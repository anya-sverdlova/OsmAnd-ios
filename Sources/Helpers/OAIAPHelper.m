//
//  OAIAPHelper.m
//  OsmAnd
//
//  Created by Alexey Kulish on 06/03/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OAIAPHelper.h"
#import "OALog.h"
#import "Localization.h"
#import "OsmAndApp.h"

NSString *const OAIAPProductPurchasedNotification = @"OAIAPProductPurchasedNotification";
NSString *const OAIAPProductPurchaseFailedNotification = @"OAIAPProductPurchaseFailedNotification";
NSString *const OAIAPProductsRestoredNotification = @"OAIAPProductsRestoredNotification";


@implementation OAFunctionalAddon

-(instancetype)initWithAddonId:(NSString *)addonId titleShort:(NSString *)titleShort titleWide:(NSString *)titleWide imageName:(NSString *)imageName
{
    self = [super init];
    if (self)
    {
        _addonId = [addonId copy];
        _titleShort = [titleShort copy];
        _titleWide = [titleWide copy];
        _imageName = [imageName copy];
    }
    return self;
}

@end

@implementation OAProduct

-(id)initWithSkProduct:(SKProduct *)skProduct
{
    self = [super init];
    if (self)
    {
        [self setSkProduct:skProduct];
    }
    return self;
}

-(id)initWithTitle:(NSString *)title desc:(NSString *)desc price:(NSDecimalNumber *)price priceLocale:(NSLocale *)priceLocale productIdentifier:(NSString *)productIdentifier
{
    self = [super init];
    if (self)
    {
        _productIdentifier = [productIdentifier copy];
        _localizedTitle = [title copy];
        _localizedDescription = [desc copy];
        _price = [price copy];
        _priceLocale = [priceLocale copy];        
    }
    return self;
}

- (void)setSkProduct:(SKProduct *)skProduct
{
    _productIdentifier = [skProduct.productIdentifier copy];
    _localizedTitle = [skProduct.localizedTitle copy];
    _localizedDescription = [skProduct.localizedDescription copy];
    _price = [skProduct.price copy];
    _priceLocale = [skProduct.priceLocale copy];
    
    _skProductRef = skProduct;
}

-(id)initWithproductIdentifier:(NSString *)productIdentifier
{
    self = [super init];
    if (self)
    {
        _productIdentifier = [productIdentifier copy];
        
        NSString *postfix = [[productIdentifier componentsSeparatedByString:@"."] lastObject];
        NSString *locTitleId = [@"product_title_" stringByAppendingString:postfix];
        NSString *locDescriptionId = [@"product_desc_" stringByAppendingString:postfix];
        
        _localizedTitle = OALocalizedString(locTitleId);
        _localizedDescription = OALocalizedString(locDescriptionId);
    }
    return self;
}

@end

@interface OAIAPHelper () <SKProductsRequestDelegate, SKPaymentTransactionObserver>
@end

@implementation OAIAPHelper
{
    SKProductsRequest * _productsRequest;
    RequestProductsCompletionHandler _completionHandler;
    
    NSSet * _productIdentifiers;
    NSMutableSet * _purchasedProductIdentifiers;
    NSMutableSet * _disabledProductIdentifiers;
    
    NSArray *_products;

    BOOL _restoringPurchases;
    NSInteger _transactionErrors;
}

+(int)freeMapsAvailable
{
    int freeMaps = kFreeMapsAvailableTotal;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"freeMapsAvailable"]) {
        freeMaps = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"freeMapsAvailable"];
    } else {
        [[NSUserDefaults standardUserDefaults] setInteger:kFreeMapsAvailableTotal forKey:@"freeMapsAvailable"];
    }

    OALog(@"Free maps available: %d", freeMaps);
    return freeMaps;
}

+(void)decreaseFreeMapsCount
{
    int freeMaps = kFreeMapsAvailableTotal;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"freeMapsAvailable"]) {
        freeMaps = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"freeMapsAvailable"];
    }
    [[NSUserDefaults standardUserDefaults] setInteger:--freeMaps forKey:@"freeMapsAvailable"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    OALog(@"Free maps left: %d", freeMaps);

}

+ (OAIAPHelper *)sharedInstance {
    static dispatch_once_t once;
    static OAIAPHelper * sharedInstance;
    dispatch_once(&once, ^{
        NSSet * productIdentifiers = [NSSet setWithObjects:
                                      kInAppId_Region_Africa,
                                      kInAppId_Region_Russia,
                                      kInAppId_Region_Asia,
                                      kInAppId_Region_Australia,
                                      kInAppId_Region_Europe,
                                      kInAppId_Region_Central_America,
                                      kInAppId_Region_North_America,
                                      kInAppId_Region_South_America,
                                      kInAppId_Region_All_World,
                                      kInAppId_Addon_SkiMap,
                                      kInAppId_Addon_Nautical,
                                      kInAppId_Addon_TrackRecording,
                                      kInAppId_Addon_Parking,
                                      kInAppId_Addon_Wiki,
                                      kInAppId_Addon_Srtm,
                                      nil];
        sharedInstance = [[self alloc] initWithProductIdentifiers:productIdentifiers];
    });
    return sharedInstance;
}

+(NSArray *)inAppsMaps
{
    return [NSArray arrayWithObjects:
            kInAppId_Region_All_World,
            kInAppId_Region_Africa,
            kInAppId_Region_Russia,
            kInAppId_Region_Asia,
            kInAppId_Region_Australia,
            kInAppId_Region_Europe,
            kInAppId_Region_Central_America,
            kInAppId_Region_North_America,
            kInAppId_Region_South_America,
            nil];
}

+(NSArray *)inAppsAddons
{
    return [NSArray arrayWithObjects:
            kInAppId_Addon_SkiMap,
            kInAppId_Addon_Nautical,
            kInAppId_Addon_TrackRecording,
            kInAppId_Addon_Parking,
            kInAppId_Addon_Wiki,
            kInAppId_Addon_Srtm,
            nil];
}

-(BOOL)productsLoaded
{
    return _products.count > 0;
}

-(OAProduct *)product:(NSString *)productIdentifier
{
    for (OAProduct *p in _products) {
        if ([p.productIdentifier isEqualToString:productIdentifier])
            return p;
    }
    return nil;
}

-(int)productIndex:(NSString *)productIdentifier
{
    NSArray *maps = [self.class inAppsMaps];
    for (int i = 0; i < maps.count; i++)
        if ([maps[i] isEqualToString:productIdentifier])
            return i;
    
    NSArray *addons = [self.class inAppsAddons];
    for (int i = 0; i < addons.count; i++)
        if ([addons[i] isEqualToString:productIdentifier])
            return i;

    return -1;
}

- (NSString *) getDisabledId:(NSString *)productIdentifier
{
    return [productIdentifier stringByAppendingString:@"_disabled"];
}

- (id)initWithProductIdentifiers:(NSSet *)productIdentifiers {
    
    if ((self = [super init])) {
        
        // Store product identifiers
        _productIdentifiers = productIdentifiers;
        
        _purchasedProductIdentifiers = [NSMutableSet set];
        _disabledProductIdentifiers = [NSMutableSet set];
        
        // Check for previously purchased products
        for (NSString * productIdentifier in _productIdentifiers) {
#if !defined(OSMAND_IOS_DEV)
            BOOL productPurchased = [[NSUserDefaults standardUserDefaults] boolForKey:productIdentifier];
#else
            BOOL productPurchased = YES;
#endif            
            if (productPurchased) {
                
                BOOL productDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:[self getDisabledId:productIdentifier]];
                if (productDisabled)
                    [_disabledProductIdentifiers addObject:[self getDisabledId:productIdentifier]];

                if ([[self.class inAppsMaps] containsObject:productIdentifier])
                    _isAnyMapPurchased = YES;
                
                [_purchasedProductIdentifiers addObject:productIdentifier];
                OALog(@"Previously purchased: %@", productIdentifier);
                
            } else {
                OALog(@"Not purchased: %@", productIdentifier);
            }
        }
        [self buildFunctionalAddonsArray];
    }
    return self;
    
}

- (void)requestProductsWithCompletionHandler:(RequestProductsCompletionHandler)completionHandler
{
    // Add self as transaction observer
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];

    _completionHandler = [completionHandler copy];
    _productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:_productIdentifiers];
    _productsRequest.delegate = self;
    [_productsRequest start];
}

- (void)disableProduct:(NSString *)productIdentifier
{
    [_disabledProductIdentifiers addObject:[self getDisabledId:productIdentifier]];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:[self getDisabledId:productIdentifier]];
    [self buildFunctionalAddonsArray];
    [[[OsmAndApp instance] addonsSwitchObservable] notifyEventWithKey:productIdentifier andValue:[NSNumber numberWithBool:NO]];
}

- (void)enableProduct:(NSString *)productIdentifier
{
    [_disabledProductIdentifiers removeObject:[self getDisabledId:productIdentifier]];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:[self getDisabledId:productIdentifier]];
    [self buildFunctionalAddonsArray];
    [[[OsmAndApp instance] addonsSwitchObservable] notifyEventWithKey:productIdentifier andValue:[NSNumber numberWithBool:YES]];
}

- (BOOL)isProductDisabled:(NSString *)productIdentifier
{
    return [_disabledProductIdentifiers containsObject:[self getDisabledId:productIdentifier]];
}

- (BOOL)productPurchasedIgnoreDisable:(NSString *)productIdentifier
{
    return [_purchasedProductIdentifiers containsObject:productIdentifier];
}

- (BOOL)productPurchased:(NSString *)productIdentifier
{
    return [_purchasedProductIdentifiers containsObject:productIdentifier] && ![_disabledProductIdentifiers containsObject:[self getDisabledId:productIdentifier]];
}

- (void)buildFunctionalAddonsArray
{
    //[_purchasedProductIdentifiers addObject:kInAppId_Addon_Parking];
    //[_purchasedProductIdentifiers addObject:kInAppId_Addon_TrackRecording];

    NSMutableArray *arr = [NSMutableArray array];

    if ([self productPurchased:kInAppId_Addon_Parking])
    {
        OAFunctionalAddon *addon = [[OAFunctionalAddon alloc] initWithAddonId:kId_Addon_Parking_Set titleShort:OALocalizedString(@"add_parking_short") titleWide:OALocalizedString(@"add_parking") imageName:@"parking_position.png"];
        addon.sortIndex = 0;
        [arr addObject:addon];
    }

    if ([self productPurchased:kInAppId_Addon_TrackRecording])
    {
        OAFunctionalAddon *addon = [[OAFunctionalAddon alloc] initWithAddonId:kId_Addon_TrackRecording_Add_Waypoint titleShort:OALocalizedString(@"add_waypoint_short") titleWide:OALocalizedString(@"add_waypoint") imageName:@"add_waypoint_to_track.png"];
        addon.sortIndex = 1;
        [arr addObject:addon];
    }
    
    [arr sortUsingComparator:^NSComparisonResult(OAFunctionalAddon *obj1, OAFunctionalAddon *obj2) {
        return obj1.sortIndex < obj2.sortIndex ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    if (arr.count == 1)
        _singleAddon = arr[0];
    else
        _singleAddon = nil;
    
    _functionalAddons = [NSArray arrayWithArray:arr];
}

- (void)buyProduct:(OAProduct *)product
{
    OALog(@"Buying %@...", product.productIdentifier);
    
    _restoringPurchases = NO;
    
    if (product.skProductRef)
    {
        SKPayment * payment = [SKPayment paymentWithProduct:product.skProductRef];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
    else
    {
        OAIAPHelper * __weak weakSelf = self;
        _completionHandler = ^(BOOL success) {
            if (!success)
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:OAIAPProductPurchaseFailedNotification object:nil userInfo:nil];
            }
            else
            {
                OAProduct *p = [weakSelf product:product.productIdentifier];
                [weakSelf buyProduct:p];
            }
        };
        
        NSSet *s = [[NSSet alloc] initWithObjects:product.productIdentifier, nil];
        _productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:s];
        _productsRequest.delegate = self;
        [_productsRequest start];

    }
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    OALog(@"Loaded list of products...");
    _productsRequest = nil;
    
    NSMutableArray *arr = [NSMutableArray array];
    for (SKProduct * skProduct in response.products)
    {
        OALog(@"Found product: %@ %@ %0.2f",
              skProduct.productIdentifier,
              skProduct.localizedTitle,
              skProduct.price.floatValue);
        OAProduct *p = [[OAProduct alloc] initWithSkProduct:skProduct];
        [arr addObject:p];
        
        if (p.price.floatValue == 0.0 && ![self productPurchasedIgnoreDisable:p.productIdentifier])
        {
            [_purchasedProductIdentifiers addObject:p.productIdentifier];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:p.productIdentifier];
            [_disabledProductIdentifiers addObject:[self getDisabledId:p.productIdentifier]];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:[self getDisabledId:p.productIdentifier]];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
    
    if (_products.count == 0)
    {
        _products = [NSArray arrayWithArray:arr];
    }
    else
    {
        for (OAProduct *product in _products)
        {
            BOOL exist = NO;
            for (OAProduct *p in arr)
                if ([p.productIdentifier isEqualToString:product.productIdentifier])
                {
                    exist = YES;
                    break;
                }
            if (!exist)
                [arr addObject:product];
        }
        _products = [NSArray arrayWithArray:arr];
    }
    
    if (_completionHandler)
        _completionHandler(YES);
    
    _completionHandler = nil;
    
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    
    OALog(@"Failed to load list of products.");
    _productsRequest = nil;
    
    if (_products.count == 0)
    {
        NSMutableArray *arr = [NSMutableArray array];
        for (NSString *prodId in _productIdentifiers)
        {
            OAProduct *p = [[OAProduct alloc] initWithproductIdentifier:prodId];
            [arr addObject:p];
        }
        
        _products = [NSArray arrayWithArray:arr];
    }

    if (_completionHandler)
        _completionHandler(NO);
    
    _completionHandler = nil;
    
}

#pragma mark SKPaymentTransactionOBserver

// Sent when the transaction array has changed (additions or state changes).  Client should check state of transactions and finish as appropriate.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction * transaction in transactions) {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                _transactionErrors++;
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    };

}

// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    [[NSNotificationCenter defaultCenter] postNotificationName:OAIAPProductsRestoredNotification object:[NSNumber numberWithInteger:_transactionErrors] userInfo:nil];
}

// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    [[NSNotificationCenter defaultCenter] postNotificationName:OAIAPProductsRestoredNotification object:[NSNumber numberWithInteger:_transactionErrors] userInfo:nil];
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    OALog(@"completeTransaction - %@", transaction.payment.productIdentifier);
    
    if ([[self.class inAppsMaps] containsObject:transaction.payment.productIdentifier])
        _isAnyMapPurchased = YES;

    [self provideContentForProductIdentifier:transaction.payment.productIdentifier];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    OALog(@"restoreTransaction - %@", transaction.originalTransaction.payment.productIdentifier);
    
    if ([[self.class inAppsMaps] containsObject:transaction.originalTransaction.payment.productIdentifier])
        _isAnyMapPurchased = YES;

    [self provideContentForProductIdentifier:transaction.originalTransaction.payment.productIdentifier];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    
    OALog(@"failedTransaction - %@", transaction.payment.productIdentifier);
    if (transaction.error.code != SKErrorPaymentCancelled)
    {
        OALog(@"Transaction error: %@", transaction.error.localizedDescription);

        [[NSNotificationCenter defaultCenter] postNotificationName:OAIAPProductPurchaseFailedNotification object:transaction.payment.productIdentifier userInfo:nil];
    
    } else {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:OAIAPProductPurchaseFailedNotification object:nil userInfo:nil];
    }

    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void)provideContentForProductIdentifier:(NSString *)productIdentifier {
    
    [_purchasedProductIdentifiers addObject:productIdentifier];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:productIdentifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:OAIAPProductPurchasedNotification object:productIdentifier userInfo:nil];

    [self buildFunctionalAddonsArray];
}

- (void)restoreCompletedTransactions {
    
    _restoringPurchases = YES;
    _transactionErrors = 0;
    
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

@end
//
//  OAMapSettingsOverlayUnderlayScreen.m
//  OsmAnd
//
//  Created by Alexey Kulish on 05/03/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OAMapSettingsOverlayUnderlayScreen.h"
#import "OAMapSettingsViewController.h"
#import "Localization.h"
#import "OASliderCell.h"
#import "OARootViewController.h"
#import "OAMapPanelViewController.h"
#import "OAMapCreatorHelper.h"

#include <QSet>

#include <OsmAndCore/Map/IMapStylesCollection.h>
#include <OsmAndCore/Map/UnresolvedMapStyle.h>
#include <OsmAndCore/Map/IOnlineTileSources.h>
#include <OsmAndCore/Map/OnlineTileSources.h>

#define _(name) OAMapSourcesOverlayUnderlayScreen__##name
#define commonInit _(commonInit)
#define deinit _(deinit)

#define Item _(Item)
@interface Item : NSObject
@property OAMapSource* mapSource;
@property std::shared_ptr<const OsmAnd::ResourcesManager::Resource> resource;
@end
@implementation Item
@end

#define Item_OnlineTileSource _(Item_OnlineTileSource)
@interface Item_OnlineTileSource : Item
@property std::shared_ptr<const OsmAnd::IOnlineTileSources::Source> onlineTileSource;
@end
@implementation Item_OnlineTileSource
@end

#define Item_SqliteDbTileSource _(Item_SqliteDbTileSource)
@interface Item_SqliteDbTileSource : Item
@end
@implementation Item_SqliteDbTileSource
@end

typedef OsmAnd::ResourcesManager::ResourceType OsmAndResourceType;

typedef enum
{
    EMapSettingOverlay = 0,
    EMapSettingUnderlay,
    
} EMapSettingType;

@implementation OAMapSettingsOverlayUnderlayScreen
{
    OsmAndAppInstance _app;
    OAAppSettings *_settings;

    NSMutableArray* _onlineMapSources;
    EMapSettingType _mapSettingType;
    UIButton *_btnShowOnMap;
}

@synthesize settingsScreen, tableData, vwController, tblView, title, isOnlineMapSource;


- (id) initWithTable:(UITableView *)tableView viewController:(OAMapSettingsViewController *)viewController param:(id)param
{
    self = [super init];
    if (self)
    {
        _app = [OsmAndApp instance];
        _settings = [OAAppSettings sharedManager];
        
        if ([param isEqualToString:@"overlay"]) {
            _mapSettingType = EMapSettingOverlay;
            title = OALocalizedString(@"map_settings_over");
            settingsScreen = EMapSettingsScreenOverlay;

        } else {
            _mapSettingType = EMapSettingUnderlay;
            title = OALocalizedString(@"map_settings_under");
            settingsScreen = EMapSettingsScreenUnderlay;
        }
        
        vwController = viewController;
        tblView = tableView;

        _btnShowOnMap = [UIButton buttonWithType:UIButtonTypeSystem];
        CGRect f = vwController.navbarView.frame;
        CGFloat btnSize = 20.0;
        _btnShowOnMap.frame = CGRectMake(f.size.width - 32.0, 32.0 + [OAUtilities getTopMargin] / 2, btnSize, btnSize);
        _btnShowOnMap.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_btnShowOnMap setImage:[UIImage imageNamed:@"left_menu_icon_map.png"] forState:UIControlStateNormal];
        _btnShowOnMap.tintColor = [UIColor whiteColor];
        [_btnShowOnMap addTarget:self action:@selector(btnShowOnMapPressed) forControlEvents:UIControlEventTouchUpInside];
        [vwController.navbarView addSubview:_btnShowOnMap];
        
        [self commonInit];
        [self initData];
    }
    return self;
}

- (void)dealloc
{
    [self deinit];
}

- (void)commonInit
{
    _onlineMapSources = [NSMutableArray array];
}

- (void)deinit
{
}

- (void)btnShowOnMapPressed
{
    [[OARootViewController instance].mapPanel updateOverlayUnderlayView:YES];
    [[OARootViewController instance].mapPanel closeDashboard];
}

- (void)setupView
{
    [_onlineMapSources removeAllObjects];
    
    // Collect all needed resources
    QList< std::shared_ptr<const OsmAnd::ResourcesManager::Resource> > onlineTileSourcesResources;
    const auto localResources = _app.resourcesManager->getLocalResources();
    for(const auto& localResource : localResources)
        if (localResource->type == OsmAndResourceType::OnlineTileSources)
            onlineTileSourcesResources.push_back(localResource);
    
    
    // Process online tile sources resources
    for(const auto& resource : onlineTileSourcesResources)
    {
        const auto& onlineTileSources = std::static_pointer_cast<const OsmAnd::ResourcesManager::OnlineTileSourcesMetadata>(resource->metadata)->sources;
        NSString* resourceId = resource->id.toNSString();
        
        for(const auto& onlineTileSource : onlineTileSources->getCollection())
        {
            Item_OnlineTileSource* item = [[Item_OnlineTileSource alloc] init];
            
            NSString *caption = onlineTileSource->title.toNSString();
            
            item.mapSource = [[OAMapSource alloc] initWithResource:resourceId
                                                        andVariant:onlineTileSource->name.toNSString() name:caption];
            item.resource = resource;
            item.onlineTileSource = onlineTileSource;
            
            [_onlineMapSources addObject:item];
        }
    }
    
    
    NSArray *arr = [_onlineMapSources sortedArrayUsingComparator:^NSComparisonResult(Item_OnlineTileSource* obj1, Item_OnlineTileSource* obj2) {
        NSString *caption1 = obj1.onlineTileSource->title.toNSString();
        NSString *caption2 = obj2.onlineTileSource->title.toNSString();
        return [caption2 compare:caption1];
    }];
    
    [_onlineMapSources setArray:arr];

    
    NSMutableArray *sqlitedbArr = [NSMutableArray array];
    for (NSString *fileName in [OAMapCreatorHelper sharedInstance].files.allKeys)
    {
        Item_SqliteDbTileSource* item = [[Item_SqliteDbTileSource alloc] init];
        item.mapSource = [[OAMapSource alloc] initWithResource:fileName andVariant:@"" name:@"sqlitedb"];
        
        [sqlitedbArr addObject:item];
    }
    
    [sqlitedbArr sortUsingComparator:^NSComparisonResult(Item_SqliteDbTileSource *obj1, Item_SqliteDbTileSource *obj2) {
        return [obj1.mapSource.resourceId caseInsensitiveCompare:obj2.mapSource.resourceId];
    }];
    
    [_onlineMapSources addObjectsFromArray:sqlitedbArr];
}


-(void) initData
{
}


#pragma mark - UITableViewDataSource

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section)
    {
        case 0:
            return 1;
        case 1:
            return [_onlineMapSources count] + 1;
            
        default:
            return 0;
    }
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section)
    {
        case 0:
            return OALocalizedString(@"map_settings_transp");
        case 1:
            return OALocalizedString(@"map_settings_avail_lay");
            
        default:
            return nil;
    }
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1)
    {
        static NSString* const mapSourceItemCell = @"mapSourceItemCell";
        
        // Get content for cell and it's type id
        NSString* caption = nil;
        NSString* description = nil;
        Item* someItem = nil;
        
        if (indexPath.row > 0)
        {
            someItem = [_onlineMapSources objectAtIndex:indexPath.row - 1];
            
            if ([someItem isKindOfClass:[Item_OnlineTileSource class]])
            {
                if (someItem.resource->type == OsmAndResourceType::OnlineTileSources)
                {
                    Item_OnlineTileSource* item = (Item_OnlineTileSource*)someItem;
                    caption = item.mapSource.name;
                    description = nil;
                }
            }
            else if ([someItem isKindOfClass:[Item_SqliteDbTileSource class]])
            {
                caption = [[someItem.mapSource.resourceId stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
                description = nil;
            }
        }
        else
        {
            caption = OALocalizedString(@"map_settings_none");
        }
        
        // Obtain reusable cell or create one
        UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:mapSourceItemCell];
        if (cell == nil)
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:mapSourceItemCell];
        
        // Fill cell content
        cell.textLabel.text = caption;
        cell.detailTextLabel.text = description;
        
        OAMapSource* mapSource;
        if (_mapSettingType == EMapSettingOverlay)
            mapSource = _app.data.overlayMapSource;
        else
            mapSource = _app.data.underlayMapSource;

        if ((indexPath.row == 0 && mapSource == nil) || [mapSource isEqual:someItem.mapSource])
            cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"menu_cell_selected.png"]];
        else
            cell.accessoryView = nil;
        
        return cell;
    }
    else
    {
        static NSString* const identifierCell = @"OASliderCell";
        OASliderCell* cell = [tableView dequeueReusableCellWithIdentifier:identifierCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OASliderCell" owner:self options:nil];
            cell = (OASliderCell *)[nib objectAtIndex:0];
            [cell.sliderView addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        }
        
        if (cell)
        {
            if (_mapSettingType == EMapSettingOverlay)
                cell.sliderView.value = _app.data.overlayAlpha;
            else
                cell.sliderView.value = _app.data.underlayAlpha;
        }
            
        return cell;
    }
}

- (void) sliderValueChanged:(id)sender
{
    UISlider *slider = sender;
    if (_mapSettingType == EMapSettingOverlay)
        _app.data.overlayAlpha = slider.value;
    else
        _app.data.underlayAlpha = slider.value;
}

#pragma mark - UITableViewDelegate

- (CGFloat) tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
{
    return 34.0;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 34.0;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1)
    {
        if (indexPath.row > 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                Item* item = [_onlineMapSources objectAtIndex:indexPath.row - 1];
                if (_mapSettingType == EMapSettingOverlay)
                {
                    _app.data.overlayMapSource = item.mapSource;
                }
                else
                {
                    _app.data.underlayMapSource = item.mapSource;
                }
                [tableView reloadData];
            });
        }
        else
        {
            if (_mapSettingType == EMapSettingOverlay)
            {
                _app.data.overlayMapSource = nil;
            }
            else
            {
                _app.data.underlayMapSource = nil;
            }
            [tableView reloadData];
        }
    }
}

@end

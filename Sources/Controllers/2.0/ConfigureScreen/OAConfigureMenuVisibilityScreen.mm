//
//  OAConfigureMenuVisibilityScreen.m
//  OsmAnd
//
//  Created by Alexey Kulish on 23/10/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//

#import "OAConfigureMenuVisibilityScreen.h"
#import "OsmAndApp.h"
#import "OAMapWidgetRegistry.h"
#import "OAMapWidgetRegInfo.h"
#import "OAConfigureMenuViewController.h"
#import "Localization.h"
#import "OASettingsImageCell.h"
#import "OARootViewController.h"
#import "OAUtilities.h"

@implementation OAConfigureMenuVisibilityScreen
{
    OsmAndAppInstance _app;
    OAAppSettings *_settings;
    OAMapWidgetRegistry *_mapWidgetRegistry;

    OAMapWidgetRegInfo *_r;
    NSDictionary *_data;
}

@synthesize configureMenuScreen, tableData, vwController, tblView, title;

- (id) initWithTable:(UITableView *)tableView viewController:(OAConfigureMenuViewController *)viewController param:(id)param
{
    self = [super init];
    if (self)
    {
        _app = [OsmAndApp instance];
        _settings = [OAAppSettings sharedManager];
        _mapWidgetRegistry = [OARootViewController instance].mapPanel.mapWidgetRegistry;

        _key = param;
        if (_key)
            _r = [_mapWidgetRegistry widgetByKey:_key];
        
        if (_r)
            title = [_r getMessage];

        configureMenuScreen = EConfigureMenuScreenVisibility;
        
        vwController = viewController;
        tblView = tableView;
        
        [self commonInit];
        [self initData];
    }
    return self;
}

- (void) dealloc
{
    [self deinit];
}

- (void) commonInit
{
}

- (void) deinit
{
}

- (void) initData
{
}

- (void) setupView
{
    if (_r)
    {
        OAApplicationMode *mode = [OAAppSettings sharedManager].applicationMode;
        
        _data = [NSMutableDictionary dictionary];
        NSMutableArray *standardList = [NSMutableArray array];
        
        BOOL showSelected = ![_r visibleCollapsed:mode] && [_r visible:mode];
        BOOL hideSelected = ![_r visibleCollapsed:mode] && ![_r visible:mode];
        BOOL collapsedSelected = [_r visibleCollapsed:mode];

        [standardList addObject:@{ @"title" : OALocalizedString(@"sett_show"),
                                   @"key" : @"action_show",
                                   @"img" : @"ic_action_view",
                                   @"selected" : @(showSelected),
                                   @"color" : [NSNull null],
                                   @"secondaryImg" : showSelected ? @"menu_cell_selected" : [NSNull null],
                                   @"type" : @"OASettingsImageCell"} ];

        [standardList addObject:@{ @"title" : OALocalizedString(@"poi_hide"),
                                   @"key" : @"action_hide",
                                   @"img" : @"ic_action_hide",
                                   @"selected" : @(hideSelected),
                                   @"color" : [NSNull null],
                                   @"secondaryImg" : hideSelected ? @"menu_cell_selected" : [NSNull null],
                                   @"type" : @"OASettingsImageCell"} ];
        
        [standardList addObject:@{ @"title" : OALocalizedString(@"shared_string_collapse"),
                                   @"key" : @"action_collapse",
                                   @"img" : @"ic_action_widget_collapse",
                                   @"selected" : @(collapsedSelected),
                                   @"color" : [NSNull null],
                                   @"secondaryImg" : collapsedSelected ? @"menu_cell_selected" : [NSNull null],
                                   @"type" : @"OASettingsImageCell"} ];
        
        NSMutableArray *additionalList = [NSMutableArray array];
        if ([_r getItemIds])
        {
            for (int i = 0; i < [_r getItemIds].count; i++)
            {
                NSString *itemId = [_r getItemIds][i];
                NSString *messageId = [_r getMessages][i];
                NSString *imageId = [_r getImageIds][i];
                BOOL selected = [_r.key isEqualToString:itemId];
                [additionalList addObject:@{ @"title" : OALocalizedString(messageId),
                                           @"key" : itemId,
                                           @"img" : imageId,
                                           @"selected" : @(selected),
                                           @"color" : selected ? UIColorFromRGB(0xff8f00) : [NSNull null],
                                           @"secondaryImg" : collapsedSelected ? @"menu_cell_selected" : [NSNull null],
                                           @"type" : @"OASettingsImageCell"} ];
            }
        }
        
        if (additionalList.count > 0)
            _data = @{ @"additional" : additionalList,
                       @"standard" : standardList };
        else
            _data = @{ @"standard" : standardList };
    }
}

- (void) setVisibility:(BOOL)visible collapsed:(BOOL)collapsed
{
    [_mapWidgetRegistry setVisibility:_r visible:visible collapsed:collapsed];
    [[OARootViewController instance].mapPanel recreateControls];
}

#pragma mark - UITableViewDataSource

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return _data.count;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_data[_data.allKeys[section]] count];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = _data[_data.allKeys[indexPath.section]][indexPath.row];
          
    static NSString* const identifierCell = @"OASettingsImageCell";
    OASettingsImageCell *cell = [tableView dequeueReusableCellWithIdentifier:identifierCell];
    if (cell == nil)
    {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OASettingsImageCell" owner:self options:nil];
        cell = (OASettingsImageCell *)[nib objectAtIndex:0];
    }
    
    if (cell)
    {
        cell.textView.text = item[@"title"];
        NSString *imageName = item[@"img"];
        if (imageName)
        {
            UIColor *color = nil;
            if (item[@"color"] != [NSNull null])
                color = item[@"color"];
            
            if (color)
                cell.imageView.image = [OAUtilities tintImageWithColor:[UIImage imageNamed:imageName] color:color];
            else
                cell.imageView.image = [UIImage imageNamed:imageName];
        }
        cell.textView.text = item[@"title"];
        if (item[@"secondaryImg"] != [NSNull null])
            [cell setSecondaryImage:[UIImage imageNamed:item[@"secondaryImg"]]];
    }
    
    return cell;
    
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = _data[_data.allKeys[indexPath.section]][indexPath.row];
    return [OASettingsImageCell getHeight:item[@"title"] hasSecondaryImg:item[@"secondaryImg"] != [NSNull null] cellWidth:tableView.bounds.size.width];
}

#pragma mark - UITableViewDelegate

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.01;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = _data[_data.allKeys[indexPath.section]][indexPath.row];

    [tableView reloadData];
}

@end

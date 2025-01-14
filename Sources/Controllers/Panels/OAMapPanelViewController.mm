//
//  OAMapPanelViewController.m
//  OsmAnd
//
//  Created by Alexey Pelykh on 8/20/13.
//  Copyright (c) 2013 OsmAnd. All rights reserved.
//

#import "OAMapPanelViewController.h"

#import "OsmAndApp.h"
#import "UIViewController+OARootViewController.h"
#import "OAMapHudViewController.h"
#import "OAMapillaryImageViewController.h"
#import "OAMapViewController.h"
#import "OAAutoObserverProxy.h"
#import "OALog.h"
#import "OAIAPHelper.h"
#import "OAGPXItemViewController.h"
#import "OAGPXEditItemViewController.h"
#import "OAGPXDatabase.h"
#import <UIViewController+JASidePanel.h>
#import "OADestinationCardsViewController.h"
#import "OAPluginPopupViewController.h"
#import "OATargetDestinationViewController.h"
#import "OATargetHistoryItemViewController.h"
#import "OATargetAddressViewController.h"
#import "OAToolbarViewController.h"
#import "OADiscountHelper.h"
#import "OARouteInfoView.h"
#import "OARoutingHelper.h"
#import "OATargetPointsHelper.h"
#import "OAMapActions.h"
#import "OARTargetPoint.h"
#import "OARouteTargetViewController.h"
#import "OARouteTargetSelectionViewController.h"
#import "OAPointDescription.h"
#import "OAMapWidgetRegistry.h"
#import "OALocationSimulation.h"
#import "OAColors.h"
#import "OAImpassableRoadSelectionViewController.h"
#import "OAImpassableRoadViewController.h"
#import "OAAvoidSpecificRoads.h"
#import "OAWaypointsViewController.h"

#import <EventKit/EventKit.h>

#import "OAMapRendererView.h"
#import "OANativeUtilities.h"
#import "OADestinationViewController.h"
#import "OADestination.h"
#import "OAMapSettingsViewController.h"
#import "OAQuickSearchViewController.h"
#import "OAPOIType.h"
#import "OADefaultFavorite.h"
#import "Localization.h"
#import "OAAppSettings.h"
#import "OASavingTrackHelper.h"
#import "PXAlertView.h"
#import "OATrackIntervalDialogView.h"
#import "OAParkingViewController.h"
#import "OAFavoriteViewController.h"
#import "OAPOIViewController.h"
#import "OAWikiMenuViewController.h"
#import "OAWikiWebViewController.h"
#import "OAGPXWptViewController.h"
#import "OAGPXDocumentPrimitives.h"
#import "OAUtilities.h"
#import "OAGPXListViewController.h"
#import "OAFavoriteListViewController.h"
#import "OAGPXRouter.h"
#import "OADestinationsHelper.h"
#import "OAHistoryItem.h"
#import "OAGPXEditWptViewController.h"
#import "OAPOI.h"
#import "OAPOILocationType.h"
#import "OAFirebaseHelper.h"
#import "OATargetMultiView.h"
#import "OAReverseGeocoder.h"
#import "OAAddress.h"
#import "OABuilding.h"
#import "OAStreet.h"
#import "OAStreetIntersection.h"
#import "OACity.h"
#import "OATargetTurnViewController.h"
#import "OARoutePreferencesViewController.h"
#import "OAConfigureMenuViewController.h"
#import "OAMapViewTrackingUtilities.h"
#import "OAMapLayers.h"
#import "OAFavoritesLayer.h"
#import "OAImpassableRoadsLayer.h"

#import <UIAlertView+Blocks.h>
#import <UIAlertView-Blocks/RIButtonItem.h>

#include <OsmAndCore.h>
#include <OsmAndCore/Utilities.h>
#include <OsmAndCore/Data/Road.h>
#include <OsmAndCore/CachingRoadLocator.h>
#include <OsmAndCore/IFavoriteLocation.h>
#include <OsmAndCore/IFavoriteLocationsCollection.h>
#include <OsmAndCore/ICU.h>


#define _(name) OAMapPanelViewController__##name
#define commonInit _(commonInit)
#define deinit _(deinit)

#define kMaxRoadDistanceInMeters 1000

typedef enum
{
    EOATargetPoint = 0,
    EOATargetBBOX,
    
} EOATargetMode;

@interface OAMapPanelViewController () <OADestinationViewControllerProtocol, OAParkingDelegate, OAWikiMenuDelegate, OAGPXWptViewControllerDelegate, OAToolbarViewControllerProtocol, OARouteCalculationProgressCallback, OARouteInformationListener>

@property (nonatomic) OAMapHudViewController *hudViewController;
@property (nonatomic) OAMapillaryImageViewController *mapillaryController;
@property (nonatomic) OADestinationViewController *destinationViewController;

@property (strong, nonatomic) OATargetPointView* targetMenuView;
@property (strong, nonatomic) OATargetMultiView* targetMultiMenuView;
@property (strong, nonatomic) UIButton* shadowButton;

@property (strong, nonatomic) OARouteInfoView* routeInfoView;

@end

@implementation OAMapPanelViewController
{
    OsmAndAppInstance _app;
    OAAppSettings *_settings;
    OASavingTrackHelper *_recHelper;
    OARoutingHelper *_routingHelper;
    OAMapViewTrackingUtilities *_mapViewTrackingUtilities;

    OAAutoObserverProxy* _addonsSwitchObserver;
    OAAutoObserverProxy* _destinationRemoveObserver;
    OAAutoObserverProxy* _mapillaryChangeObserver;
    
    BOOL _mapNeedsRestore;
    OAMapMode _mainMapMode;
    OsmAnd::PointI _mainMapTarget31;
    float _mainMapZoom;
    float _mainMapAzimuth;
    float _mainMapEvelationAngle;
    
    NSString *_formattedTargetName;
    double _targetLatitude;
    double _targetLongitude;
    double _targetZoom;
    EOATargetMode _targetMode;
    
    OADestination *_targetDestination;

    OADashboardViewController *_dashboard;
    OAQuickSearchViewController *_searchViewController;
    UILongPressGestureRecognizer *_shadowLongPress;

    BOOL _customStatusBarStyleNeeded;
    UIStatusBarStyle _customStatusBarStyle;
    
    BOOL _mapStateSaved;
    
    UIView *_shadeView;
    
    NSMutableArray<OAToolbarViewController *> *_toolbars;
    BOOL _topControlsVisible;
}

- (instancetype) init
{
    self = [super init];
    if (self)
    {
        [self commonInit];
    }
    return self;
}

- (void) commonInit
{
    _app = [OsmAndApp instance];

    _settings = [OAAppSettings sharedManager];
    _recHelper = [OASavingTrackHelper sharedInstance];
    _mapActions = [[OAMapActions alloc] init];
    _routingHelper = [OARoutingHelper sharedInstance];
    _mapViewTrackingUtilities = [OAMapViewTrackingUtilities instance];
    _mapWidgetRegistry = [[OAMapWidgetRegistry alloc] init];
    
    _addonsSwitchObserver = [[OAAutoObserverProxy alloc] initWith:self
                                                      withHandler:@selector(onAddonsSwitch:withKey:andValue:)
                                                       andObserve:_app.addonsSwitchObservable];

    _destinationRemoveObserver = [[OAAutoObserverProxy alloc] initWith:self
                                                           withHandler:@selector(onDestinationRemove:withKey:)
                                                            andObserve:_app.data.destinationRemoveObservable];
    
    _mapillaryChangeObserver = [[OAAutoObserverProxy alloc] initWith:self
                                                         withHandler:@selector(onMapillaryChanged)
                                                          andObserve:_app.data.mapillaryChangeObservable];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMapGestureAction:) name:kNotificationMapGestureAction object:nil];

    [_routingHelper addListener:self];
    [_routingHelper setProgressBar:self];
    
    _toolbars = [NSMutableArray array];
    _topControlsVisible = YES;
}

- (void) loadView
{
    OALog(@"Creating Map Panel views...");
    
    // Create root view
    UIView* rootView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view = rootView;
    
    // Setup route info menu
    self.routeInfoView = [[OARouteInfoView alloc] initWithFrame:CGRectMake(0.0, 0.0, DeviceScreenWidth, 140.0)];

    // Instantiate map view controller
    _mapViewController = [[OAMapViewController alloc] init];
    [self addChildViewController:_mapViewController];
    [self.view addSubview:_mapViewController.view];
    _mapViewController.view.frame = self.view.frame;
    _mapViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // Setup target point menu
    self.targetMenuView = [[OATargetPointView alloc] initWithFrame:CGRectMake(0.0, 0.0, DeviceScreenWidth, DeviceScreenHeight)];
    self.targetMenuView.menuViewDelegate = self;
    [self.targetMenuView setMapViewInstance:_mapViewController.view];
    [self.targetMenuView setParentViewInstance:self.view];
    self.targetMenuView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [self resetActiveTargetMenu];

    // Setup target multi menu
    self.targetMultiMenuView = [[OATargetMultiView alloc] initWithFrame:CGRectMake(0.0, 0.0, DeviceScreenWidth, 140.0)];

    [self updateHUD:NO];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_mapNeedsRestore)
    {
        _mapNeedsRestore = NO;
        [self restoreMapAfterReuse];
    }
    
    self.sidePanelController.recognizesPanGesture = NO; //YES;
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self.targetMenuView setNavigationController:self.navigationController];

    if ([_mapViewController parentViewController] != self)
        [self doMapRestore];
    
    [[OADiscountHelper instance] checkAndDisplay];
}

- (void) viewWillLayoutSubviews
{
    if ([self contextMenuMode])
    {
        [self doUpdateContextMenuToolbarLayout];
    }
    else
    {
        OAToolbarViewController *topToolbar = [self getTopToolbar];
        if (topToolbar)
            [topToolbar updateFrame:YES];
        else
            [self updateToolbar];
    }
    
    if (_shadowButton)
        _shadowButton.frame = [self shadowButtonRect];
}
 
@synthesize mapViewController = _mapViewController;

- (void) doUpdateContextMenuToolbarLayout
{
    CGFloat contextMenuToolbarHeight = [self.targetMenuView toolbarHeight];
    [self.hudViewController updateContextMenuToolbarLayout:contextMenuToolbarHeight animated:YES];
}

- (void) updateHUD:(BOOL)animated
{
    if (!_destinationViewController)
    {
        _destinationViewController = [[OADestinationViewController alloc] initWithNibName:@"OADestinationViewController" bundle:nil];
        _destinationViewController.delegate = self;
        _destinationViewController.destinationDelegate = self;
        
        if ([OADestinationsHelper instance].sortedDestinations.count > 0)
            [self showToolbar:_destinationViewController];
    }
    
    // Inflate new HUD controller
    if (!self.hudViewController)
    {
        self.hudViewController = [[OAMapHudViewController alloc] initWithNibName:@"OAMapHudViewController"
                                                                                             bundle:nil];
        self.hudViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;        
        [self addChildViewController:self.hudViewController];
        
        // Switch views
        self.hudViewController.view.frame = self.view.frame;
        [self.view addSubview:self.hudViewController.view];
    }
    
    if (!self.mapillaryController)
    {
        self.mapillaryController = [[OAMapillaryImageViewController alloc] initWithNibName:@"OAMapillaryImageViewController" bundle:nil];
        
        self.mapillaryController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addChildViewController:self.mapillaryController];
        
        // Switch views
        self.mapillaryController.view.frame = self.view.frame;
        [self.view addSubview:self.mapillaryController.view];
        
        [self.mapillaryController.view setHidden:YES];
    }
    
    _mapViewController.view.frame = self.view.frame;
    
    [self updateToolbar];

    [self.rootViewController setNeedsStatusBarAppearanceUpdate];
}

- (void) updateOverlayUnderlayView:(BOOL)show
{
    [self.hudViewController updateOverlayUnderlayView:show];
}

- (UIStatusBarStyle) preferredStatusBarStyle
{
    if (_dashboard || !_mapillaryController.view.hidden)
        return UIStatusBarStyleLightContent;
    
    if (_customStatusBarStyleNeeded)
        return _customStatusBarStyle;

    UIStatusBarStyle style;
    if (!self.hudViewController)
        style = UIStatusBarStyleDefault;
    
    style = self.hudViewController.preferredStatusBarStyle;
    
    return [self.targetMenuView getStatusBarStyle:[self contextMenuMode] defaultStyle:style];
}

- (void) onMapillaryChanged
{
    if (!_app.data.mapillary)
        [_mapillaryController hideMapillaryView];
}

- (BOOL) hasGpxActiveTargetType
{
    return _activeTargetType == OATargetGPX || _activeTargetType == OATargetGPXEdit || _activeTargetType == OATargetRouteStartSelection || _activeTargetType == OATargetRouteFinishSelection || _activeTargetType == OATargetRouteIntermediateSelection ||_activeTargetType == OATargetImpassableRoadSelection;
}

- (void) onAddonsSwitch:(id)observable withKey:(id)key andValue:(id)value
{
    NSString *productIdentifier = key;
    if ([productIdentifier isEqualToString:kInAppId_Addon_Srtm])
    {
        [_app.data.mapLayerChangeObservable notifyEvent];
    }
}

- (void) saveMapStateIfNeeded
{
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;
    
    if ([_mapViewController parentViewController] == self) {
        
        _mapNeedsRestore = YES;
        _mainMapMode = _app.mapMode;
        _mainMapTarget31 = renderView.target31;
        _mainMapZoom = renderView.zoom;
        _mainMapAzimuth = renderView.azimuth;
        _mainMapEvelationAngle = renderView.elevationAngle;
    }
}

- (void) saveMapStateNoRestore
{
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;

    _mapNeedsRestore = NO;
    _mainMapMode = _app.mapMode;
    _mainMapTarget31 = renderView.target31;
    _mainMapZoom = renderView.zoom;
    _mainMapAzimuth = renderView.azimuth;
    _mainMapEvelationAngle = renderView.elevationAngle;
}

- (void) prepareMapForReuse:(Point31)destinationPoint zoom:(CGFloat)zoom newAzimuth:(float)newAzimuth newElevationAngle:(float)newElevationAngle animated:(BOOL)animated
{
    [self saveMapStateIfNeeded];
    
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;

    if (isnan(zoom))
        zoom = renderView.zoom;
    if (zoom > 22.0f)
        zoom = 22.0f;
    
    [_mapViewController goToPosition:destinationPoint
                             andZoom:zoom
                            animated:animated];
    
    renderView.azimuth = newAzimuth;
    renderView.elevationAngle = newElevationAngle;
}

- (void) prepareMapForReuse:(UIView *)destinationView mapBounds:(OAGpxBounds)mapBounds newAzimuth:(float)newAzimuth newElevationAngle:(float)newElevationAngle animated:(BOOL)animated
{
    [self saveMapStateIfNeeded];
    
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;
    
    if (mapBounds.topLeft.latitude != DBL_MAX) {
        
        const OsmAnd::LatLon latLon(mapBounds.center.latitude, mapBounds.center.longitude);
        Point31 center = [OANativeUtilities convertFromPointI:OsmAnd::Utilities::convertLatLonTo31(latLon)];
        
        float metersPerPixel = [_mapViewController calculateMapRuler];
        
        double distanceH = OsmAnd::Utilities::distance(mapBounds.topLeft.longitude, mapBounds.topLeft.latitude, mapBounds.bottomRight.longitude, mapBounds.topLeft.latitude);
        double distanceV = OsmAnd::Utilities::distance(mapBounds.topLeft.longitude, mapBounds.topLeft.latitude, mapBounds.topLeft.longitude, mapBounds.bottomRight.latitude);
        
        CGSize mapSize;
        if (destinationView)
            mapSize = destinationView.bounds.size;
        else
            mapSize = self.view.bounds.size;
        
        CGFloat newZoomH = distanceH / (mapSize.width * metersPerPixel);
        CGFloat newZoomV = distanceV / (mapSize.height * metersPerPixel);
        CGFloat newZoom = log2(MAX(newZoomH, newZoomV));
        
        CGFloat zoom = renderView.zoom - newZoom;
        if (isnan(zoom))
            zoom = renderView.zoom;
        if (zoom > 22.0f)
            zoom = 22.0f;
        
        [_mapViewController goToPosition:center
                                 andZoom:zoom
                                animated:animated];
    }
    
    
    renderView.azimuth = newAzimuth;
    renderView.elevationAngle = newElevationAngle;
}

- (CGFloat) getZoomForBounds:(OAGpxBounds)mapBounds mapSize:(CGSize)mapSize
{
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;
    
    if (mapBounds.topLeft.latitude == DBL_MAX)
        return renderView.zoom;

    float metersPerPixel = [_mapViewController calculateMapRuler];
    
    double distanceH = OsmAnd::Utilities::distance(mapBounds.topLeft.longitude, mapBounds.topLeft.latitude, mapBounds.bottomRight.longitude, mapBounds.topLeft.latitude);
    double distanceV = OsmAnd::Utilities::distance(mapBounds.topLeft.longitude, mapBounds.topLeft.latitude, mapBounds.topLeft.longitude, mapBounds.bottomRight.latitude);
    
    CGFloat newZoomH = distanceH / (mapSize.width * metersPerPixel);
    CGFloat newZoomV = distanceV / (mapSize.height * metersPerPixel);
    CGFloat newZoom = log2(MAX(newZoomH, newZoomV));
    
    CGFloat zoom = renderView.zoom - newZoom;
    if (isnan(zoom))
        zoom = renderView.zoom;
    if (zoom > 22.0f)
        zoom = 22.0f;
    
    return zoom;
}

- (void) doMapReuse:(UIViewController *)destinationViewController destinationView:(UIView *)destinationView
{
    CGRect newFrame = CGRectMake(0, 0, destinationView.bounds.size.width, destinationView.bounds.size.height);
    if (!CGRectEqualToRect(_mapViewController.view.frame, newFrame))
        _mapViewController.view.frame = newFrame;

    [_mapViewController willMoveToParentViewController:nil];
    
    [destinationViewController addChildViewController:_mapViewController];
    [destinationView addSubview:_mapViewController.view];
    [_mapViewController didMoveToParentViewController:self];
    [destinationView bringSubviewToFront:_mapViewController.view];
    
    _mapViewController.minimap = YES;
}

- (void) modifyMapAfterReuse:(Point31)destinationPoint zoom:(CGFloat)zoom azimuth:(float)azimuth elevationAngle:(float)elevationAngle animated:(BOOL)animated
{
    _mapNeedsRestore = NO;
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;
    renderView.azimuth = azimuth;
    renderView.elevationAngle = elevationAngle;
    [_mapViewController goToPosition:destinationPoint andZoom:zoom animated:YES];
    
    _mapViewController.minimap = NO;
}

- (void) modifyMapAfterReuse:(OAGpxBounds)mapBounds azimuth:(float)azimuth elevationAngle:(float)elevationAngle animated:(BOOL)animated
{
    _mapNeedsRestore = NO;
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;
    renderView.azimuth = azimuth;
    renderView.elevationAngle = elevationAngle;
    
    if (mapBounds.topLeft.latitude != DBL_MAX) {
        
        const OsmAnd::LatLon latLon(mapBounds.center.latitude, mapBounds.center.longitude);
        Point31 center = [OANativeUtilities convertFromPointI:OsmAnd::Utilities::convertLatLonTo31(latLon)];
        
        float metersPerPixel = [_mapViewController calculateMapRuler];
        
        double distanceH = OsmAnd::Utilities::distance(mapBounds.topLeft.longitude, mapBounds.topLeft.latitude, mapBounds.bottomRight.longitude, mapBounds.topLeft.latitude);
        double distanceV = OsmAnd::Utilities::distance(mapBounds.topLeft.longitude, mapBounds.topLeft.latitude, mapBounds.topLeft.longitude, mapBounds.bottomRight.latitude);
        
        CGSize mapSize = self.view.bounds.size;
        
        CGFloat newZoomH = distanceH / (mapSize.width * metersPerPixel);
        CGFloat newZoomV = distanceV / (mapSize.height * metersPerPixel);
        CGFloat newZoom = log2(MAX(newZoomH, newZoomV));
        
        CGFloat zoom = renderView.zoom - newZoom;
        if (isnan(zoom))
            zoom = renderView.zoom;
        if (zoom > 22.0f)
            zoom = 22.0f;
        
        [_mapViewController goToPosition:center
                                 andZoom:zoom
                                animated:animated];
    }
    
    _mapViewController.minimap = NO;
}

- (void) restoreMapAfterReuse
{
    _app.mapMode = _mainMapMode;
    
    OAMapRendererView* mapView = (OAMapRendererView*)_mapViewController.view;
    mapView.target31 = _mainMapTarget31;
    mapView.zoom = _mainMapZoom;
    mapView.azimuth = _mainMapAzimuth;
    mapView.elevationAngle = _mainMapEvelationAngle;
    
    _mapViewController.minimap = NO;
}

- (void) restoreMapAfterReuseAnimated
{
    _app.mapMode = _mainMapMode;
 
    if (_mainMapMode == OAMapModeFree || _mainMapMode == OAMapModeUnknown)
    {
        OAMapRendererView* mapView = (OAMapRendererView*)_mapViewController.view;
        mapView.azimuth = _mainMapAzimuth;
        mapView.elevationAngle = _mainMapEvelationAngle;
        [_mapViewController goToPosition:[OANativeUtilities convertFromPointI:_mainMapTarget31] andZoom:_mainMapZoom animated:YES];
    }
    
    _mapViewController.minimap = NO;
}

- (void) doMapRestore
{
    [_mapViewController hideTempGpxTrack];
    
    _mapViewController.view.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    
    [_mapViewController willMoveToParentViewController:nil];
    
    [self addChildViewController:_mapViewController];
    [self.view addSubview:_mapViewController.view];
    [_mapViewController didMoveToParentViewController:self];
    [self.view sendSubviewToBack:_mapViewController.view];
}

- (void) hideContextMenu
{
    [self targetHideMenu:.2 backButtonClicked:NO onComplete:nil];
}

- (BOOL) isContextMenuVisible
{
    return (_targetMenuView && _targetMenuView.superview) || (_targetMultiMenuView && _targetMultiMenuView.superview);
}

- (void) closeDashboard
{
    [self closeDashboardWithDuration:.3];
}

- (void) closeDashboardWithDuration:(CGFloat)duration
{
    if (_dashboard)
    {
        if ([_dashboard isKindOfClass:[OAMapSettingsViewController class]])
            [self updateOverlayUnderlayView:[self.hudViewController isOverlayUnderlayViewVisible]];
        
        OADashboardViewController* lastMapSettingsCtrl = [self.childViewControllers lastObject];
        if (lastMapSettingsCtrl)
            [lastMapSettingsCtrl hide:YES animated:YES duration:duration];
        
        [self destroyShadowButton];
        
        if (([_dashboard isKindOfClass:[OARoutePreferencesViewController class]] || [_dashboard isKindOfClass:[OAWaypointsViewController class]]) && _routeInfoView.superview)
            [self createShadowButton:@selector(closeRouteInfo) withLongPressEvent:nil topView:_routeInfoView];

        _dashboard = nil;

        [self.targetMenuView quickShow];

        self.sidePanelController.recognizesPanGesture = NO; //YES;
    }
}

- (void) closeRouteInfo
{
    [self closeRouteInfoWithDuration:.3];
}

- (void) closeRouteInfoWithDuration:(CGFloat)duration
{
    if (self.routeInfoView.superview)
    {
        [self.routeInfoView hide:YES duration:duration onComplete:nil];
        
        [self destroyShadowButton];
        
        self.sidePanelController.recognizesPanGesture = NO; //YES;
    }
}

- (CGRect) shadowButtonRect
{
    return self.view.frame;
}

- (void) removeGestureRecognizers
{
    while (self.view.gestureRecognizers.count > 0)
        [self.view removeGestureRecognizer:self.view.gestureRecognizers[0]];
}

- (void) mapSettingsButtonClick:(id)sender
{
    [OAFirebaseHelper logEvent:@"configure_map_open"];
    
    [self removeGestureRecognizers];
    
    _dashboard = [[OAMapSettingsViewController alloc] init];
    [_dashboard show:self parentViewController:nil animated:YES];
    
    [self createShadowButton:@selector(closeDashboard) withLongPressEvent:nil topView:_dashboard.view];
    
    [self.targetMenuView quickHide];

    self.sidePanelController.recognizesPanGesture = NO;
}

- (void) showConfigureScreen
{
    [OAFirebaseHelper logEvent:@"configure_screen_open"];
    
    [self removeGestureRecognizers];
    
    _dashboard = [[OAConfigureMenuViewController alloc] init];
    [_dashboard show:self parentViewController:nil animated:YES];
    
    [self createShadowButton:@selector(closeDashboard) withLongPressEvent:nil topView:_dashboard.view];
    
    [self.targetMenuView quickHide];
    
    self.sidePanelController.recognizesPanGesture = NO;
}

- (void) showWaypoints
{
    [OAFirebaseHelper logEvent:@"waypoints_open"];
    
    [self removeGestureRecognizers];
    
    _dashboard = [[OAWaypointsViewController alloc] init];
    [_dashboard show:self parentViewController:nil animated:YES];
    
    [self createShadowButton:@selector(closeDashboard) withLongPressEvent:nil topView:_dashboard.view];
    
    [self.targetMenuView quickHide];
    
    self.sidePanelController.recognizesPanGesture = NO;
}

- (void) showRoutePreferences
{
    [OAFirebaseHelper logEvent:@"route_preferences_open"];
    
    [self removeGestureRecognizers];
    
    _dashboard = [[OARoutePreferencesViewController alloc] init];
    [_dashboard show:self parentViewController:nil animated:YES];
    
    [self createShadowButton:@selector(closeDashboard) withLongPressEvent:nil topView:_dashboard.view];
    
    [self.targetMenuView quickHide];
    
    self.sidePanelController.recognizesPanGesture = NO;
}

- (void) showAvoidRoads
{
    [OAFirebaseHelper logEvent:@"avoid_roads_open"];
    
    [self removeGestureRecognizers];
    
    _dashboard = [[OARoutePreferencesViewController alloc] initWithAvoiRoadsScreen];
    [_dashboard show:self parentViewController:nil animated:YES];
    
    [self createShadowButton:@selector(closeDashboard) withLongPressEvent:nil topView:_dashboard.view];
    
    [self.targetMenuView quickHide];
    
    self.sidePanelController.recognizesPanGesture = NO;
}

- (void) showRouteInfo
{
    [OAFirebaseHelper logEvent:@"route_info_open"];
    
    [self removeGestureRecognizers];
    
    if (self.targetMenuView.superview)
    {
        [self hideTargetPointMenu:.2 onComplete:^{
            [self showRouteInfoInternal];
        }];
    }
    else
    {
        [self showRouteInfoInternal];
    }
}

- (void) showRouteInfoInternal
{
    CGRect frame = self.routeInfoView.frame;
    frame.origin.y = DeviceScreenHeight + 10.0;
    self.routeInfoView.frame = frame;
    
    [self.routeInfoView.layer removeAllAnimations];
    if ([self.view.subviews containsObject:self.routeInfoView])
        [self.routeInfoView removeFromSuperview];
    
    [self.view addSubview:self.routeInfoView];
    
    self.sidePanelController.recognizesPanGesture = NO;
    [self.routeInfoView show:YES onComplete:^{
        self.sidePanelController.recognizesPanGesture = NO;
    }];
    
    [self createShadowButton:@selector(closeRouteInfo) withLongPressEvent:nil topView:_routeInfoView];
}

- (void) updateRouteInfo
{
    if (self.routeInfoView.superview)
        [self.routeInfoView updateMenu];
}

- (void) addWaypoint
{
    [self.routeInfoView addWaypoint];
}

- (void) searchButtonClick:(id)sender
{
    [self openSearch];
}

- (void) openSearch
{
    [self openSearch:OAQuickSearchType::REGULAR];
}

- (void) openSearch:(OAQuickSearchType)searchType
{
    [self openSearch:searchType location:nil tabIndex:-1];
}

- (void) openSearch:(OAQuickSearchType)searchType location:(CLLocation *)location tabIndex:(NSInteger)tabIndex
{
    [self openSearch:searchType location:location tabIndex:tabIndex searchQuery:nil];
}

- (void) openSearch:(OAQuickSearchType)searchType location:(CLLocation *)location tabIndex:(NSInteger)tabIndex searchQuery:(NSString *)searchQuery
{
    [OAFirebaseHelper logEvent:@"search_open"];
    
    [self removeGestureRecognizers];
    
    OAMapRendererView* mapView = (OAMapRendererView*)_mapViewController.view;
    BOOL isMyLocationVisible = [_mapViewController isMyLocationVisible];
    
    BOOL searchNearMapCenter = NO;
    OsmAnd::PointI searchLocation;
    
    CLLocation* newLocation = [OsmAndApp instance].locationServices.lastKnownLocation;
    OsmAnd::PointI myLocation;
    double distanceFromMyLocation = 0;
    if (location)
    {
        searchLocation = OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(location.coordinate.latitude, location.coordinate.longitude));
        searchNearMapCenter = YES;
    }
    else if (newLocation)
    {
        myLocation = OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(newLocation.coordinate.latitude, newLocation.coordinate.longitude));
        if (!isMyLocationVisible)
        {
            distanceFromMyLocation = OsmAnd::Utilities::distance31(myLocation, mapView.target31);
            if (distanceFromMyLocation > 15000)
            {
                searchNearMapCenter = YES;
                searchLocation = mapView.target31;
            }
            else
            {
                searchLocation = myLocation;
            }
        }
        else
        {
            searchLocation = myLocation;
        }
    }
    else
    {
        searchNearMapCenter = YES;
        searchLocation = mapView.target31;
    }
    
    if (!_searchViewController || location || searchQuery)
        _searchViewController = [[OAQuickSearchViewController alloc] init];
    
    _searchViewController.myLocation = searchLocation;
    _searchViewController.distanceFromMyLocation = distanceFromMyLocation;
    _searchViewController.searchNearMapCenter = searchNearMapCenter;
    _searchViewController.searchType = searchType;
    if (searchQuery)
        _searchViewController.searchQuery = searchQuery;
    if (tabIndex != -1)
        _searchViewController.tabIndex = tabIndex;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:_searchViewController];
    navController.navigationBarHidden = YES;
    navController.automaticallyAdjustsScrollViewInsets = NO;
    navController.edgesForExtendedLayout = UIRectEdgeNone;
    
    [self.navigationController presentViewController:navController animated:YES completion:nil];
}

- (void) setRouteTargetPoint:(BOOL)target intermediate:(BOOL)intermediate latitude:(double)latitude longitude:(double)longitude pointDescription:(OAPointDescription *)pointDescription
{
    if (!target && !intermediate)
    {
        [[OATargetPointsHelper sharedInstance] setStartPoint:[[CLLocation alloc] initWithLatitude:latitude longitude:longitude] updateRoute:YES name:pointDescription];
    }
    else
    {
        [[OATargetPointsHelper sharedInstance] navigateToPoint:[[CLLocation alloc] initWithLatitude:latitude longitude:longitude] updateRoute:YES intermediate:(!intermediate ? -1 : (int)[[OATargetPointsHelper sharedInstance] getIntermediatePoints].count) historyName:pointDescription];
    }
    if (self.routeInfoView.superview)
    {
        [self.routeInfoView update];
    }
}

- (void) processNoSymbolFound:(CLLocationCoordinate2D)coord
{
    [self.targetMenuView hideByMapGesture];

    OATargetPoint *targetPoint = [[OATargetPoint alloc] init];
    targetPoint.type = OATargetNone;
    targetPoint.location = coord;
    [self processTargetPoint:targetPoint];
}

- (void) onMapGestureAction:(NSNotification *)notification
{
    [self.targetMenuView hideByMapGesture];
}

- (NSString *) convertHTML:(NSString *)html
{
    NSScanner *myScanner;
    NSString *text = nil;
    myScanner = [NSScanner scannerWithString:html];
    
    while ([myScanner isAtEnd] == NO) {
        
        [myScanner scanUpToString:@"<" intoString:NULL] ;
        
        [myScanner scanUpToString:@">" intoString:&text] ;
        
        html = [html stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@>", text] withString:@""];
    }
    //
    html = [html stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    return html;
}

- (void) applyTargetPointController:(OATargetPoint *)targetPoint
{
    OATargetMenuViewController *controller = [OATargetMenuViewController createMenuController:targetPoint activeTargetType:_activeTargetType activeViewControllerState:_activeViewControllerState];
    if (controller)
    {
        targetPoint.ctrlAttrTypeStr = [controller getAttributedTypeStr];
        targetPoint.ctrlTypeStr = [controller getTypeStr];
    }
}

- (void) reopenContextMenu
{
    if (!self.targetMenuView.superview)
    {
        [self showTargetPointMenu:YES showFullMenu:NO];
    }
}

- (void) showContextMenuWithPoints:(NSArray<OATargetPoint *> *)targetPoints
{
    NSMutableArray<OATargetPoint *> *validPoints = [NSMutableArray array];
    for (OATargetPoint *targetPoint in targetPoints)
    {
        if ([self processTargetPoint:targetPoint])
            [validPoints addObject:targetPoint];
    }
    
    if (validPoints.count == 0)
    {
        return;
    }
    else if (validPoints.count == 1)
    {
        [self showContextMenu:validPoints[0]];
    }
    else
    {
        for (OATargetPoint *targetPoint in validPoints)
            [self applyTargetPointController:targetPoint];

        [self showMultiContextMenu:validPoints];
    }
}

- (void) showMultiContextMenu:(NSArray<OATargetPoint *> *)points
{
    [self showMultiPointMenu:points onComplete:^{
        
    }];
}

- (void) showContextMenu:(OATargetPoint *)targetPoint
{
    if (targetPoint.type == OATargetMapillaryImage)
    {
        [_mapillaryController showImage:targetPoint.targetObj];
        [self applyTargetPoint:targetPoint];
        [self goToTargetPointDefault];
        [self hideMultiMenuIfNeeded];
        [self setNeedsStatusBarAppearanceUpdate];
        return;
    }
    // show context marker on map
    [_mapViewController showContextPinMarker:targetPoint.location.latitude longitude:targetPoint.location.longitude animated:YES];
    
    [self applyTargetPoint:targetPoint];    
    [_targetMenuView setTargetPoint:targetPoint];
    [self showTargetPointMenu:YES showFullMenu:NO onComplete:^{
        
        if (targetPoint.centerMap)
            [self goToTargetPointDefault];
        
        if (_activeTargetType == OATargetGPXEdit && targetPoint.type != OATargetWpt)
            [self targetPointAddWaypoint];
    }];
}

- (void) updateContextMenu:(OATargetPoint *)targetPoint
{
    // show context marker on map
    [_mapViewController showContextPinMarker:targetPoint.location.latitude longitude:targetPoint.location.longitude animated:YES];
    
    [self applyTargetPoint:targetPoint];
    [_targetMenuView setTargetPoint:targetPoint];
    [self.targetMenuView applyTargetObjectChanges];
    if (targetPoint.centerMap)
        [self goToTargetPointDefault];
}

- (BOOL) processTargetPoint:(OATargetPoint *)targetPoint
{
    if (!_activeTargetType)
        return YES;
    
    BOOL isNone = targetPoint.type == OATargetNone;
    BOOL isWaypoint = targetPoint.type == OATargetWpt;
    
    switch (_activeTargetType)
    {
        // while we are in view GPX mode - waypoints can be pressed only
        case OATargetGPX:
        {
            if (!isWaypoint && !isNone)
            {
                [_mapViewController hideContextPinMarker];
                return NO;
            }
            break;
        }
        case OATargetGPXEdit:
        {
            if (isWaypoint)
            {
                NSString *path = ((OAGPX *)_activeTargetObj).gpxFileName;
                if (_mapViewController.foundWpt && ![[_mapViewController.foundWptDocPath lastPathComponent] isEqualToString:path])
                {
                    [_mapViewController hideContextPinMarker];
                    return NO;
                }
            }
            break;
        }
        case OATargetRouteStartSelection:
        case OATargetRouteFinishSelection:
        case OATargetRouteIntermediateSelection:
        {
            [_mapViewController hideContextPinMarker];
            
            OAPointDescription *pointDescription = nil;
            if (!isNone)
                pointDescription = [[OAPointDescription alloc] initWithType:POINT_TYPE_LOCATION name:targetPoint.title];
                
            if (_activeTargetType == OATargetRouteStartSelection)
                [[OATargetPointsHelper sharedInstance] setStartPoint:[[CLLocation alloc] initWithLatitude:targetPoint.location.latitude longitude:targetPoint.location.longitude] updateRoute:YES name:pointDescription];
            else
                [[OATargetPointsHelper sharedInstance] navigateToPoint:[[CLLocation alloc] initWithLatitude:targetPoint.location.latitude longitude:targetPoint.location.longitude] updateRoute:YES intermediate:(_activeTargetType != OATargetRouteIntermediateSelection ? -1 : (int)[[OATargetPointsHelper sharedInstance] getIntermediatePoints].count) historyName:pointDescription];

            [self hideTargetPointMenu];
            [[OARootViewController instance].mapPanel showRouteInfo];
            
            return NO;
        }
        case OATargetImpassableRoadSelection:
        {
            [_mapViewController hideContextPinMarker];
            
            [[OAAvoidSpecificRoads instance] addImpassableRoad:[[CLLocation alloc] initWithLatitude:targetPoint.location.latitude longitude:targetPoint.location.longitude] showDialog:YES skipWritingSettings:NO];
            
            [self hideTargetPointMenu:.2 onComplete:^{
                [self showAvoidRoads];
            }];
            
            return NO;
        }
        case OATargetGPXRoute:
        {
            if (!isWaypoint)
            {
                [_mapViewController hideContextPinMarker];
                return NO;
            }
            else if (!isNone)
            {
                NSString *path = [OAGPXRouter sharedInstance].gpx.gpxFileName;
                if (_mapViewController.foundWpt && ![[_mapViewController.foundWptDocPath lastPathComponent] isEqualToString:path])
                {
                    [_mapViewController hideContextPinMarker];
                    return NO;
                }
            }
            break;
        }

        default:
            break;
    }
    
    return YES;
}

- (void) applyTargetPoint:(OATargetPoint *)targetPoint
{
    _targetDestination = nil;
    
    _targetMenuView.isAddressFound = targetPoint.addressFound;
    _formattedTargetName = targetPoint.title;

    if (targetPoint.type == OATargetDestination || targetPoint.type == OATargetParking)
    {
        _targetDestination = targetPoint.targetObj;
    }
    else if (targetPoint.type == OATargetWpt)
    {
        if ([targetPoint.targetObj isKindOfClass:[OAGpxWptItem class]])
        {
            OAGpxWptItem *item = (OAGpxWptItem *)targetPoint.targetObj;
            _mapViewController.foundWpt = item.point;
            _mapViewController.foundWptGroups = item.groups;
            _mapViewController.foundWptDocPath = item.docPath;
        }
    }
    _targetMode = EOATargetPoint;
    _targetLatitude = targetPoint.location.latitude;
    _targetLongitude = targetPoint.location.longitude;
    _targetZoom = 0.0;
}

- (NSString *) findRoadNameByLat:(double)lat lon:(double)lon
{
    return [[OAReverseGeocoder instance] lookupAddressAtLat:lat lon:lon];
}

- (void) goToTargetPointDefault
{
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;
    renderView.azimuth = 0.0;
    renderView.elevationAngle = 90.0;
    renderView.zoom = kDefaultFavoriteZoomOnShow;
    
    _mainMapAzimuth = 0.0;
    _mainMapEvelationAngle = 90.0;
    _mainMapZoom = kDefaultFavoriteZoomOnShow;
    
    [self targetGoToPoint];
}

- (void) createShadowButton:(SEL)action withLongPressEvent:(SEL)withLongPressEvent topView:(UIView *)topView
{
    if (_shadowButton && [self.view.subviews containsObject:_shadowButton])
        [self destroyShadowButton];
    
    self.shadowButton = [[UIButton alloc] initWithFrame:[self shadowButtonRect]];
    [_shadowButton setBackgroundColor:[UIColor colorWithWhite:0.3 alpha:0]];
    [_shadowButton addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    if (withLongPressEvent) {
        _shadowLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:withLongPressEvent];
        [_shadowButton addGestureRecognizer:_shadowLongPress];
    }
    
    [self.view insertSubview:self.shadowButton belowSubview:topView];
}

- (void) destroyShadowButton
{
    if (_shadowButton)
    {
        [_shadowButton removeFromSuperview];
        if (_shadowLongPress) {
            [_shadowButton removeGestureRecognizer:_shadowLongPress];
            _shadowLongPress = nil;
        }
        self.shadowButton = nil;
    }
}

- (void)shadowTargetPointLongPress:(UILongPressGestureRecognizer*)gesture
{
    if (![self.targetMenuView preHide])
        return;

    if ( gesture.state == UIGestureRecognizerStateEnded )
        [_mapViewController simulateContextMenuPress:gesture];
}

- (void) showTopControls
{
    [self.hudViewController showTopControls];
    
    _topControlsVisible = YES;
}

- (void) hideTopControls
{
    [self.hudViewController hideTopControls];

    _topControlsVisible = NO;
}

- (void) setTopControlsVisible:(BOOL)visible
{
    [self setTopControlsVisible:visible customStatusBarStyle:UIStatusBarStyleLightContent];
}

- (void) setTopControlsVisible:(BOOL)visible customStatusBarStyle:(UIStatusBarStyle)customStatusBarStyle
{
    if (visible)
    {
        [self showTopControls];
        _customStatusBarStyleNeeded = NO;
        [self setNeedsStatusBarAppearanceUpdate];
    }
    else
    {
        [self hideTopControls];
        _customStatusBarStyle = customStatusBarStyle;
        _customStatusBarStyleNeeded = YES;
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

- (BOOL) isTopControlsVisible
{
    return _topControlsVisible;
}

- (BOOL) contextMenuMode
{
    if (self.hudViewController)
        return self.hudViewController.contextMenuMode;
    else
        return NO;
}

- (void) enterContextMenuMode
{
    EOAMapModeButtonType mapModeButtonType;
    switch (_activeTargetType)
    {
        case OATargetGPX:
            mapModeButtonType = EOAMapModeButtonTypeShowMap;
            break;
        case OATargetGPXRoute:
            mapModeButtonType = EOAMapModeButtonTypeNavigate;
            break;
            
        default:
            mapModeButtonType = EOAMapModeButtonRegular;
            break;
    }
    
    self.hudViewController.mapModeButtonType = mapModeButtonType;
    [self.hudViewController enterContextMenuMode];
}

- (void) restoreFromContextMenuMode
{
    [self.hudViewController restoreFromContextMenuMode];
}

- (void) showBottomControls:(CGFloat)menuHeight animated:(BOOL)animated
{
    [self.hudViewController showBottomControls:menuHeight animated:animated];
}

- (void) hideBottomControls:(CGFloat)menuHeight animated:(BOOL)animated
{
    [self.hudViewController hideBottomControls:menuHeight animated:animated];
}

- (void) setBottomControlsVisible:(BOOL)visible menuHeight:(CGFloat)menuHeight animated:(BOOL)animated
{
    if (visible)
        [self showBottomControls:menuHeight animated:animated];
    else
        [self hideBottomControls:menuHeight animated:animated];
}

- (void) storeActiveTargetViewControllerState
{
    switch (_activeTargetType)
    {
        case OATargetGPX:
        {
            OAGPXItemViewControllerState *gpxItemViewControllerState = (OAGPXItemViewControllerState *)([((OAGPXItemViewController *)self.targetMenuView.customController) getCurrentState]);
            gpxItemViewControllerState.showFull = self.targetMenuView.showFull;
            gpxItemViewControllerState.showFullScreen = self.targetMenuView.showFullScreen;
            gpxItemViewControllerState.showCurrentTrack = (!_activeTargetObj || ((OAGPX *)_activeTargetObj).gpxFileName.length == 0);
            
            _activeViewControllerState = gpxItemViewControllerState;
            break;
        }

        case OATargetGPXEdit:
        {
            OAGPXEditItemViewControllerState *gpxItemViewControllerState = (OAGPXEditItemViewControllerState *)([((OAGPXEditItemViewController *)self.targetMenuView.customController) getCurrentState]);
            gpxItemViewControllerState.showFullScreen = self.targetMenuView.showFullScreen;
            gpxItemViewControllerState.showCurrentTrack = (!_activeTargetObj || ((OAGPX *)_activeTargetObj).gpxFileName.length == 0);
            
            _activeViewControllerState = gpxItemViewControllerState;
            break;
        }
            
        case OATargetGPXRoute:
        {
            OAGPXRouteViewControllerState *gpxItemViewControllerState = (OAGPXRouteViewControllerState *)([((OAGPXRouteViewController *)self.targetMenuView.customController) getCurrentState]);
            gpxItemViewControllerState.showFullScreen = self.targetMenuView.showFullScreen;
            gpxItemViewControllerState.showCurrentTrack = (!_activeTargetObj || ((OAGPX *)_activeTargetObj).gpxFileName.length == 0);
            
            _activeViewControllerState = gpxItemViewControllerState;
            break;
        }
            
        default:
            break;
    }
}

- (void) restoreActiveTargetMenu
{
    switch (_activeTargetType)
    {
        case OATargetGPX:
            [_mapViewController hideContextPinMarker];
            [self openTargetViewWithGPX:_activeTargetObj pushed:YES];
            break;

        case OATargetGPXEdit:
            [_mapViewController hideContextPinMarker];
            [self openTargetViewWithGPXEdit:_activeTargetObj pushed:YES];
            break;
            
        case OATargetGPXRoute:
            [_mapViewController hideContextPinMarker];
            [[OARootViewController instance].mapPanel openTargetViewWithGPXRoute:YES segmentType:kSegmentRouteWaypoints];
            break;
            
        default:
            break;
    }
}

- (void) resetActiveTargetMenu
{
    if ([self hasGpxActiveTargetType] && _activeTargetObj)
        ((OAGPX *)_activeTargetObj).newGpx = NO;
    
    _activeTargetActive = NO;
    _activeTargetObj = nil;
    _activeTargetType = OATargetNone;
    _activeViewControllerState = nil;

    _targetMenuView.activeTargetType = _activeTargetType;
    
    [self restoreFromContextMenuMode];
}

- (void) onDestinationRemove:(id)observable withKey:(id)key
{
    //OADestination *destination = key;
    dispatch_async(dispatch_get_main_queue(), ^{
        _targetDestination = nil;
        [_mapViewController hideContextPinMarker];
    });
}

- (void) createShade
{
    if (_shadeView)
    {
        [_shadeView removeFromSuperview];
        _shadeView = nil;
    }
    
    _shadeView = [[UIView alloc] initWithFrame:self.view.frame];
    _shadeView.backgroundColor = UIColorFromRGBA(0x00000060);
    _shadeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _shadeView.alpha = 0.0;
}

- (void) removeShade
{
    [_shadeView removeFromSuperview];
    _shadeView = nil;
}

-(BOOL) gpxModeActive
{
    return (_activeTargetActive &&
        (_activeTargetType == OATargetGPX || _activeTargetType == OATargetGPXEdit || _activeTargetType == OATargetGPXRoute));
}

#pragma mark - OATargetPointViewDelegate

- (void) targetResetCustomStatusBarStyle
{
    _customStatusBarStyleNeeded = NO;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void) targetViewEnableMapInteraction
{
    if (self.shadowButton)
        self.shadowButton.hidden = YES;
}

- (void) targetViewDisableMapInteraction
{
    if (self.shadowButton)
        self.shadowButton.hidden = NO;
}

- (void) targetZoomIn
{
    [_mapViewController animatedZoomIn];
}

- (void) targetZoomOut
{
    [_mapViewController animatedZoomOut];
    [_mapViewController calculateMapRuler];
}

- (void) navigate:(OATargetPoint *)targetPoint
{
    [_mapActions navigate:targetPoint];
}

- (void) navigateFrom:(OATargetPoint *)targetPoint
{
    [_mapActions enterRoutePlanningMode:[[CLLocation alloc] initWithLatitude:targetPoint.location.latitude
                                                                   longitude:targetPoint.location.longitude]
                               fromName:targetPoint.pointDescription checkDisplayedGpx:NO];
}

- (void) targetPointAddFavorite
{
    if ([_mapViewController hasFavoriteAt:CLLocationCoordinate2DMake(_targetLatitude, _targetLongitude)])
        return;
    
    OAFavoriteViewController *favoriteViewController = [[OAFavoriteViewController alloc] initWithLocation:self.targetMenuView.targetPoint.location andTitle:self.targetMenuView.targetPoint.title];
    
    UIColor* color = [UIColor colorWithRed:favoriteViewController.favorite.favorite->getColor().r/255.0 green:favoriteViewController.favorite.favorite->getColor().g/255.0 blue:favoriteViewController.favorite.favorite->getColor().b/255.0 alpha:1.0];
    OAFavoriteColor *favCol = [OADefaultFavorite nearestFavColor:color];
    self.targetMenuView.targetPoint.icon = [UIImage imageNamed:favCol.iconName];
    self.targetMenuView.targetPoint.type = OATargetFavorite;
    
    [favoriteViewController activateEditing];
    
    [self.targetMenuView setCustomViewController:favoriteViewController needFullMenu:YES];
    [self.targetMenuView updateTargetPointType:OATargetFavorite];
}

- (void) targetPointShare
{
}

- (void) targetPointDirection
{
    if (_targetDestination)
    {
        if (self.targetMenuView.targetPoint.type != OATargetDestination && self.targetMenuView.targetPoint.type != OATargetParking)
            return;

        dispatch_async(dispatch_get_main_queue(), ^{
            [[OADestinationsHelper instance] addHistoryItem:_targetDestination];
            [[OADestinationsHelper instance] removeDestination:_targetDestination];
        });
    }
    else if (self.targetMenuView.targetPoint.type == OATargetImpassableRoad)
    {
        OAAvoidSpecificRoads *avoidRoads = [OAAvoidSpecificRoads instance];
        NSNumber *roadId = self.targetMenuView.targetPoint.targetObj;
        if (roadId)
        {
            const auto& road = [avoidRoads getRoadById:roadId.unsignedLongLongValue];
            if (road)
            {
                [avoidRoads removeImpassableRoad:road];
                [_mapViewController hideContextPinMarker];
            }
        }
    }
    else
    {
        OADestination *destination = [[OADestination alloc] initWithDesc:_formattedTargetName latitude:_targetLatitude longitude:_targetLongitude];

        UIColor *color = [_destinationViewController addDestination:destination];
        if (color)
        {
            [_mapViewController hideContextPinMarker];
            [[OADestinationsHelper instance] moveDestinationOnTop:destination wasSelected:NO];
        }
        else
        {
            [[[UIAlertView alloc] initWithTitle:OALocalizedString(@"cannot_add_destination") message:OALocalizedString(@"cannot_add_marker_desc") delegate:nil cancelButtonTitle:OALocalizedString(@"shared_string_ok") otherButtonTitles:nil
              ] show];
        }
    }
    
    [self hideTargetPointMenu];
}

- (void) targetPointParking
{
    OAParkingViewController *parking = [[OAParkingViewController alloc] initWithCoordinate:CLLocationCoordinate2DMake(_targetLatitude, _targetLongitude)];
    parking.parkingDelegate = self;
    
    [self.targetMenuView setCustomViewController:parking needFullMenu:YES];
    [self.targetMenuView updateTargetPointType:OATargetParking];
}

- (void) targetPointAddWaypoint
{
    if ([_mapViewController hasWptAt:CLLocationCoordinate2DMake(_targetLatitude, _targetLongitude)])
        return;
    
    NSMutableArray *names = [NSMutableArray array];
    NSMutableArray *paths = [NSMutableArray array];
    
    OAAppSettings *settings = [OAAppSettings sharedManager];
    for (NSString *fileName in settings.mapSettingVisibleGpx)
    {
        NSString *path = [_app.gpxPath stringByAppendingPathComponent:fileName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            [names addObject:[fileName stringByDeletingPathExtension]];
            [paths addObject:path];
        }
    }
    
    // Ask for track where to add waypoint
    if (names.count > 0)
    {
        if ([self hasGpxActiveTargetType])
        {
            if (_activeTargetObj)
            {
                OAGPX *gpx = (OAGPX *)_activeTargetObj;
                NSString *path = [_app.gpxPath stringByAppendingPathComponent:gpx.gpxFileName];
                [self targetPointAddWaypoint:path];
            }
            else
            {
                [self targetPointAddWaypoint:nil];
            }
            return;
        }
        
        [names insertObject:OALocalizedString(@"gpx_curr_new_track") atIndex:0];
        [paths insertObject:@"" atIndex:0];
        
        if (names.count > 5)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" message:OALocalizedString(@"gpx_select_track") cancelButtonItem:[RIButtonItem itemWithLabel:OALocalizedString(@"shared_string_cancel")] otherButtonItems: nil];
            
            for (int i = 0; i < names.count; i++)
            {
                NSString *name = names[i];
                [alert addButtonItem:[RIButtonItem itemWithLabel:name action:^{
                    NSString *gpxFileName = paths[i];
                    if (gpxFileName.length == 0)
                        gpxFileName = nil;
                    
                    [self targetPointAddWaypoint:gpxFileName];
                }]];
            }
            [alert show];
        }
        else
        {
            NSMutableArray *images = [NSMutableArray array];
            for (int i = 0; i < names.count; i++)
                [images addObject:@"icon_info"];
            
            [PXAlertView showAlertWithTitle:OALocalizedString(@"gpx_select_track")
                                    message:nil
                                cancelTitle:OALocalizedString(@"shared_string_cancel")
                                otherTitles:names
                                  otherDesc:nil
                                otherImages:images
                                 completion:^(BOOL cancelled, NSInteger buttonIndex) {
                                     if (!cancelled)
                                     {
                                         NSInteger trackId = buttonIndex;
                                         NSString *gpxFileName = paths[trackId];
                                         if (gpxFileName.length == 0)
                                             gpxFileName = nil;
                                         
                                         [self targetPointAddWaypoint:gpxFileName];
                                     }
                                 }];
        }
        
    }
    else
    {
        [self targetPointAddWaypoint:nil];
    }
}

- (void) targetPointAddWaypoint:(NSString *)gpxFileName
{
    OAGPXWptViewController *wptViewController = [[OAGPXWptViewController alloc] initWithLocation:self.targetMenuView.targetPoint.location andTitle:self.targetMenuView.targetPoint.title gpxFileName:gpxFileName];
    
    wptViewController.mapViewController = self.mapViewController;
    wptViewController.wptDelegate = self;
    
    [_mapViewController addNewWpt:wptViewController.wpt.point gpxFileName:gpxFileName];
    wptViewController.wpt.groups = _mapViewController.foundWptGroups;

    UIColor* color = wptViewController.wpt.color;
    OAFavoriteColor *favCol = [OADefaultFavorite nearestFavColor:color];
    
    self.targetMenuView.targetPoint.type = OATargetWpt;
    self.targetMenuView.targetPoint.icon = [UIImage imageNamed:favCol.iconName];
    self.targetMenuView.targetPoint.targetObj = wptViewController.wpt;
    
    [wptViewController activateEditing];
    
    [self.targetMenuView setCustomViewController:wptViewController needFullMenu:YES];
    [self.targetMenuView updateTargetPointType:OATargetWpt];
    
    if (_activeTargetType == OATargetGPXEdit)
        wptViewController.navBarBackground.backgroundColor = UIColorFromRGB(0x4caf50);

    if (!gpxFileName && ![OAAppSettings sharedManager].mapSettingShowRecordingTrack)
    {
        [OAAppSettings sharedManager].mapSettingShowRecordingTrack = YES;
        [[_app updateRecTrackOnMapObservable] notifyEvent];
    }
}

- (void) targetHideContextPinMarker
{
    [_mapViewController hideContextPinMarker];
}

- (void) targetHide
{
    [_mapViewController hideContextPinMarker];
    [self hideTargetPointMenu];
}

- (void) targetHideMenu:(CGFloat)animationDuration backButtonClicked:(BOOL)backButtonClicked onComplete:(void (^)(void))onComplete
{
    if (backButtonClicked)
    {
        if (_activeTargetType != OATargetNone && !_activeTargetActive)
            animationDuration = .1;
        
        [self hideTargetPointMenuAndPopup:animationDuration onComplete:onComplete];
    }
    else
    {
        [self hideTargetPointMenu:animationDuration onComplete:onComplete];
    }
}

- (void) targetGoToPoint
{
    OsmAnd::LatLon latLon(_targetLatitude, _targetLongitude);
    Point31 point = [OANativeUtilities convertFromPointI:OsmAnd::Utilities::convertLatLonTo31(latLon)];
    _mainMapTarget31 = OsmAnd::Utilities::convertLatLonTo31(latLon);

    BOOL landscape = [self.targetMenuView isLandscape];
    CGFloat leftInset = 0;
    CGFloat bottomInset = 0;
    if (self.targetMenuView.superview)
    {
        leftInset = landscape ? kInfoViewLanscapeWidth : 0.0;
        bottomInset = landscape ? 0.0 : [self.targetMenuView getVisibleHeight];
    }
    else if ([OARouteInfoView isVisible])
    {
        leftInset = landscape ? kInfoViewLanscapeWidth : 0.0;
        bottomInset = landscape ? 0.0 : self.routeInfoView.frame.size.height;
    }
    
    [_mapViewController correctPosition:point originalCenter31:[OANativeUtilities convertFromPointI:_mainMapTarget31] leftInset:leftInset bottomInset:bottomInset centerBBox:(_targetMode == EOATargetBBOX) animated:YES];

}

- (void) targetGoToGPX
{
    if (_activeTargetObj)
        [self displayGpxOnMap:_activeTargetObj];
    else
        [self displayGpxOnMap:[[OASavingTrackHelper sharedInstance] getCurrentGPX]];
}

- (void) targetGoToGPXRoute
{
    [self openTargetViewWithGPXRoute:_activeTargetObj pushed:YES];
}

- (void) targetViewHeightChanged:(CGFloat)height animated:(BOOL)animated
{
    if (self.targetMenuView.targetPoint.type == OATargetGPX || self.targetMenuView.targetPoint.type == OATargetGPXEdit || (![self.targetMenuView isLandscape] && self.targetMenuView.showFullScreen))
        return;
    
    Point31 targetPoint31 = [OANativeUtilities convertFromPointI:OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(_targetLatitude, _targetLongitude))];
    [_mapViewController correctPosition:targetPoint31 originalCenter31:[OANativeUtilities convertFromPointI:_mainMapTarget31] leftInset:([self.targetMenuView isLandscape] ? kInfoViewLanscapeWidth : 0.0) bottomInset:([self.targetMenuView isLandscape] ? 0.0 : height) centerBBox:(_targetMode == EOATargetBBOX) animated:animated];
}

- (void) showTargetPointMenu:(BOOL)saveMapState showFullMenu:(BOOL)showFullMenu
{
    [self showTargetPointMenu:saveMapState showFullMenu:showFullMenu onComplete:nil];
}

- (void)hideMultiMenuIfNeeded {
    if (self.targetMultiMenuView.superview)
        [self.targetMultiMenuView hide:YES duration:.2 onComplete:nil];
}

- (void) showTargetPointMenu:(BOOL)saveMapState showFullMenu:(BOOL)showFullMenu onComplete:(void (^)(void))onComplete
{
    [self hideMultiMenuIfNeeded];

    if (_activeTargetActive)
    {
        [self storeActiveTargetViewControllerState];
        _activeTargetActive = NO;
        BOOL activeTargetChildPushed = _activeTargetChildPushed;
        _activeTargetChildPushed = NO;
        
        [self hideTargetPointMenu:.1 onComplete:^{
            
            [self showTargetPointMenu:saveMapState showFullMenu:showFullMenu onComplete:onComplete];
            _activeTargetChildPushed = activeTargetChildPushed;
            
        } hideActiveTarget:YES mapGestureAction:NO];
        
        return;
    }
    
    if (_dashboard)
        [self closeDashboard];
    
    if (saveMapState)
        [self saveMapStateNoRestore];
    
    _mapStateSaved = saveMapState;
    
    OATargetMenuViewController *controller = [OATargetMenuViewController createMenuController:_targetMenuView.targetPoint activeTargetType:_activeTargetType activeViewControllerState:_activeViewControllerState];
    BOOL prepared = NO;
    switch (_targetMenuView.targetPoint.type)
    {
        case OATargetFavorite:
        case OATargetDestination:
        case OATargetAddress:
        case OATargetHistoryItem:
        case OATargetPOI:
        case OATargetOsmEdit:
        case OATargetOsmNote:
        case OATargetOsmOnlineNote:
        case OATargetTransportStop:
        case OATargetTransportRoute:
        case OATargetTurn:
        case OATargetMyLocation:
        {
            if (controller)
                [self.targetMenuView doInit:showFullMenu];
            
            break;
        }
        case OATargetParking:
        {
            if (controller)
            {
                [self.targetMenuView doInit:showFullMenu];
                ((OAParkingViewController *)controller).parkingDelegate = self;
            }
            break;
        }
        case OATargetWiki:
        {
            if (controller)
            {
                [self.targetMenuView doInit:showFullMenu];
                ((OAWikiMenuViewController *)controller).menuDelegate = self;
            }
            break;
        }
        case OATargetWpt:
        {
            [self.targetMenuView doInit:showFullMenu];
            
            OAGPXWptViewController *wptViewController = (OAGPXWptViewController *) controller;
            if (_activeTargetType == OATargetGPXEdit)
                [wptViewController activateEditing];
            
            wptViewController.mapViewController = self.mapViewController;
            wptViewController.wptDelegate = self;
            
            break;
        }
        case OATargetGPX:
        {
            OAGPXItemViewControllerState *state = _activeViewControllerState ? (OAGPXItemViewControllerState *)_activeViewControllerState : nil;
            BOOL showFull = (state && state.showFull) || (!state && showFullMenu);
            BOOL showFullScreen = (state && state.showFullScreen);
            [self.targetMenuView doInit:showFull showFullScreen:showFullScreen];

            break;
        }
        case OATargetGPXEdit:
        {
            OAGPXEditItemViewControllerState *state = _activeViewControllerState ? (OAGPXEditItemViewControllerState *)_activeViewControllerState : nil;
            BOOL showFull = (state && state.showFullScreen) || (!state && showFullMenu);
            [self.targetMenuView doInit:showFull showFullScreen:showFull];
            
            break;
        }
        case OATargetRouteStart:
        case OATargetRouteFinish:
        case OATargetRouteIntermediate:
        case OATargetRouteStartSelection:
        case OATargetRouteFinishSelection:
        case OATargetRouteIntermediateSelection:
        case OATargetImpassableRoad:
        case OATargetImpassableRoadSelection:
        {
            if (controller)
                [self.targetMenuView doInit:NO];

            break;
        }
        case OATargetGPXRoute:
        {
            OAGPXRouteViewControllerState *state = _activeViewControllerState ? (OAGPXRouteViewControllerState *)_activeViewControllerState : nil;
            OAGpxRouteSegmentType segmentType = (OAGpxRouteSegmentType)_targetMenuView.targetPoint.segmentIndex;
            BOOL showFull = (state && state.showFullScreen) || (!state && segmentType == kSegmentRouteWaypoints);
            [self.targetMenuView doInit:showFull showFullScreen:showFull];

            break;
        }
        case OATargetMapillaryImage:
        {
            break;
        }
        default:
        {
            [self.targetMenuView prepare];
            prepared = YES;
        }
    }
    if (controller && !prepared)
    {
        [self.targetMenuView setCustomViewController:controller needFullMenu:NO];
        [self.targetMenuView prepareNoInit];
    }
    
    CGRect frame = self.targetMenuView.frame;
    frame.origin.y = DeviceScreenHeight + 10.0;
    self.targetMenuView.frame = frame;
    
    [self.targetMenuView.layer removeAllAnimations];
    if ([self.view.subviews containsObject:self.targetMenuView])
        [self.targetMenuView removeFromSuperview];
    
    
    if (_targetMenuView.targetPoint.minimized)
    {
        _targetMenuView.targetPoint.minimized = NO;
        if (onComplete)
            onComplete();
        
        return;
    }
    
    [self.view addSubview:self.targetMenuView];
    
    Point31 targetPoint31 = [OANativeUtilities convertFromPointI:OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(_targetLatitude, _targetLongitude))];
    [_mapViewController correctPosition:targetPoint31 originalCenter31:[OANativeUtilities convertFromPointI:_mainMapTarget31] leftInset:([self.targetMenuView isLandscape] ? kInfoViewLanscapeWidth : 0.0) bottomInset:([self.targetMenuView isLandscape] ? 0.0 : [self.targetMenuView getHeaderViewHeight]) centerBBox:(_targetMode == EOATargetBBOX) animated:YES];
    
    if (onComplete)
        onComplete();
    
    self.sidePanelController.recognizesPanGesture = NO;
    [self.targetMenuView show:YES onComplete:^{
        self.sidePanelController.recognizesPanGesture = NO;
    }];
}

- (void) showMultiPointMenu:(NSArray<OATargetPoint *> *)points onComplete:(void (^)(void))onComplete
{
    if (_dashboard)
        [self closeDashboard];
    
    if (self.targetMenuView.superview)
        [self hideTargetPointMenu];
    
    CGRect frame = self.targetMultiMenuView.frame;
    frame.origin.y = DeviceScreenHeight + 10.0;
    self.targetMultiMenuView.frame = frame;
    
    [self.targetMultiMenuView.layer removeAllAnimations];
    if ([self.view.subviews containsObject:self.targetMultiMenuView])
        [self.targetMultiMenuView removeFromSuperview];
    
    [self.targetMultiMenuView setTargetPoints:points];
    
    [self.view addSubview:self.targetMultiMenuView];
    
    if (onComplete)
        onComplete();
    
    self.sidePanelController.recognizesPanGesture = NO;
    [self.targetMultiMenuView show:YES onComplete:^{
        self.sidePanelController.recognizesPanGesture = NO;
    }];
}

- (void) targetHideMenuByMapGesture
{
    [self hideTargetPointMenu:.2 onComplete:nil hideActiveTarget:NO mapGestureAction:YES];
}

- (void) targetSetTopControlsVisible:(BOOL)visible
{
    [self setTopControlsVisible:visible];
}

- (void) targetSetBottomControlsVisible:(BOOL)visible menuHeight:(CGFloat)menuHeight animated:(BOOL)animated
{
    [self setBottomControlsVisible:visible menuHeight:menuHeight animated:animated];
}

- (void) targetStatusBarChanged
{
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void) hideTargetPointMenu
{
    [self hideTargetPointMenu:.2 onComplete:nil];
}

- (void) hideTargetPointMenu:(CGFloat)animationDuration
{
    [self hideTargetPointMenu:animationDuration onComplete:nil];
}

- (void) hideTargetPointMenu:(CGFloat)animationDuration onComplete:(void (^)(void))onComplete
{
    [self hideTargetPointMenu:animationDuration onComplete:onComplete hideActiveTarget:NO mapGestureAction:NO];
}

- (void) hideTargetPointMenu:(CGFloat)animationDuration onComplete:(void (^)(void))onComplete hideActiveTarget:(BOOL)hideActiveTarget mapGestureAction:(BOOL)mapGestureAction
{
    if (self.targetMultiMenuView.superview)
    {
        [self.targetMultiMenuView hide:YES duration:animationDuration onComplete:nil];
        return;
    }
    
    if (mapGestureAction && !self.targetMenuView.superview)
    {
        return;
    }
        
    if (![self.targetMenuView preHide])
        return;
    
    if (!hideActiveTarget)
    {
        if (_mapStateSaved)
            [self restoreMapAfterReuseAnimated];
        
        _mapStateSaved = NO;
    }
    
    [self destroyShadowButton];
    
    if (_activeTargetType != OATargetNone && !_activeTargetActive && !_activeTargetChildPushed && !hideActiveTarget && animationDuration > .1)
        animationDuration = .1;
    
    [self.targetMenuView hide:YES duration:animationDuration onComplete:^{
        
        if (_activeTargetType != OATargetNone)
        {
            if (_activeTargetActive || _activeTargetChildPushed)
            {
                [self resetActiveTargetMenu];
                _activeTargetChildPushed = NO;
            }
            else if (!hideActiveTarget)
            {
                [self restoreActiveTargetMenu];
            }
        }
        
        if (onComplete)
            onComplete();
        
    }];
    
    [self showTopControls];
    _customStatusBarStyleNeeded = NO;
    [self setNeedsStatusBarAppearanceUpdate];

    self.sidePanelController.recognizesPanGesture = NO; //YES;
}

- (void) hideTargetPointMenuAndPopup:(CGFloat)animationDuration onComplete:(void (^)(void))onComplete
{
    if (self.targetMultiMenuView.superview)
    {
        [self.targetMultiMenuView hide:YES duration:animationDuration onComplete:onComplete];
        return;
    }

    if (![self.targetMenuView preHide])
        return;

    if (_mapStateSaved)
        [self restoreMapAfterReuseAnimated];
    
    _mapStateSaved = NO;
    
    [self destroyShadowButton];
    
    if (_activeTargetType == OATargetNone || _activeTargetActive)
    {
        BOOL popped;
        switch (self.targetMenuView.targetPoint.type)
        {
            case OATargetGPX:
            case OATargetGPXEdit:
                if ([self hasGpxActiveTargetType] && _activeTargetObj)
                    ((OAGPX *)_activeTargetObj).newGpx = NO;
                popped = [OAGPXListViewController popToParent];
                break;
                
            case OATargetGPXRoute:
                popped = [OAGPXListViewController popToParent];
                break;
                
            case OATargetFavorite:
                popped = [OAFavoriteListViewController popToParent];
                break;

            default:
                popped = NO;
                break;
        }

        if (!popped)
            [self.navigationController popViewControllerAnimated:YES];
    }
    
    [self.targetMenuView hide:YES duration:animationDuration onComplete:^{
        
        if (_activeTargetType != OATargetNone)
        {
            if (_activeTargetActive)
                [self resetActiveTargetMenu];
            else
                [self restoreActiveTargetMenu];

            _activeTargetChildPushed = NO;
        }
        if (onComplete)
            onComplete();
    }];
    
    [self showTopControls];
    _customStatusBarStyleNeeded = NO;
    [self setNeedsStatusBarAppearanceUpdate];
    
    self.sidePanelController.recognizesPanGesture = NO; //YES;
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if (self.targetMenuView.superview)
        [self.targetMenuView prepareForRotation:toInterfaceOrientation];
}

-(void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self.targetMenuView.customController viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self.targetMultiMenuView transitionToSize];
    } completion:nil];
}

- (OATargetPoint *) getCurrentTargetPoint
{
    if (_targetMenuView.superview)
        return _targetMenuView.targetPoint;
    else
        return nil;
}

- (void) openTargetViewWithFavorite:(OAFavoriteItem *)item pushed:(BOOL)pushed
{
    OATargetPoint *targetPoint = [_mapViewController.mapLayers.favoritesLayer getTargetPointCpp:item.favorite.get()];
    if (targetPoint)
    {
        _targetMenuView.isAddressFound = YES;
        _formattedTargetName = targetPoint.title;
        _targetMode = EOATargetPoint;
        _targetLatitude = targetPoint.location.latitude;
        _targetLongitude = targetPoint.location.longitude;
        _targetZoom = 0.0;
        
        targetPoint.toolbarNeeded = pushed;
        
        [_mapViewController showContextPinMarker:targetPoint.location.latitude longitude:targetPoint.location.longitude animated:NO];
        [_targetMenuView setTargetPoint:targetPoint];
        
        [self showTargetPointMenu:YES showFullMenu:NO onComplete:^{
            [self goToTargetPointDefault];
        }];
    }
}

- (void) openTargetViewWithAddress:(OAAddress *)address name:(NSString *)name typeName:(NSString *)typeName pushed:(BOOL)pushed
{
    double lat = address.latitude;
    double lon = address.longitude;
    
    [_mapViewController showContextPinMarker:lat longitude:lon animated:NO];
    
    OATargetPoint *targetPoint = [[OATargetPoint alloc] init];
    
    NSString *lang = [OAAppSettings sharedManager].settingPrefMapLanguage;
    if (!lang)
        lang = @"";
    BOOL transliterate = [OAAppSettings sharedManager].settingMapLanguageTranslit;
    
    NSString *caption = name.length == 0 ? [address getName:lang transliterate:transliterate] : name;
    NSString *description = typeName.length == 0 ?  [address getAddressTypeName] : typeName;
    UIImage *icon = [address icon];
    
    targetPoint.type = OATargetAddress;
    
    _targetMenuView.isAddressFound = YES;
    _formattedTargetName = description;
    _targetMode = EOATargetPoint;
    _targetLatitude = lat;
    _targetLongitude = lon;
    _targetZoom = 16.0;
    
    targetPoint.location = CLLocationCoordinate2DMake(lat, lon);
    targetPoint.title = caption;
    targetPoint.titleAddress = description;
    targetPoint.icon = icon;
    targetPoint.toolbarNeeded = pushed;
    targetPoint.targetObj = address;
    
    [_targetMenuView setTargetPoint:targetPoint];
    
    [self showTargetPointMenu:YES showFullMenu:NO onComplete:^{
        [self goToTargetPointDefault];
    }];
}

- (void) openTargetViewWithHistoryItem:(OAHistoryItem *)item pushed:(BOOL)pushed
{
    [self openTargetViewWithHistoryItem:item pushed:pushed showFullMenu:NO];
}

- (void) openTargetViewWithHistoryItem:(OAHistoryItem *)item pushed:(BOOL)pushed showFullMenu:(BOOL)showFullMenu
{
    double lat = item.latitude;
    double lon = item.longitude;
    
    [_mapViewController showContextPinMarker:lat longitude:lon animated:NO];
    
    OATargetPoint *targetPoint = [[OATargetPoint alloc] init];
    
    NSString *caption = item.name;    
    UIImage *icon = [item icon];
    
    targetPoint.type = OATargetHistoryItem;

    _targetMenuView.isAddressFound = YES;
    _formattedTargetName = [self findRoadNameByLat:lat lon:lon];
    _targetMode = EOATargetPoint;
    _targetLatitude = lat;
    _targetLongitude = lon;
    _targetZoom = 0.0;
    
    targetPoint.location = CLLocationCoordinate2DMake(lat, lon);
    targetPoint.title = caption;
    targetPoint.titleAddress = _formattedTargetName;
    targetPoint.icon = icon;
    targetPoint.toolbarNeeded = pushed;
    targetPoint.targetObj = item;
    
    [_targetMenuView setTargetPoint:targetPoint];
    
    [self showTargetPointMenu:YES showFullMenu:showFullMenu onComplete:^{
        [self goToTargetPointDefault];
    }];
}

- (void) openTargetViewWithWpt:(OAGpxWptItem *)item pushed:(BOOL)pushed
{
    [self openTargetViewWithWpt:item pushed:pushed showFullMenu:YES];
}

- (void) openTargetViewWithWpt:(OAGpxWptItem *)item pushed:(BOOL)pushed showFullMenu:(BOOL)showFullMenu
{
    double lat = item.point.position.latitude;
    double lon = item.point.position.longitude;
    
    [_mapViewController showContextPinMarker:lat longitude:lon animated:NO];
    
    if ([_mapViewController findWpt:item.point.position])
    {
        item.point = _mapViewController.foundWpt;
        item.groups = _mapViewController.foundWptGroups;
    }
    
    OATargetPoint *targetPoint = [[OATargetPoint alloc] init];
    
    NSString *caption = item.point.name;
    
    OAFavoriteColor *favCol = [OADefaultFavorite nearestFavColor:item.color];
    UIImage *icon = [UIImage imageNamed:favCol.iconName];
    
    targetPoint.type = OATargetWpt;
    
    _targetMenuView.isAddressFound = YES;
    _formattedTargetName = caption;
    _targetMode = EOATargetPoint;
    _targetLatitude = lat;
    _targetLongitude = lon;
    _targetZoom = 0.0;
    
    targetPoint.location = CLLocationCoordinate2DMake(lat, lon);
    targetPoint.title = _formattedTargetName;
    targetPoint.icon = icon;
    targetPoint.toolbarNeeded = pushed;
    targetPoint.targetObj = item;
    
    [_targetMenuView setTargetPoint:targetPoint];
    
    if (pushed && _activeTargetActive && [self hasGpxActiveTargetType])
        _activeTargetChildPushed = YES;

    [self showTargetPointMenu:YES showFullMenu:showFullMenu onComplete:^{
        [self goToTargetPointDefault];
    }];
}

- (void) openTargetViewWithGPX:(OAGPX *)item pushed:(BOOL)pushed
{
    BOOL showCurrentTrack = NO;
    if (item == nil)
    {
        item = [[OASavingTrackHelper sharedInstance] getCurrentGPX];
        item.gpxTitle = OALocalizedString(@"track_recording_name");
        showCurrentTrack = YES;
    }
    
    [_mapViewController hideContextPinMarker];

    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;
    OATargetPoint *targetPoint = [[OATargetPoint alloc] init];
    
    NSString *caption = [item getNiceTitle];
    
    UIImage *icon = [UIImage imageNamed:@"icon_info"];
    
    targetPoint.type = OATargetGPX;
    
    _targetMenuView.isAddressFound = YES;
    _formattedTargetName = caption;
    
    if (_activeTargetType != OATargetGPX)
        [self displayGpxOnMap:item];
    
    if (item.bounds.center.latitude == DBL_MAX)
    {
        OsmAnd::LatLon latLon = OsmAnd::Utilities::convert31ToLatLon(renderView.target31);
        targetPoint.location = CLLocationCoordinate2DMake(latLon.latitude, latLon.longitude);
        _targetLatitude = latLon.latitude;
        _targetLongitude = latLon.longitude;
    }
    else
    {
        targetPoint.location = CLLocationCoordinate2DMake(item.bounds.center.latitude, item.bounds.center.longitude);
    }
    
    targetPoint.title = _formattedTargetName;
    targetPoint.icon = icon;
    targetPoint.toolbarNeeded = NO;
    if (!showCurrentTrack)
        targetPoint.targetObj = item;
    
    _activeTargetType = targetPoint.type;
    _activeTargetObj = targetPoint.targetObj;
    
    _targetMenuView.activeTargetType = _activeTargetType;
    [_targetMenuView setTargetPoint:targetPoint];
    
    [self showTargetPointMenu:YES showFullMenu:!item.newGpx onComplete:^{
        [self enterContextMenuMode];
        _activeTargetActive = YES;
    }];
}

- (void) openTargetViewWithGPXEdit:(OAGPX *)item pushed:(BOOL)pushed
{
    BOOL showCurrentTrack = NO;
    if (item == nil)
    {
        item = [[OASavingTrackHelper sharedInstance] getCurrentGPX];
        item.gpxTitle = OALocalizedString(@"track_recording_name");
        showCurrentTrack = YES;
    }
    
    [_mapViewController hideContextPinMarker];
    
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;
    OATargetPoint *targetPoint = [[OATargetPoint alloc] init];
    
    NSString *caption = [item getNiceTitle];
    
    UIImage *icon = [UIImage imageNamed:@"icon_info"];
    
    targetPoint.type = OATargetGPXEdit;
    
    _targetMenuView.isAddressFound = YES;
    _formattedTargetName = caption;
    
    if (_activeTargetType != OATargetGPXEdit)
        [self displayGpxOnMap:item];
    
    if (item.bounds.center.latitude == DBL_MAX)
    {
        OsmAnd::LatLon latLon = OsmAnd::Utilities::convert31ToLatLon(renderView.target31);
        targetPoint.location = CLLocationCoordinate2DMake(latLon.latitude, latLon.longitude);
        _targetLatitude = latLon.latitude;
        _targetLongitude = latLon.longitude;
    }
    else
    {
        targetPoint.location = CLLocationCoordinate2DMake(item.bounds.center.latitude, item.bounds.center.longitude);
    }
    
    targetPoint.title = _formattedTargetName;
    targetPoint.icon = icon;
    targetPoint.toolbarNeeded = NO;
    if (!showCurrentTrack)
        targetPoint.targetObj = item;
    
    _activeTargetType = targetPoint.type;
    _activeTargetObj = targetPoint.targetObj;
    
    _targetMenuView.activeTargetType = _activeTargetType;
    [_targetMenuView setTargetPoint:targetPoint];
    
    [self enterContextMenuMode];
    [self showTargetPointMenu:YES showFullMenu:!item.newGpx onComplete:^{
        _activeTargetActive = YES;
    }];
}

- (void) openTargetViewWithImpassableRoad:(unsigned long long)roadId pushed:(BOOL)pushed
{
    [self closeDashboard];
    [self closeRouteInfo];

    OAAvoidSpecificRoads *avoidRoads = [OAAvoidSpecificRoads instance];
    const auto& roads = [avoidRoads getImpassableRoads];
    for (const auto& r : roads)
    {
        if (r->id == roadId)
        {
            CLLocation *location = [avoidRoads getLocation:r->id];
            if (location)
            {
                double lat = location.coordinate.latitude;
                double lon = location.coordinate.longitude;
                
                [_mapViewController showContextPinMarker:lat longitude:lon animated:NO];
                
                OATargetPoint *targetPoint = [_mapViewController.mapLayers.impassableRoadsLayer getTargetPointCpp:r.get()];
                if (targetPoint)
                {
                    targetPoint.toolbarNeeded = pushed;
                    
                    _targetMenuView.isAddressFound = YES;
                    _formattedTargetName = targetPoint.title;
                    
                    _targetMode = EOATargetPoint;
                    _targetLatitude = targetPoint.location.latitude;
                    _targetLongitude =  targetPoint.location.longitude;
                    _targetZoom = 0.0;
                    
                    [_targetMenuView setTargetPoint:targetPoint];
                    
                    [self showTargetPointMenu:YES showFullMenu:NO onComplete:^{
                        [self goToTargetPointDefault];
                    }];
                }
            }
            break;
        }
    }
}

- (void) openTargetViewWithImpassableRoadSelection
{
    [_mapViewController hideContextPinMarker];
    [self closeDashboard];
    [self closeRouteInfo];
    
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;
    OATargetPoint *targetPoint = [[OATargetPoint alloc] init];
    
    targetPoint.type = OATargetImpassableRoadSelection;
    
    _targetMenuView.isAddressFound = YES;
    _formattedTargetName = OALocalizedString(@"shared_string_select_on_map");
    
    OsmAnd::LatLon latLon = OsmAnd::Utilities::convert31ToLatLon(renderView.target31);
    targetPoint.location = CLLocationCoordinate2DMake(latLon.latitude, latLon.longitude);
    _targetLatitude = latLon.latitude;
    _targetLongitude = latLon.longitude;
    
    targetPoint.title = _formattedTargetName;
    targetPoint.icon = [UIImage imageNamed:@"map_pin_avoid_road"];
    targetPoint.toolbarNeeded = NO;
    
    _activeTargetType = targetPoint.type;
    _activeTargetObj = targetPoint.targetObj;
    _targetMenuView.activeTargetType = _activeTargetType;
    
    [_targetMenuView setTargetPoint:targetPoint];
    
    [self enterContextMenuMode];
    [self showTargetPointMenu:YES showFullMenu:NO onComplete:^{
        _activeTargetActive = YES;
    }];
}

- (void) openTargetViewWithRouteTargetPoint:(OARTargetPoint *)routeTargetPoint pushed:(BOOL)pushed
{
    double lat = routeTargetPoint.point.coordinate.latitude;
    double lon = routeTargetPoint.point.coordinate.longitude;
    
    [_mapViewController showContextPinMarker:lat longitude:lon animated:NO];
    
    OATargetPoint *targetPoint = [[OATargetPoint alloc] init];
    
    UIImage *icon;
    if (routeTargetPoint.start)
    {
        targetPoint.type = OATargetRouteStart;
        [UIImage imageNamed:@"list_startpoint"];
    }
    else if (!routeTargetPoint.intermediate)
    {
        targetPoint.type = OATargetRouteFinish;
        [UIImage imageNamed:@"list_destination"];
    }
    else
    {
        targetPoint.type = OATargetRouteIntermediate;
        [UIImage imageNamed:@"list_intermediate"];
    }
    
    _targetMenuView.isAddressFound = YES;
    _formattedTargetName = [routeTargetPoint getPointDescription].name;
    _targetMode = EOATargetPoint;
    _targetLatitude = lat;
    _targetLongitude = lon;
    _targetZoom = 0.0;
    
    targetPoint.location = CLLocationCoordinate2DMake(lat, lon);
    targetPoint.title = _formattedTargetName;
    targetPoint.icon = icon;
    targetPoint.toolbarNeeded = pushed;
    
    [_targetMenuView setTargetPoint:targetPoint];
    
    [self showTargetPointMenu:YES showFullMenu:NO onComplete:^{
            [self goToTargetPointDefault];
    }];
}

- (void) openTargetViewWithRouteTargetSelection:(BOOL)target intermediate:(BOOL)intermediate
{
    [_mapViewController hideContextPinMarker];
    [self closeRouteInfo];
    
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;
    OATargetPoint *targetPoint = [[OATargetPoint alloc] init];
    
    if (intermediate)
        targetPoint.type = OATargetRouteIntermediateSelection;
    else if (target)
        targetPoint.type = OATargetRouteFinishSelection;
    else
        targetPoint.type = OATargetRouteStartSelection;

    _targetMenuView.isAddressFound = YES;
    _formattedTargetName = OALocalizedString(@"shared_string_select_on_map");
    
    OsmAnd::LatLon latLon = OsmAnd::Utilities::convert31ToLatLon(renderView.target31);
    targetPoint.location = CLLocationCoordinate2DMake(latLon.latitude, latLon.longitude);
    _targetLatitude = latLon.latitude;
    _targetLongitude = latLon.longitude;
    
    targetPoint.title = _formattedTargetName;
    targetPoint.icon = [UIImage imageNamed:@"ic_action_marker"];
    targetPoint.toolbarNeeded = NO;
    
    _activeTargetType = targetPoint.type;
    _activeTargetObj = targetPoint.targetObj;
    _targetMenuView.activeTargetType = _activeTargetType;
    
    [_targetMenuView setTargetPoint:targetPoint];
    
    [self enterContextMenuMode];
    [self showTargetPointMenu:YES showFullMenu:NO onComplete:^{
        _activeTargetActive = YES;
    }];
}

- (void) openTargetViewWithGPXRoute:(BOOL)pushed
{
    [self openTargetViewWithGPXRoute:nil pushed:pushed segmentType:kSegmentRoute];
}

- (void) openTargetViewWithGPXRoute:(BOOL)pushed segmentType:(OAGpxRouteSegmentType)segmentType
{
    [self openTargetViewWithGPXRoute:nil pushed:pushed segmentType:segmentType];
}

- (void) openTargetViewWithGPXRoute:(OAGPX *)item pushed:(BOOL)pushed
{
    [self openTargetViewWithGPXRoute:item pushed:pushed segmentType:kSegmentRoute];
}

- (void) openTargetViewWithGPXRoute:(OAGPX *)item pushed:(BOOL)pushed segmentType:(OAGpxRouteSegmentType)segmentType
{
    if (![[OAIAPHelper sharedInstance].tripPlanning isActive])
    {
        [OAPluginPopupViewController askForPlugin:kInAppId_Addon_TripPlanning];
        return;
    }

    [_mapViewController hideContextPinMarker];
 
    BOOL useCurrentRoute = (item == nil);
    if (useCurrentRoute)
        item = [OAGPXRouter sharedInstance].gpx;
    
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;
    OATargetPoint *targetPoint = [[OATargetPoint alloc] init];
    
    NSString *caption = [item getNiceTitle];
    
    UIImage *icon = [UIImage imageNamed:@"ic_route_modebg.jpg"];
    
    targetPoint.type = OATargetGPXRoute;
    
    _targetMenuView.isAddressFound = YES;
    _formattedTargetName = caption;
    
    if (item.bounds.center.latitude == DBL_MAX)
    {
        OsmAnd::LatLon latLon = OsmAnd::Utilities::convert31ToLatLon(renderView.target31);
        targetPoint.location = CLLocationCoordinate2DMake(latLon.latitude, latLon.longitude);
        _targetLatitude = latLon.latitude;
        _targetLongitude = latLon.longitude;
    }
    else
    {
        targetPoint.location = CLLocationCoordinate2DMake(item.bounds.center.latitude, item.bounds.center.longitude);
    }
    
    targetPoint.title = _formattedTargetName;
    targetPoint.icon = icon;
    targetPoint.toolbarNeeded = NO;
    targetPoint.targetObj = item;
    targetPoint.segmentIndex = segmentType;
    
    _activeTargetType = targetPoint.type;
    _activeTargetObj = targetPoint.targetObj;
    
    _targetMenuView.activeTargetType = _activeTargetType;
    [_targetMenuView setTargetPoint:targetPoint];
    
    if (!useCurrentRoute)
        [[OAGPXRouter sharedInstance] setRouteWithGpx:item];
    
    [self enterContextMenuMode];
    [self showTargetPointMenu:YES showFullMenu:!item.newGpx onComplete:^{
        _activeTargetActive = YES;
        [self displayGpxOnMap:item];
    }];
}

- (void) openTargetViewWithDestination:(OADestination *)destination
{
    [self destinationViewMoveTo:destination];
}

- (void) displayGpxOnMap:(OAGPX *)item
{
    if (item.bounds.topLeft.latitude == DBL_MAX)
        return;
    
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;

    CGSize screenBBox = CGSizeMake(DeviceScreenWidth - ([self.targetMenuView isLandscape] ? kInfoViewLanscapeWidth : 0.0), DeviceScreenHeight - ([self.targetMenuView isLandscape] ? 0.0 : 233.0));
    _targetZoom = [self getZoomForBounds:item.bounds mapSize:screenBBox];
    _targetMode = (_targetZoom > 0.0 ? EOATargetBBOX : EOATargetPoint);
    
    if (_targetMode == EOATargetBBOX)
    {
        _targetLatitude = item.bounds.bottomRight.latitude;
        _targetLongitude = item.bounds.topLeft.longitude;
    }
    else
    {
        _targetLatitude = item.bounds.center.latitude;
        _targetLongitude = item.bounds.center.longitude;
    }
    
    Point31 targetPoint31 = [OANativeUtilities convertFromPointI:OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(item.bounds.center.latitude, item.bounds.center.longitude))];
    [_mapViewController goToPosition:targetPoint31
                             andZoom:(_targetMode == EOATargetBBOX ? _targetZoom : kDefaultFavoriteZoomOnShow)
                            animated:NO];
    
    renderView.azimuth = 0.0;
    renderView.elevationAngle = 90.0;
    
    OsmAnd::LatLon latLon(item.bounds.center.latitude, item.bounds.center.longitude);
    _mainMapTarget31 = OsmAnd::Utilities::convertLatLonTo31(latLon);
    _mainMapZoom = _targetZoom;
    
    if (self.targetMenuView.superview && !self.targetMenuView.showFullScreen)
    {
        Point31 targetPoint31 = [OANativeUtilities convertFromPointI:OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(_targetLatitude, _targetLongitude))];
        [_mapViewController correctPosition:targetPoint31 originalCenter31:[OANativeUtilities convertFromPointI:_mainMapTarget31] leftInset:([self.targetMenuView isLandscape] ? kInfoViewLanscapeWidth : 0.0) bottomInset:([self.targetMenuView isLandscape] ? 0.0 : [self.targetMenuView getVisibleHeight]) centerBBox:(_targetMode == EOATargetBBOX) animated:NO];
    }
}

- (BOOL) goToMyLocationIfInArea:(CLLocationCoordinate2D)topLeft bottomRight:(CLLocationCoordinate2D)bottomRight
{
    BOOL res = NO;
    
    CLLocation *myLoc = _app.locationServices.lastKnownLocation;
    if (myLoc && topLeft.latitude != DBL_MAX)
    {
        CLLocationCoordinate2D my = myLoc.coordinate;

        OsmAnd::PointI myI = OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(my.latitude, my.longitude));
        OsmAnd::PointI topLeftI = OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(topLeft.latitude, topLeft.longitude));
        OsmAnd::PointI bottomRightI = OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(bottomRight.latitude, bottomRight.longitude));
        
        if (topLeftI.x < myI.x &&
            topLeftI.y < myI.y &&
            bottomRightI.x > myI.x &&
            bottomRightI.y > myI.y)
        {
            OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;
            
            _targetZoom = kDefaultFavoriteZoom;
            _targetMode = EOATargetPoint;
            
            _targetLatitude = my.latitude;
            _targetLongitude = my.longitude;
            
            Point31 targetPoint31 = [OANativeUtilities convertFromPointI:OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(my.latitude, my.longitude))];
            [_mapViewController goToPosition:targetPoint31
                                     andZoom:(_targetMode == EOATargetBBOX ? _targetZoom : kDefaultFavoriteZoomOnShow)
                                    animated:NO];
            
            renderView.azimuth = 0.0;
            renderView.elevationAngle = 90.0;
            
            OsmAnd::LatLon latLon(my.latitude, my.longitude);
            _mainMapTarget31 = OsmAnd::Utilities::convertLatLonTo31(latLon);
            _mainMapZoom = _targetZoom;
            
            res = YES;
        }
    }
    
    return res;
}

- (void) displayAreaOnMap:(CLLocationCoordinate2D)topLeft bottomRight:(CLLocationCoordinate2D)bottomRight zoom:(float)zoom bottomInset:(float)bottomInset leftInset:(float)leftInset
{
    OAToolbarViewController *toolbar = [self getTopToolbar];
    CGFloat topInset = 0.0;
    if (toolbar && [toolbar.navBarView superview])
        topInset = toolbar.navBarView.frame.size.height;

    OAGpxBounds bounds;
    bounds.topLeft = topLeft;
    bounds.bottomRight = bottomRight;
    bounds.center.latitude = bottomRight.latitude / 2.0 + topLeft.latitude / 2.0;
    bounds.center.longitude = bottomRight.longitude / 2.0 + topLeft.longitude / 2.0;
    
    if (bounds.topLeft.latitude == DBL_MAX)
        return;
    
    OAMapRendererView* renderView = (OAMapRendererView*)_mapViewController.view;

    CGSize screenBBox = CGSizeMake(DeviceScreenWidth - leftInset, DeviceScreenHeight - topInset - bottomInset);
    _targetZoom = (zoom <= 0 ? [self getZoomForBounds:bounds mapSize:screenBBox] : zoom);
    _targetMode = (_targetZoom > 0.0 ? EOATargetBBOX : EOATargetPoint);
    
    _targetLatitude = bounds.bottomRight.latitude;
    _targetLongitude = bounds.topLeft.longitude;
    
    Point31 targetPoint31 = [OANativeUtilities convertFromPointI:OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(bounds.center.latitude, bounds.center.longitude))];
    [_mapViewController goToPosition:targetPoint31
                             andZoom:(_targetMode == EOATargetBBOX ? _targetZoom : kDefaultFavoriteZoomOnShow)
                            animated:NO];
    
    renderView.azimuth = 0.0;
    renderView.elevationAngle = 90.0;
    
    OsmAnd::LatLon latLon(bounds.center.latitude, bounds.center.longitude);
    _mainMapTarget31 = OsmAnd::Utilities::convertLatLonTo31(latLon);
    _mainMapZoom = _targetZoom;
    
    targetPoint31 = [OANativeUtilities convertFromPointI:OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(_targetLatitude, _targetLongitude))];
    if (bottomInset > 0)
    {
        [_mapViewController correctPosition:targetPoint31 originalCenter31:[OANativeUtilities convertFromPointI:_mainMapTarget31] leftInset:leftInset bottomInset:bottomInset centerBBox:(_targetMode == EOATargetBBOX) animated:NO];
    }
    else if (topInset > 0)
    {
        [_mapViewController correctPosition:targetPoint31 originalCenter31:[OANativeUtilities convertFromPointI:_mainMapTarget31] leftInset:leftInset bottomInset:-topInset centerBBox:(_targetMode == EOATargetBBOX) animated:NO];
    }
    else if (leftInset > 0)
    {
        [_mapViewController correctPosition:targetPoint31 originalCenter31:[OANativeUtilities convertFromPointI:_mainMapTarget31] leftInset:leftInset bottomInset:0 centerBBox:(_targetMode == EOATargetBBOX) animated:NO];
    }
}

- (BOOL) isTopToolbarActive
{
    OAToolbarViewController *toolbar = [self getTopToolbar];
    return toolbar || [_targetMenuView isToolbarVisible];
}

- (OAToolbarViewController *) getTopToolbar
{
    BOOL followingMode = [_routingHelper isFollowingMode];
    for (OAToolbarViewController *toolbar in _toolbars)
    {
        if (toolbar && (toolbar.showOnTop || (!followingMode || ![toolbar isKindOfClass:[OADestinationViewController class]])))
            return toolbar;
    }
    return nil;
}

- (void) updateToolbar
{
    OAToolbarViewController *toolbar = [self getTopToolbar];
    if (self.hudViewController)
    {
        if (toolbar)
        {
            [self.hudViewController setToolbar:toolbar];
            [toolbar updateFrame:NO];
        }
        else
        {
            [self.hudViewController removeToolbar];
        }
    }
}

- (void) showCards
{
    [OAFirebaseHelper logEvent:@"destinations_open"];

    _destinationViewController.showOnTop = YES;
    [self showToolbar:_destinationViewController];
    [self openDestinationCardsView];
}

- (void) showToolbar:(OAToolbarViewController *)toolbarController
{
    if (![_toolbars containsObject:toolbarController])
    {
        [_toolbars addObject:toolbarController];
        toolbarController.delegate = self;
    }
    
    [_toolbars sortUsingComparator:^NSComparisonResult(OAToolbarViewController * _Nonnull t1, OAToolbarViewController * _Nonnull t2) {
        int t1p = [t1 getPriority];
        if (t1.showOnTop)
            t1p -= 1000;
        int t2p = [t2 getPriority];
        if (t2.showOnTop)
            t2p -= 1000;
        return [OAUtilities compareInt:t1p y:t2p];
    }];

    [self updateToolbar];
}

- (void) hideToolbar:(OAToolbarViewController *)toolbarController
{
    [_toolbars removeObject:toolbarController];
    [self updateToolbar];
}

#pragma mark - OAToolbarViewControllerProtocol

- (CGFloat) toolbarTopPosition
{
    if (self.hudViewController)
        return self.hudViewController.toolbarTopPosition;

    return 20.0;
}

- (void) toolbarLayoutDidChange:(OAToolbarViewController *)toolbarController animated:(BOOL)animated
{
    if (self.hudViewController)
        [self.hudViewController updateToolbarLayout:animated];

    if ([toolbarController isKindOfClass:[OADestinationViewController class]])
    {
        OADestinationCardsViewController *cardsController = [OADestinationCardsViewController sharedInstance];
        if (cardsController.view.superview && !cardsController.isHiding && [OADestinationsHelper instance].sortedDestinations.count > 0)
        {
            [UIView animateWithDuration:(animated ? .25 : 0.0) animations:^{
                cardsController.view.frame = CGRectMake(0.0, _destinationViewController.view.frame.origin.y + _destinationViewController.view.frame.size.height, DeviceScreenWidth, DeviceScreenHeight - _destinationViewController.view.frame.origin.y - _destinationViewController.view.frame.size.height);
            }];
        }
    }
}

- (void) toolbarHide:(OAToolbarViewController *)toolbarController;
{
    [self hideToolbar:toolbarController];
}

- (void) recreateControls
{
    if (self.hudViewController)
        [self.hudViewController recreateControls];
}

- (void) refreshMap
{
    if (self.hudViewController)
        [self.hudViewController updateInfo];
    
    [self updateToolbar];
}

#pragma mark - OAParkingDelegate

- (void) addParking:(OAParkingViewController *)sender
{
    OADestination *destination = [[OADestination alloc] initWithDesc:_formattedTargetName latitude:sender.coord.latitude longitude:sender.coord.longitude];
    
    destination.parking = YES;
    destination.carPickupDateEnabled = sender.timeLimitActive;
    if (sender.timeLimitActive)
        destination.carPickupDate = sender.date;
    else
        destination.carPickupDate = nil;
    
    UIColor *color = [_destinationViewController addDestination:destination];
    if (color)
    {
        if (sender.timeLimitActive && sender.addToCalActive)
            [OADestinationsHelper addParkingReminderToCalendar:destination];
        
        [_mapViewController hideContextPinMarker];
        [self hideTargetPointMenu];
    }
    else
    {
        [[[UIAlertView alloc] initWithTitle:OALocalizedString(@"cannot_add_marker") message:OALocalizedString(@"cannot_add_marker_desc") delegate:nil cancelButtonTitle:OALocalizedString(@"shared_string_ok") otherButtonTitles:nil
         ] show];
    }
}

- (void) saveParking:(OAParkingViewController *)sender parking:(OADestination *)parking
{
    parking.carPickupDateEnabled = sender.timeLimitActive;
    if (sender.timeLimitActive)
        parking.carPickupDate = sender.date;
    else
        parking.carPickupDate = nil;
    
    if (parking.eventIdentifier)
        [OADestinationsHelper removeParkingReminderFromCalendar:parking];
    
    if (sender.timeLimitActive && sender.addToCalActive)
        [OADestinationsHelper addParkingReminderToCalendar:parking];
    
    [_destinationViewController updateDestinations];
    [self hideTargetPointMenu];
}

- (void) cancelParking:(OAParkingViewController *)sender
{
    [self hideTargetPointMenu];
}

#pragma mark - OAGPXWptViewControllerDelegate

- (void) changedWptItem
{
    [self.targetMenuView applyTargetObjectChanges];
}

#pragma mark - OAWikiMenuDelegate

- (void)openWiki:(OAWikiMenuViewController *)sender
{
    OAWikiWebViewController *wikiWeb = [[OAWikiWebViewController alloc] initWithLocalizedContent:self.targetMenuView.targetPoint.localizedContent localizedNames:self.targetMenuView.targetPoint.localizedNames];
    [self.navigationController pushViewController:wikiWeb animated:YES];
}

#pragma mark - OADestinationViewControllerProtocol

- (void)destinationsAdded
{
    [self showToolbar:_destinationViewController];
}

- (void) hideDestinations
{
    [self hideToolbar:_destinationViewController];
}

- (void) openDestinationCardsView
{
    OADestinationCardsViewController *cardsController = [OADestinationCardsViewController sharedInstance];
    
    if (!cardsController.view.superview)
    {
        [self hideTargetPointMenu];

        CGFloat y = _destinationViewController.view.frame.origin.y + _destinationViewController.view.frame.size.height;
        CGFloat h = DeviceScreenHeight - y;
    
        cardsController.view.frame = CGRectMake(0.0, y - h, DeviceScreenWidth, h);
        
        [self.hudViewController addChildViewController:cardsController];
        
        [self createShade];
        
        [self.hudViewController.view insertSubview:_shadeView belowSubview:_destinationViewController.view];
        
        [self.hudViewController.view insertSubview:cardsController.view belowSubview:_destinationViewController.view];
        
        if (_destinationViewController)
            [self.destinationViewController updateCloseButton];
        
        [UIView animateWithDuration:.25 animations:^{
            cardsController.view.frame = CGRectMake(0.0, y, DeviceScreenWidth, h);
            _shadeView.alpha = 1.0;
        }];
    }
}

- (void) hideDestinationCardsView
{
    [self hideDestinationCardsViewAnimated:YES];
}

- (void) hideDestinationCardsViewAnimated:(BOOL)animated
{
    OADestinationCardsViewController *cardsController = [OADestinationCardsViewController sharedInstance];
    BOOL wasOnTop = _destinationViewController.showOnTop;
    _destinationViewController.showOnTop = NO;
    if (cardsController.view.superview)
    {
        CGFloat y = _destinationViewController.view.frame.origin.y + _destinationViewController.view.frame.size.height;
        CGFloat h = DeviceScreenHeight - y;
    
        [cardsController doViewWillDisappear];

        if ([OADestinationsHelper instance].sortedDestinations.count == 0)
        {
            [self hideToolbar:_destinationViewController];
        }
        else
        {
            [self.destinationViewController updateCloseButton];
            if (wasOnTop)
                [self updateToolbar];
        }
        
        if (animated)
        {
            [UIView animateWithDuration:.25 animations:^{
                cardsController.view.frame = CGRectMake(0.0, y - h, DeviceScreenWidth, h);
                _shadeView.alpha = 0.0;
                
            } completion:^(BOOL finished) {
                
                [self removeShade];
                
                [cardsController.view removeFromSuperview];
                [cardsController removeFromParentViewController];
            }];
        }
        else
        {
            [self removeShade];
            [cardsController.view removeFromSuperview];
            [cardsController removeFromParentViewController];
        }
    }
}

- (void) openHideDestinationCardsView
{
    if (![OADestinationCardsViewController sharedInstance].view.superview)
        [self openDestinationCardsView];
    else
        [self hideDestinationCardsView];
}

- (void) destinationViewMoveTo:(OADestination *)destination
{
    if (destination.routePoint &&
        [_mapViewController findWpt:CLLocationCoordinate2DMake(destination.latitude, destination.longitude)])
    {
        OAGpxWptItem *item = [[OAGpxWptItem alloc] init];
        item.point = _mapViewController.foundWpt;
        [self openTargetViewWithWpt:item pushed:NO showFullMenu:NO];
        return;
    }

    [_mapViewController showContextPinMarker:destination.latitude longitude:destination.longitude animated:YES];

    OATargetPoint *targetPoint = [[OATargetPoint alloc] init];
    
    NSString *caption = destination.desc;
    UIImage *icon = [UIImage imageNamed:destination.markerResourceName];
    
    if (destination.parking)
        targetPoint.type = OATargetParking;
    else
        targetPoint.type = OATargetDestination;
    
    targetPoint.targetObj = destination;
    
    _targetDestination = destination;
    
    _targetMenuView.isAddressFound = YES;
    _formattedTargetName = caption;
    _targetMode = EOATargetPoint;
    _targetLatitude = destination.latitude;
    _targetLongitude = destination.longitude;
    _targetZoom = 0.0;
    
    targetPoint.location = CLLocationCoordinate2DMake(destination.latitude, destination.longitude);
    targetPoint.title = _formattedTargetName;
    targetPoint.icon = icon;
    targetPoint.titleAddress = [self findRoadNameByLat:destination.latitude lon:destination.longitude];
    
    [_targetMenuView setTargetPoint:targetPoint];
    
    [self showTargetPointMenu:YES showFullMenu:NO onComplete:^{
        [self targetGoToPoint];
    }];
}

// Navigation

- (void) displayCalculatedRouteOnMap:(CLLocationCoordinate2D)topLeft bottomRight:(CLLocationCoordinate2D)bottomRight
{
    BOOL landscape = [self.targetMenuView isLandscape];
    [self displayAreaOnMap:topLeft bottomRight:bottomRight zoom:0 bottomInset:[_routeInfoView superview] && !landscape ? _routeInfoView.frame.size.height + 20.0 : 0 leftInset:[_routeInfoView superview] && landscape ? _routeInfoView.frame.size.width + 20.0 : 0];
}

- (void) onNavigationClick:(BOOL)hasTargets
{
    OATargetPointsHelper *targets = [OATargetPointsHelper sharedInstance];
    if (![_routingHelper isFollowingMode] && ![_routingHelper isRoutePlanningMode])
    {
        if (!hasTargets)
        {
            [targets restoreTargetPoints:false];
            if (![targets getPointToNavigate])
                [_mapActions setFirstMapMarkerAsTarget];
        }
        OARTargetPoint *start = [targets getPointToStart];
        if (start)
        {
            [_mapActions enterRoutePlanningMode:[[CLLocation alloc] initWithLatitude:[start getLatitude] longitude:[start getLongitude]] fromName:[start getPointDescription]];
        }
        else
        {
            [_mapActions enterRoutePlanningMode:nil fromName:nil];
        }
        [self updateRouteButton];
    }
    else
    {
        [self showRouteInfo];
    }
}

- (void) switchToRouteFollowingLayout
{
    [_routingHelper setRoutePlanningMode:NO];
    [_mapViewTrackingUtilities switchToRoutePlanningMode];
    [self refreshMap];
}

- (BOOL) switchToRoutePlanningLayout
{
    if (![_routingHelper isRoutePlanningMode] && [_routingHelper isFollowingMode])
    {
        [_routingHelper setRoutePlanningMode:YES];
        [_mapViewTrackingUtilities switchToRoutePlanningMode];
        [self refreshMap];
        return YES;
    }
    return NO;
}


- (void) startNavigation
{
    if ([_routingHelper isFollowingMode])
    {
        [self switchToRouteFollowingLayout];
        if (_settings.applicationMode != [_routingHelper getAppMode])
            _settings.applicationMode = [_routingHelper getAppMode];

        if (_settings.simulateRouting && ![_app.locationServices.locationSimulation isRouteAnimating])
            [_app.locationServices.locationSimulation startStopRouteAnimation];
    }
    else
    {
        if (![[OATargetPointsHelper sharedInstance] checkPointToNavigateShort])
        {
            [self showRouteInfo];
        }
        else
        {
            //app.logEvent(mapActivity, "start_navigation");
            _settings.applicationMode = [_routingHelper getAppMode];
            [_mapViewTrackingUtilities backToLocationImpl:17 forceZoom:YES];
            _settings.followTheRoute = YES;
            [_routingHelper setFollowingMode:true];
            [_routingHelper setRoutePlanningMode:false];
            [_mapViewTrackingUtilities switchToRoutePlanningMode];
            [_routingHelper notifyIfRouteIsCalculated];
            [_routingHelper setCurrentLocation:_app.locationServices.lastKnownLocation returnUpdatedLocation:false];
            
            [self updateRouteButton];
            [self updateToolbar];
            
            if (_settings.simulateRouting && ![_app.locationServices.locationSimulation isRouteAnimating])
                [_app.locationServices.locationSimulation startStopRouteAnimation];
        }
    }
}

- (void) stopNavigation
{
    [self closeRouteInfo];
    if ([_routingHelper isFollowingMode])
        [_mapActions stopNavigationActionConfirm];
    else
        [_mapActions stopNavigationWithoutConfirm];

    if (_settings.simulateRouting && [_app.locationServices.locationSimulation isRouteAnimating])
        [_app.locationServices.locationSimulation startStopRouteAnimation];
}

- (void) updateRouteButton
{
    dispatch_async(dispatch_get_main_queue(), ^{
        bool routePlanningMode = false;
        if ([_routingHelper isRoutePlanningMode])
        {
            routePlanningMode = true;
        }
        else if (([_routingHelper isRouteCalculated] || [_routingHelper isRouteBeingCalculated]) && ![_routingHelper isFollowingMode])
        {
            routePlanningMode = true;
        }
        
        [self.hudViewController updateRouteButton:routePlanningMode followingMode:[_routingHelper isFollowingMode]];
    });
}

- (void) updateColors
{
    [_targetMenuView updateColors];
    [self updateRouteButton];
}

#pragma mark - OARouteCalculationProgressCallback

- (void) updateProgress:(int)progress
{
    //NSLog(@"Route calculation in progress: %d", progress);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.hudViewController onRoutingProgressChanged:progress];
    });
}

- (void) finish
{
    NSLog(@"Route calculation finished");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.hudViewController onRoutingProgressFinished];
    });
}

- (void) requestPrivateAccessRouting
{
    
}

#pragma mark - OARouteInformationListener

- (void) newRouteIsCalculated:(BOOL)newRoute
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateRouteButton];
    });
}

- (void) routeWasUpdated
{
}

- (void) routeWasCancelled
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateRouteButton];
    });
}

- (void) routeWasFinished
{
}

@end

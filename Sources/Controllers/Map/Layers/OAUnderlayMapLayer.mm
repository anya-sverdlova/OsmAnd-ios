//
//  OAUnderlayMapLayer.m
//  OsmAnd
//
//  Created by Alexey Kulish on 11/06/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//

#import "OAUnderlayMapLayer.h"
#import "OAMapCreatorHelper.h"
#import "OAMapViewController.h"
#import "OAMapRendererView.h"
#import "OAAutoObserverProxy.h"

#include "OASQLiteTileSourceMapLayerProvider.h"
#include "OAWebClient.h"
#include <OsmAndCore/IWebClient.h>
#include <OsmAndCore/Map/OnlineTileSources.h>
#include <OsmAndCore/Map/OnlineRasterMapLayerProvider.h>

@implementation OAUnderlayMapLayer
{
    std::shared_ptr<OsmAnd::IMapLayerProvider> _rasterUnderlayMapProvider;
    OAAutoObserverProxy* _underlayMapSourceChangeObserver;
    OAAutoObserverProxy* _underlayAlphaChangeObserver;
    std::shared_ptr<OsmAnd::IWebClient> _webClient;
}

- (NSString *) layerId
{
    return [NSString stringWithFormat:@"%@_%d", kUnderlayMapLayerId, self.layerIndex];
}

- (void) initLayer
{
    _webClient = std::make_shared<OAWebClient>();
    
    _underlayMapSourceChangeObserver = [[OAAutoObserverProxy alloc] initWith:self
                                                                withHandler:@selector(onUnderlayLayerChanged)
                                                                 andObserve:self.app.data.underlayMapSourceChangeObservable];
    _underlayAlphaChangeObserver = [[OAAutoObserverProxy alloc] initWith:self
                                                            withHandler:@selector(onUnderlayLayerAlphaChanged)
                                                             andObserve:self.app.data.underlayAlphaChangeObservable];
}

- (void) deinitLayer
{
    if (_underlayMapSourceChangeObserver)
    {
        [_underlayMapSourceChangeObserver detach];
        _underlayMapSourceChangeObserver = nil;
    }
    if (_underlayAlphaChangeObserver)
    {
        [_underlayAlphaChangeObserver detach];
        _underlayAlphaChangeObserver = nil;
    }
    
    _webClient = nil;
}

- (void) resetLayer
{
    _rasterUnderlayMapProvider.reset();
    [self.mapView resetProviderFor:self.layerIndex];
}

- (BOOL) updateLayer
{
    if (self.app.data.underlayMapSource)
    {
        [self showProgressHUD];

        if ([self.app.data.underlayMapSource.name isEqualToString:@"sqlitedb"])
        {
            NSString *path = [OAMapCreatorHelper sharedInstance].files[self.app.data.underlayMapSource.resourceId];
            
            const auto sqliteTileSourceMapProvider = std::make_shared<OASQLiteTileSourceMapLayerProvider>(QString::fromNSString(path));
            
            _rasterUnderlayMapProvider = sqliteTileSourceMapProvider;
            [self.mapView setProvider:_rasterUnderlayMapProvider forLayer:self.layerIndex];
            
            OsmAnd::MapLayerConfiguration config;
            config.setOpacityFactor(1.0 - self.app.data.underlayAlpha);
            [self.mapView setMapLayerConfiguration:self.layerIndex configuration:config forcedUpdate:NO];
        }
        else
        {    const auto resourceId = QString::fromNSString(self.app.data.underlayMapSource.resourceId);
            const auto mapSourceResource = self.app.resourcesManager->getResource(resourceId);
            if (mapSourceResource && _webClient)
            {
                const auto& onlineTileSources = std::static_pointer_cast<const OsmAnd::ResourcesManager::OnlineTileSourcesMetadata>(mapSourceResource->metadata)->sources;
                
                const auto onlineMapTileProvider = onlineTileSources->createProviderFor(QString::fromNSString(self.app.data.underlayMapSource.variant), _webClient);
                if (onlineMapTileProvider)
                {
                    onlineMapTileProvider->setLocalCachePath(QString::fromNSString(self.app.cachePath));
                    _rasterUnderlayMapProvider = onlineMapTileProvider;
                    [self.mapView setProvider:_rasterUnderlayMapProvider forLayer:self.layerIndex];
                    
                    OsmAnd::MapLayerConfiguration config;
                    config.setOpacityFactor(1.0 - self.app.data.underlayAlpha);
                    [self.mapView setMapLayerConfiguration:self.layerIndex configuration:config forcedUpdate:NO];
                }
            }
        }
        
        [self hideProgressHUD];

        return YES;
    }
    return NO;
}

- (void) onUnderlayLayerAlphaChanged
{
    [self.mapViewController runWithRenderSync:^{
        OsmAnd::MapLayerConfiguration config;
        config.setOpacityFactor(1.0 - self.app.data.underlayAlpha);
        [self.mapView setMapLayerConfiguration:0 configuration:config forcedUpdate:NO];
    }];
}

- (void) onUnderlayLayerChanged
{
    [self updateUnderlayLayer];
}

- (void) updateUnderlayLayer
{
    [self.mapViewController runWithRenderSync:^{
        if (![self updateLayer])
        {
            OsmAnd::MapLayerConfiguration config;
            config.setOpacityFactor(self.app.data.underlayAlpha);
            [self.mapView setMapLayerConfiguration:1.0 configuration:config forcedUpdate:NO];
            
            [self.mapView resetProviderFor:self.layerIndex];
            _rasterUnderlayMapProvider.reset();
        }
    }];
}

@end

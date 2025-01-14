//
//  OASearchUICore.h
//  OsmAnd
//
//  Created by Alexey Kulish on 11/01/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//
//  OsmAnd-java/src/net/osmand/search/SearchUICore.java
//  git revision ff5900b8e51b6b16ed0828180ec387bbbb8f77cd

#import <Foundation/Foundation.h>
#import "OASearchResult.h"
#import "OAResultMatcher.h"

@class OASearchPhrase, OASearchCoreAPI, OACustomSearchPoiFilter, OASearchSettings;

@interface OASearchResultCollection : NSObject

@property (nonatomic) OASearchPhrase *phrase;

- (instancetype)initWithPhrase:(OASearchPhrase *)phrase;

- (OASearchResultCollection *) combineWithCollection:(OASearchResultCollection *)collection resort:(BOOL)resort removeDuplicates:(BOOL)removeDuplicates;
- (OASearchResultCollection *) addSearchResults:(NSArray<OASearchResult *> *)sr resortAll:(BOOL)resortAll removeDuplicates:(BOOL)removeDuplicates;
- (NSArray<OASearchResult *> *) getCurrentSearchResults;
- (void) sortSearchResults;
- (void) filterSearchDuplicateResults;
- (BOOL) sameSearchResult:(OASearchResult *)r1 r2:(OASearchResult *)r2;

@end


@interface OASearchResultComparator : NSObject

- (instancetype) initWithPhrase:(OASearchPhrase *)phrase;

@end


@interface OASearchUICore : NSObject

typedef void (^OASearchUICoreRunnable)();

@property (nonatomic) OASearchUICoreRunnable onSearchStart;
@property (nonatomic) OASearchUICoreRunnable onResultsComplete;

- (instancetype) initWithLang:(NSString *)lang transliterate:(BOOL)transliterate;

- (OASearchCoreAPI *) getApiByClass:(Class)cl;
- (OASearchResultCollection *) shallowSearch:(Class)cl text:(NSString *)text matcher:(OAResultMatcher<OASearchResult *> *)matcher;
- (void) initApi;

- (void) clearCustomSearchPoiFilters;
- (void) addCustomSearchPoiFilter:(OACustomSearchPoiFilter *)poiFilter  priority:(int)priority;
- (void) registerAPI:(OASearchCoreAPI *)api;

- (OASearchResultCollection *) getCurrentSearchResult;
- (OASearchPhrase *) getPhrase;
- (OASearchSettings *) getSearchSettings;

- (void) updateSettings:(OASearchSettings *)settings;
- (BOOL) selectSearchResult:(OASearchResult *)r;

- (OASearchPhrase *) resetPhrase;
- (OASearchPhrase *) resetPhrase:(NSString *)text;

- (void) search:(NSString *)text delayedExecution:(BOOL)delayedExecution matcher:(OAResultMatcher<OASearchResult *> *)matcher;
- (void) cancelSearch;

- (BOOL) isSearchMoreAvailable:(OASearchPhrase *)phrase;
- (int) getMinimalSearchRadius:(OASearchPhrase *)phrase;
- (int) getNextSearchRadius:(OASearchPhrase *)phrase;

@end

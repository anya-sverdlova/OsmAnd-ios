//
//  OAEditPOIData.m
//  OsmAnd
//
//  Created by Paul on 1/25/19.
//  Copyright © 2019 OsmAnd. All rights reserved.
//

#import "OAEditPOIData.h"
#import "OrderedDictionary.h"
#import "OAEntity.h"
#import "OAPOIHelper.h"
#import "OAPOIType.h"
#import "OAObservable.h"

@implementation OAEditPOIData
{
    MutableOrderedDictionary *_tagValues;
    BOOL _isInEdit;
    OAEntity *_entity;
    BOOL _hasChangesBeenMade;
    NSDictionary<NSString *, OAPOIType *> *_allTranslatedSubTypes;
    OAPOICategory *_category;
    OAPOIType *_currentPoiType;
    
    NSMutableSet<NSString *> *_changedTags;
    
    OAPOIHelper *_poiHelper;
}


-(id) initWithEntity:(OAEntity *)entity
{
    self = [super init];
    if (self) {
        _entity = entity;
        _poiHelper = [OAPOIHelper sharedInstance];
        _category = _poiHelper.otherPoiCategory;
        _allTranslatedSubTypes = [_poiHelper getAllTranslatedNames:YES];
        _tagValues = [[MutableOrderedDictionary alloc] init];
        _changedTags = [NSMutableSet new];
        _tagsChangedObservable = [[OAObservable alloc] init];
        [self initTags:entity];
        [self updateTypeTag:[self getPoiTypeString] userChanges:NO];
    }
    return self;
}

-(void)initTags:(OAEntity *) entity
{
    if (_isInEdit)
        return;
    
    for (NSString *s in [entity getTagKeySet]) {
        [self tryAddTag:s value:[entity getTagFromString:s]];
    }
    [self retrieveType];
}

-(NSDictionary<NSString *, OAPOIType *> *)getAllTranslatedSubTypes
{
    return _allTranslatedSubTypes;
}

-(NSArray*) getTranslatedSubTypesMatchingWith:(NSString*) searchString
{
    NSArray<NSString *> *tags = [_allTranslatedSubTypes allKeys];
//search for now is case insensitive
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF contains[c] %@",searchString];
    NSArray* result = [tags filteredArrayUsingPredicate:predicate];
    return result;
}

-(void)updateType:(OAPOICategory *)type
{
    if(type && type != _category)
    {
        _category = type;
        [_tagValues setObject:@"" forKey:POI_TYPE_TAG];
        [_changedTags addObject:POI_TYPE_TAG];
    }
}

-(OAPOICategory *)getPoiCategory
{
    return _category;
}

-(OAPOIType *)getCurrentPoiType
{
    return _currentPoiType;
}

-(OAPOIType *) getPoiTypeDefined
{
    return [_allTranslatedSubTypes objectForKey:[[self getPoiTypeString] lowerCase]];
}

-(NSString *) getPoiTypeString
{
    NSString *s = [_tagValues objectForKey:POI_TYPE_TAG];
    return !s ? @"" : s;
}

-(OAEntity *) getEntity
{
    return _entity;
}

-(NSString *) getTag:(NSString *) key
{
    return [_tagValues objectForKey:key];
}

-(void)updateTags:(NSDictionary<NSString *, NSString *> *) tagMap
{
    if (_isInEdit)
        return;
    
    [_tagValues removeAllObjects];
    [_tagValues addEntriesFromDictionary:tagMap];

    [_changedTags removeAllObjects];
    [self retrieveType];
}

-(NSDictionary<NSString *, NSString *> *)getTagValues
{
    return [OrderedDictionary dictionaryWithDictionary:_tagValues];
}

-(void)putTag:(NSString *)tag value:(NSString *)value
{
    if (_isInEdit)
        return;
    
    _isInEdit = YES;
    [_tagValues removeObjectForKey:[REMOVE_TAG_PREFIX stringByAppendingString:tag]];
    NSString *oldValue = [_tagValues objectForKey:tag];
    if (!oldValue || ![oldValue isEqualToString:value])
        [_changedTags addObject:tag];
    
    [_tagValues setObject:value forKey:tag];
    // TODO: check if notification is necessary after the advanced editing is implemented
    //notifyDatasetChanged(tag);
    _hasChangesBeenMade = YES;
    _isInEdit = false;
    
}
// UNUSED
//-(void) notifyToUpdateUI
//{
//    if (_isInEdit)
//        return;
//    
//    _isInEdit = YES;
//    [_tagsChangedObservable notifyEventWithKey:nil];
//    _isInEdit = NO;
//}

-(void)removeTag:(NSString *)tag
{
    if (_isInEdit)
        return;
    _isInEdit = YES;
    [_tagValues setObject:REMOVE_TAG_VALUE forKey:[REMOVE_TAG_PREFIX stringByAppendingString:tag]];
    [_tagValues removeObjectForKey:tag];
    [_tagsChangedObservable notifyEventWithKey:tag];
    _hasChangesBeenMade = YES;
    _isInEdit = NO;
    
}

-(void)setIsInEdit:(BOOL)isInEdit
{
    _isInEdit = isInEdit;
}

-(BOOL)isInEdit
{
    return _isInEdit;
}

-(NSSet<NSString *> *)getChangedTags
{
    return [NSSet setWithSet:_changedTags];
}

-(BOOL)hasChangesBeenMade
{
    return _hasChangesBeenMade;
}

-(void)updateTypeTag:(NSString *)newTag userChanges:(BOOL)userChanges
{
    if (_isInEdit)
        return;
    
    [_tagValues setObject:newTag forKey:POI_TYPE_TAG];
    if (userChanges)
        [_changedTags addObject:POI_TYPE_TAG];
    
    [self retrieveType];
    OAPOIType *pt = [self getPoiTypeDefined];
    if (pt) {
        [self removeTypeTagWithPrefix:[_tagValues objectForKey:[REMOVE_TAG_PREFIX stringByAppendingString:pt.getEditOsmTag]] == nil];
        _currentPoiType = pt;
        [_tagValues setObject:pt.getEditOsmValue forKey:pt.getEditOsmTag];
        if (userChanges)
            [_changedTags addObject:pt.getEditOsmTag];
        
        _category = pt.category;
    }
    else if (_currentPoiType)
    {
        [self removeTypeTagWithPrefix:YES];
        _category = _currentPoiType.category;
    }
    [_tagsChangedObservable notifyEventWithKey:POI_TYPE_TAG];
    _hasChangesBeenMade = userChanges;
    _isInEdit = NO;
}

-(void)tryAddTag:(NSString *)key value:(NSString *) value
{
    if (value.length > 0)
        [_tagValues setObject:value forKey:key];
}

-(void)retrieveType
{
    NSString *type = [_tagValues objectForKey:POI_TYPE_TAG];
    if (type)
    {
        OAPOIType *pt = [_allTranslatedSubTypes objectForKey:type];
        if (pt)
            _category = pt.category;
        
    }
}

-(void)removeTypeTagWithPrefix:(BOOL)needRemovePrefix
{
    if (_currentPoiType) {
        if (needRemovePrefix) {
            [_tagValues setObject:REMOVE_TAG_VALUE forKey:[REMOVE_TAG_PREFIX stringByAppendingString:_currentPoiType.getEditOsmTag]];
            if (_currentPoiType.getOsmTag2)
                [_tagValues setObject:REMOVE_TAG_VALUE forKey:[REMOVE_TAG_PREFIX stringByAppendingString:_currentPoiType.getOsmTag2]];
        } else {
            [_tagValues removeObjectForKey:[REMOVE_TAG_PREFIX stringByAppendingString:_currentPoiType.getEditOsmTag]];
            if (_currentPoiType.getOsmTag2)
                [_tagValues removeObjectForKey:[REMOVE_TAG_PREFIX stringByAppendingString:_currentPoiType.getOsmTag2]];
        }
        [self removeCurrentTypeTag];
    }
}

-(void)removeCurrentTypeTag
{
    if (_currentPoiType)
    {
        [_tagValues removeObjectForKey:_currentPoiType.getEditOsmTag];
        [_tagValues removeObjectForKey:_currentPoiType.getOsmTag2];
        [_changedTags minusSet:[NSSet setWithObjects:_currentPoiType.getEditOsmTag, _currentPoiType.getOsmTag2, nil]];
    }
}

@end

//
//  OAMapCreatorHelper.m
//  OsmAnd
//
//  Created by Alexey Kulish on 31/07/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OAMapCreatorHelper.h"
#import "OALog.h"

@implementation OAMapCreatorHelper

+ (OAMapCreatorHelper *)sharedInstance
{
    static dispatch_once_t once;
    static OAMapCreatorHelper * sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)addSqliteFilePaths:(NSMutableDictionary *)filesArray path:(NSString *)path
{
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
    if (files)
    {
        for (NSString *file in files)
        {
            if ([[file pathExtension] caseInsensitiveCompare:@"sqlitedb"] == NSOrderedSame &&
                ![file hasPrefix:@"Hillshade_"] &&
                ![file hasPrefix:@"Heightmap_"] &&
                ![file hasSuffix:@"hillshade.sqlite"] &&
                ![file hasSuffix:@"heightmap.sqlite"])
            {
                [filesArray setObject:[path stringByAppendingPathComponent:file] forKey:file];
            }
        }
    }
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _sqlitedbResourcesChangedObservable = [[OAObservable alloc] init];
        NSFileManager *fileManager = [NSFileManager defaultManager];

        _filesDir = [NSHomeDirectory() stringByAppendingString:@"/Library/MapCreator"];
        _documentsDir = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].lastObject.path;
        
        BOOL isDir = YES;
        if (![fileManager fileExistsAtPath:_filesDir isDirectory:&isDir])
            [fileManager createDirectoryAtPath:_filesDir withIntermediateDirectories:YES attributes:nil error:nil];
        
        NSMutableDictionary *filesArray = [NSMutableDictionary dictionary];
        
        [self addSqliteFilePaths:filesArray path:_filesDir];
        [self addSqliteFilePaths:filesArray path:_documentsDir];
        
        _files = [NSDictionary dictionaryWithDictionary:filesArray];
    }
    return self;
}

- (BOOL)installFile:(NSString *)filePath newFileName:(NSString *)newFileName
{
    NSString *fileName;
    if (newFileName)
        fileName = newFileName;
    else
        fileName = [filePath lastPathComponent];
    
    if (self.files[fileName])
        [self removeFile:fileName];

    NSString *path = [self.filesDir stringByAppendingPathComponent:fileName];
    NSError *error;
    [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:path error:&error];
    if (error)
    {
        OALog(@"Failed installation MapCreator db file: %@", filePath);
    }
    else
    {
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:_files];
        [tmp setObject:path forKey:fileName];
        _files = [NSDictionary dictionaryWithDictionary:tmp];
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    
    if (error)
    {
        return NO;
    }
    else
    {
        [_sqlitedbResourcesChangedObservable notifyEvent];
        return YES;
    }
    
    return (error == nil);
}

- (void)removeFile:(NSString *)fileName
{
    NSString *path = self.files[fileName];

    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:self.files];
    [dictionary removeObjectForKey:fileName];
    _files = [NSDictionary dictionaryWithDictionary:dictionary];

    [_sqlitedbResourcesChangedObservable notifyEvent];
}

- (NSString *)getNewNameIfExists:(NSString *)fileName
{
    NSString *res;
    
    if (self.files[fileName])
    {
        NSFileManager *fileMan = [NSFileManager defaultManager];
        NSString *ext = [fileName pathExtension];
        NSString *newName;
        for (int i = 2; i < 100000; i++) {
            newName = [[NSString stringWithFormat:@"%@_%d", [fileName stringByDeletingPathExtension], i] stringByAppendingPathExtension:ext];
            if (![fileMan fileExistsAtPath:[self.filesDir stringByAppendingPathComponent:newName]])
                break;
        }
        res = newName;
    }
    
    return res;
}

@end

//
//  XLGResourceFile.m
//  Xiblingual
//
//  Created by hetima on 2014/04/04.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import "XLGResourceFile.h"

typedef NS_ENUM(NSUInteger, XLGResourceType) {
    XLGResourceInvalid=0,
    XLGResourceXib,
    XLGResourceStoryboard,
    XLGResourceStrings,
};

@implementation XLGResourceFile{
    
    XLGResourceType _resourceType;

}


XLGResourceType XLG_resourceTypeOfFile(NSString* path)
{
    NSString* ext=[path pathExtension];
    if ([ext isEqualToString:@"xib"]) {
        return XLGResourceXib;
    }else if ([ext isEqualToString:@"storyboard"]){
        return XLGResourceStoryboard;
    }else if ([ext isEqualToString:@"strings"]){
        return XLGResourceStrings;
    }
    
    return XLGResourceInvalid;
}


- (instancetype)initWithFilePath:(NSString*)filePath
{
    self = [super init];
    if (self) {
        _path=filePath;
        _name=[[filePath lastPathComponent]stringByDeletingPathExtension];
        _resourceType=XLG_resourceTypeOfFile(filePath);
        NSString* basePath=[filePath stringByDeletingLastPathComponent];
        if ([[basePath pathExtension]isEqualToString:@"lproj"]) {
            NSString* parentDir=[basePath lastPathComponent];
            _language=[parentDir stringByDeletingPathExtension];
        }
    }
    
    return self;
}

- (BOOL) isLikeXib
{
    return (_resourceType==XLGResourceStoryboard || _resourceType==XLGResourceXib);
}

- (BOOL) isLikeStrings
{
    return (_resourceType==XLGResourceStrings);
}

- (BOOL)canUpdateResource
{

    if ([self isBaseXibFile]) {
        NSArray* ary=[self localizedFilesForBaseXibFile];
        if ([ary count]>0) {
            return YES;
        }
    }else{
        NSString* baseXibPath=[self baseXibFileForLocalizedFile];
        if (baseXibPath) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)canPreviewStringsAsXib
{
    if (![self isLikeStrings]) {
        return NO;
    }
    NSString* baseXibPath=[self baseXibFileForLocalizedFile];
    if (baseXibPath) {
        return YES;
    }
    return NO;
}

- (BOOL)isBaseXibFile
{
    if (![self isLikeXib]) {
        return NO;
    }
    
    if ([self.language isEqualToString:@"Base"]) {
        return YES;
    }
    return NO;
}

- (NSArray*)localizedFilesForBaseXibFile
{
    NSString* path=self.path;
    
    if (![self isBaseXibFile]) {
        return nil;
    }
    
    NSString* basePath=[path stringByDeletingLastPathComponent];
    NSString* parentPath=[basePath stringByDeletingLastPathComponent];
    
    NSString* xibName=[path lastPathComponent];
    NSString* stringsFileName=[[xibName stringByDeletingPathExtension]stringByAppendingPathExtension:@"strings"];
    NSMutableArray* result=[[NSMutableArray alloc]init];
    
    NSArray* files=[[NSFileManager defaultManager]contentsOfDirectoryAtPath:parentPath error:nil];
    for (NSString* file in files) {
        if ([file hasSuffix:@".lproj"] && ![file isEqualToString:@"Base.lproj"]) {
            NSString* localizePath=[parentPath stringByAppendingPathComponent:file];
            NSString* resourceFile=[localizePath stringByAppendingPathComponent:stringsFileName];
            if ([[NSFileManager defaultManager]fileExistsAtPath:resourceFile]) {
                [result addObject:resourceFile];
            }
            resourceFile=[localizePath stringByAppendingPathComponent:xibName];
            if ([[NSFileManager defaultManager]fileExistsAtPath:resourceFile]) {
                [result addObject:resourceFile];
            }
        }
    }
    
    return result;
}

- (NSString*)baseXibFileForLocalizedFile
{
    NSString* path=self.path;

    if ([self isBaseXibFile] || (![self isLikeXib] && ![self isLikeStrings])) {
        return nil;
    }
    
    if (![self.language length]>0) {
        return nil;
    }
    
    NSString* parentPath=[path stringByDeletingLastPathComponent];
    NSString* basePath=[[parentPath stringByDeletingLastPathComponent]stringByAppendingPathComponent:@"Base.lproj"];
    
    NSArray* candidates=nil;
    if ([self isLikeXib]) {
        candidates=@[
            [basePath stringByAppendingPathComponent:[self.path lastPathComponent]]
        ];
    }else if ([self isLikeStrings]){
        candidates=@[
            [basePath stringByAppendingPathComponent:[self.name stringByAppendingPathExtension:@"xib"]],
            [basePath stringByAppendingPathComponent:[self.name stringByAppendingPathExtension:@"storyboard"]]
        ];
    }
    
    for (NSString* candidate in candidates) {
        if ([[NSFileManager defaultManager]fileExistsAtPath:candidate]) {
            return candidate;
        }
    }

    return nil;
}

@end

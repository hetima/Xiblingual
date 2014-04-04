//
//  XLGResourceFile.h
//  Xiblingual
//
//  Created by hetima on 2014/04/04.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XLGResourceFile : NSObject

- (instancetype)initWithFilePath:(NSString*)filePath;

@property (nonatomic, strong) NSString* path;
@property (nonatomic, strong) NSString* name; // [[path lastPathComponent]stringByDeletingPathExtension]
@property (nonatomic, strong) NSString* language; // Base, ja, en... etc

- (BOOL) isLikeXib; // xib or storyboard
- (BOOL) isLikeStrings; // strings

- (BOOL)canUpdateResource;
- (BOOL)canPreviewStringsAsXib;
- (BOOL)isBaseXibFile;
- (NSString*)baseXibFileForLocalizedFile;
- (NSArray*)localizedFilesForBaseXibFile;

@end

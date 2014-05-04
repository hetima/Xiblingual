//
//  XLGXiblingual.h
//  XLGXiblingual


#import <AppKit/AppKit.h>

@interface XLGXiblingual : NSObject
@property (nonatomic, strong) NSBundle *bundle;

+ (NSString*)workingDirectoryInCache;
+ (NSString*)workingDirectoryInTemporary;
+ (NSString*)workingDirectoryRootInCache;
+ (NSString*)workingDirectoryRootInTemporary;

@end

NSURL* XLG_documentURLForIDENavigableItemArchivableRepresentation(id obj);

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

+ (BOOL)canUpdateResource:(NSString*)path;
+ (BOOL)canPreviewStringsAsXib:(NSString*)path;
+ (BOOL)isBaseXibFile:(NSString*)path;
+ (NSString*)baseXibFileForLocalizedFile:(NSString*)path;
+ (NSArray*)localizedFilesForBaseXibFile:(NSString*)path;

@end

IMP Replace_MethodImp_WithFunc(Class aClass, SEL origSel, const void* repFunc);
IMP Replace_ClassMethodImp_WithFunc(Class aClass, SEL origSel, const void* repFunc);


#ifndef REPFUNCDEFd
#define REPFUNCDEFd
#define RMF(aClass, origSel, repFunc) Replace_MethodImp_WithFunc(aClass, origSel, repFunc)
#define RCMF(aClass, origSel, repFunc) Replace_ClassMethodImp_WithFunc(aClass, origSel, repFunc)
#endif

NSURL* XLG_documentURLForIDENavigableItemArchivableRepresentation(id obj);

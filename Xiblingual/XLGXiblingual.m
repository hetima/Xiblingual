//
//  XLGXiblingual.m
//  XLGXiblingual


#import "XLGXiblingual.h"
#import "XLGContextMenuManager.h"
#import "XLGXibConverter.h"

IMP Replace_MethodImp_WithFunc(Class aClass, SEL origSel, const void* repFunc)
{
    Method origMethod;
    IMP oldImp = NULL;
    
    if (aClass && (origMethod = class_getInstanceMethod(aClass, origSel))){
        oldImp=method_setImplementation(origMethod, repFunc);
    }
    
    return oldImp;
}


IMP Replace_ClassMethodImp_WithFunc(Class aClass, SEL origSel, const void* repFunc)
{
    Method origMethod;
    IMP oldImp = NULL;
    
    if (aClass && (origMethod = class_getClassMethod(aClass, origSel))){
        oldImp=method_setImplementation(origMethod, repFunc);
    }
    
    return oldImp;
}

NSURL* XLG_documentURLForIDENavigableItemArchivableRepresentation(id obj)
{
    //obj == IDENavigableItemArchivableRepresentation

    NSURL* result=nil;
    SEL sel_documentLocation=NSSelectorFromString(@"documentLocation");
    if ([obj respondsToSelector:sel_documentLocation]) {
        id documentLocation=objc_msgSend(obj, sel_documentLocation); //DVTDocumentLocation
        
        SEL sel_documentURL=NSSelectorFromString(@"documentURL");
        if ([documentLocation respondsToSelector:sel_documentURL]) {
            result=objc_msgSend(documentLocation, sel_documentURL); //DVTDocumentLocation
        }
    }

    return result;
}

NSString* makeWorkingDirectoryInDirectory(NSString* parent)
{
    NSString* tmpDir=NSTemporaryDirectory();
    
    if (![[NSFileManager defaultManager]fileExistsAtPath:parent]) {
        [[NSFileManager defaultManager]createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    tmpDir=[parent stringByAppendingPathComponent:@"wd_XXXXXX"];
    
    size_t len=strlen([tmpDir fileSystemRepresentation]);
    char* template=malloc(len+10);
    if ([tmpDir getFileSystemRepresentation:template maxLength:len+10]) {
        if(mkdtemp(template)){
            tmpDir=[[NSFileManager defaultManager]stringWithFileSystemRepresentation:template length:len];
        }else{
            tmpDir=nil;
        }
        free(template);
    }
    
    BOOL isDir;
    if (tmpDir && (![[NSFileManager defaultManager]fileExistsAtPath:tmpDir isDirectory:&isDir] || !isDir)) {
        tmpDir=nil;
    }
    
    return tmpDir;
    
}

//static XLGXiblingual *sharedPlugin;


@implementation XLGXiblingual

+ (NSString*)workingDirectoryRootInCache
{
    NSString* tmpDir=nil;
    
    NSArray* dirs=NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if ([dirs count]>0) {
        tmpDir=[dirs objectAtIndex:0];
    }
    if (!tmpDir) {
        tmpDir=[@"~/Library/Caches" stringByExpandingTildeInPath];
    }
    tmpDir=[tmpDir stringByAppendingPathComponent:@"com.hetima.Xiblingual/WorkingDirectory"];

    return tmpDir;
}

+ (NSString*)workingDirectoryInCache
{
    return makeWorkingDirectoryInDirectory([self workingDirectoryRootInCache]);
}


+ (NSString*)workingDirectoryRootInTemporary
{
    NSString* tmpDir=NSTemporaryDirectory();
    if (!tmpDir) {
        tmpDir=@"/tmp";
    }
    tmpDir=[tmpDir stringByAppendingPathComponent:@"com.hetima.Xiblingual/WorkingDirectory"];
    
    return tmpDir;
}

+ (NSString*)workingDirectoryInTemporary
{
    return makeWorkingDirectoryInDirectory([self workingDirectoryRootInTemporary]);
}

#pragma mark - xcplugin

+ (BOOL)shouldLoadPlugin
{
    NSString *currentApplicationName = [[NSBundle mainBundle]infoDictionary][@"CFBundleName"];
    if (![currentApplicationName isEqual:@"Xcode"]){
        return NO;
    }
    
    NSString* ibtoolPath=[XLGXibConverter ibtoolPath];
    if (![[NSFileManager defaultManager]fileExistsAtPath:ibtoolPath]) {
        return NO;
    }
    
    Class cls=NSClassFromString(@"IDEStructureNavigator");
    if (![cls instancesRespondToSelector:NSSelectorFromString(@"menuNeedsUpdate:")]) {
        return NO;
    }
    
    return YES;
}

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    if ([self shouldLoadPlugin]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];

            [XLGContextMenuManager si];
            [XLGXibConverter si];

        });
    }
}

- (instancetype)initWithBundle:(NSBundle *)plugin
{
    self = [super init];
    if (self) {
        self.bundle = plugin;
        [self cleanupWorkingDirectory];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(appWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];

    }
    return self;
}

- (void)cleanupWorkingDirectory
{
    NSString* tmpDir;
    tmpDir=[XLGXiblingual workingDirectoryRootInTemporary];
    if ([[NSFileManager defaultManager]fileExistsAtPath:tmpDir]) {
        [[NSFileManager defaultManager]removeItemAtPath:tmpDir error:nil];
    }
    
    tmpDir=[XLGXiblingual workingDirectoryRootInCache];
    if ([[NSFileManager defaultManager]fileExistsAtPath:tmpDir]) {
        [[NSFileManager defaultManager]removeItemAtPath:tmpDir error:nil];
    }
}

- (void)appWillTerminate:(NSNotification*)note
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    [self cleanupWorkingDirectory];
}

@end

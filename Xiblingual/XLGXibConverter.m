//
//  XLGXibConverter.m
//  Xiblingual


#import "XLGXibConverter.h"

#define kXLGXibConverterEventStreamLatency			((CFTimeInterval)1.5)

#define kXibWatchInfoFileName @"FileInfo"
#define kXibWatchInfoStringsFile @"stringsFile"
#define kXibWatchInfoXibFile @"xibFile"
#define kXibWatchInfoXibFileModDate @"xibFileModDate"

@implementation XLGXibConverter{

    FSEventStreamRef _eventStream;
}

static void XLGXibConverterEventsCallback(
                               ConstFSEventStreamRef streamRef,
                               void *callbackCtxInfo,
                               size_t numEvents,
                               void *eventPaths, // CFArrayRef
                               const FSEventStreamEventFlags eventFlags[],
                               const FSEventStreamEventId eventIds[])
{
	XLGXibConverter *watcher			= (__bridge XLGXibConverter *)callbackCtxInfo;
	NSArray *eventPathsArray	= (__bridge NSArray *)eventPaths;
    

	for (NSUInteger i = 0; i < numEvents; ++i) {

        NSString *eventPath = [eventPathsArray objectAtIndex:i];
/*
        FSEventStreamEventFlags flags = eventFlags[i];
        LOG(@"%d%d%d%d%d%d:%@",
            ((flags) & (kFSEventStreamEventFlagItemCreated))!=0,
            ((flags) & (kFSEventStreamEventFlagItemRemoved))!=0,
            ((flags) & (kFSEventStreamEventFlagItemInodeMetaMod))!=0,
            ((flags) & (kFSEventStreamEventFlagItemRenamed))!=0,
            ((flags) & (kFSEventStreamEventFlagItemModified))!=0,
            ((flags) & (kFSEventStreamEventFlagItemFinderInfoMod))!=0,
            eventPath);
*/
        if ([eventPath hasSuffix:@".xib"]||[eventPath hasSuffix:@".storyboard"]){
            [watcher previewXibUpdated:eventPath];
        }
	}
}


+(instancetype)si
{
    static id sharedXibConverter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedXibConverter = [[self alloc]init];
        [sharedXibConverter setupEventStream];
    });
    return sharedXibConverter;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _eventStream=nil;
        //[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(appWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
    }
    return self;
}

- (void)appWillTerminate:(NSNotification*)note
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];

    //BUG in libdispatch client: kevent[EVFILT_WRITE] delete: "No such file or directory" - 0x2
    //とログが出る
    //[self invalidateEventStream];
}

+ (NSString*)ibtoolPath
{
    static NSString* ibtoolPath;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString* bundlePath=[[NSBundle mainBundle]bundlePath];
        ibtoolPath=[bundlePath stringByAppendingPathComponent:@"Contents/Developer/usr/bin/ibtool"];
    });
    return ibtoolPath;
    
    //return @"/Applications/Xcode.app/Contents/Developer/usr/bin/ibtool";
}


+ (void)updateStringsFile:(NSString*)stringsFile withBaseXibFile:(NSString*)baseXibFile
{
    NSArray* args;
    NSTask* task;
    NSString* tmpDir=[XLGXiblingual workingDirectoryInTemporary];
    
    // merge string to new-xib
    // ibtool --import-strings-file stringsFile --write new.xib baseXibFile
    NSString* tmpXibName=[@"new" stringByAppendingPathExtension:[baseXibFile pathExtension]];
    NSString* tmpXibFile=[tmpDir stringByAppendingPathComponent:tmpXibName];
    args=@[@"--import-strings-file", stringsFile, @"--write", tmpXibFile, baseXibFile];
    task=[NSTask launchedTaskWithLaunchPath:[XLGXibConverter ibtoolPath] arguments:args];
    [task waitUntilExit];
    int status = [task terminationStatus];

    // export strings from new-xib
    // ibtool --export-strings-file new.strings new.xib
    // コメント部分もローカライズされた文字列になってしまう
    NSString* tmpStringsFileUTF16=[tmpDir stringByAppendingPathComponent:@"new.strings.utf16"];
    args=@[@"--export-strings-file", tmpStringsFileUTF16, tmpXibFile];
    task=[NSTask launchedTaskWithLaunchPath:[XLGXibConverter ibtoolPath] arguments:args];
    [task waitUntilExit];
    status = [task terminationStatus];
    
    // utf16 to utf8
    // NSString* tmpStringsFile=[tmpDir stringByAppendingPathComponent:@"new.strings"];
    // detecting encoding seems work
    NSStringEncoding enc;
    NSString* contents=[NSString stringWithContentsOfFile:tmpStringsFileUTF16 usedEncoding:&enc error:nil];

    if ([contents length] /*&& enc==NSUnicodeStringEncoding*/) {
        [contents writeToFile:stringsFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }else{
        NSAlert *alert = [[NSAlert alloc]init];
        [alert setMessageText:@"Error: Couldn't generate strings file."];
        [alert runModal];
    }
    
    // delete tmp files
    [[NSFileManager defaultManager]removeItemAtPath:tmpDir error:nil];
}

+ (void)updateXibFile:(NSString*)xibFile withBaseXibFile:(NSString*)baseXibFile
{
    NSArray* args;
    NSTask* task;
    NSString* tmpDir=[XLGXiblingual workingDirectoryInTemporary];
    // export strings from xibFile
    NSString* tmpStringsFileUTF16=[tmpDir stringByAppendingPathComponent:@"new.strings.utf16"];
    args=@[@"--export-strings-file", tmpStringsFileUTF16, xibFile];
    task=[NSTask launchedTaskWithLaunchPath:[XLGXibConverter ibtoolPath] arguments:args];
    [task waitUntilExit];
    
    // merge string to baseXibFile
    NSString* tmpXibName=[@"new" stringByAppendingPathExtension:[baseXibFile pathExtension]];
    NSString* tmpXibFile=[tmpDir stringByAppendingPathComponent:tmpXibName];
    args=@[@"--import-strings-file", tmpStringsFileUTF16, @"--write", tmpXibFile, baseXibFile];
    task=[NSTask launchedTaskWithLaunchPath:[XLGXibConverter ibtoolPath] arguments:args];
    [task waitUntilExit];
    
    BOOL replaced;
    if ([[NSFileManager defaultManager]fileExistsAtPath:tmpXibFile]) {
        NSURL* originalLocation=[NSURL fileURLWithPath:xibFile];
        NSURL* newFileLocation=[NSURL fileURLWithPath:tmpXibFile];
        replaced=[[NSFileManager defaultManager]replaceItemAtURL:originalLocation withItemAtURL:newFileLocation backupItemName:nil options:0 resultingItemURL:nil error:nil];
    }
    if (!replaced) {
        NSAlert *alert = [[NSAlert alloc]init];
        [alert setMessageText:@"Error: Couldn't update layout file."];
        [alert runModal];
    }
    
    // delete tmp files
    [[NSFileManager defaultManager]removeItemAtPath:tmpDir error:nil];
}

+ (void)previewAsXibStringsFile:(NSString*)stringsFile withBaseXibFile:(NSString*)baseXibFile
{
    NSString* workingDir=[XLGXiblingual workingDirectoryInCache];
    
    // merge string to new-xib
    // ibtool --import-strings-file stringsFile --write new.xib baseXibFile
    NSString* lang=[[[stringsFile stringByDeletingLastPathComponent]lastPathComponent]stringByDeletingPathExtension];
    NSString* tmpXibName=[NSString stringWithFormat:@"[preview][%@]%@", lang, [baseXibFile lastPathComponent]];
    NSString* tmpXibFile=[workingDir stringByAppendingPathComponent:tmpXibName];
    NSArray* args=@[@"--import-strings-file", stringsFile, @"--write", tmpXibFile, baseXibFile];
    NSTask* task=[NSTask launchedTaskWithLaunchPath:[XLGXibConverter ibtoolPath] arguments:args];
    [task waitUntilExit];
    //int status = [task terminationStatus];
    
    if ([[NSFileManager defaultManager]fileExistsAtPath:tmpXibFile]) {
        //create watchInfo
        NSDate* modDate=[[[NSFileManager defaultManager]attributesOfItemAtPath:tmpXibFile error:nil]fileModificationDate];
        if (!modDate) modDate=[NSDate date];
        NSDictionary* info=@{kXibWatchInfoStringsFile:stringsFile, kXibWatchInfoXibFile:tmpXibFile, kXibWatchInfoXibFileModDate:modDate};
        
        NSString* infoFile=[workingDir stringByAppendingPathComponent:kXibWatchInfoFileName];
        [info writeToFile:infoFile atomically:YES];
        
        [[NSWorkspace sharedWorkspace]openFile:tmpXibFile withApplication:@"Xcode"];
    }else{
        NSAlert *alert = [[NSAlert alloc]init];
        [alert setMessageText:@"Error: Couldn't generate layout file."];
        [alert runModal];
    }
}

+ (void)exportToStringsFile:(NSString*)stringsFile fromXibFile:(NSString*)baseXibFile
{
    
    NSString* tmpDir=[XLGXiblingual workingDirectoryInTemporary];
    // export string from xib
    // ibtool --export-strings-file new.strings new.xib
    NSString* tmpStringsFileUTF16=[tmpDir stringByAppendingPathComponent:@"new.strings.utf16"];
    NSArray* args=@[@"--export-strings-file", tmpStringsFileUTF16, baseXibFile];
    NSTask* task=[NSTask launchedTaskWithLaunchPath:[XLGXibConverter ibtoolPath] arguments:args];
    [task waitUntilExit];
    //utf16 to utf8
    NSStringEncoding enc;
    NSString* contents=[NSString stringWithContentsOfFile:tmpStringsFileUTF16 usedEncoding:&enc error:nil];
    
    if ([contents length] /*&& enc==NSUnicodeStringEncoding*/) {
        [contents writeToFile:stringsFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }else{
        NSAlert *alert = [[NSAlert alloc]init];
        [alert setMessageText:@"Error: Couldn't generate strings file."];
        [alert runModal];
    }
    
    //delete tmp files
    [[NSFileManager defaultManager]removeItemAtPath:tmpDir error:nil];
}

#pragma mark - filesystem

- (void)previewXibUpdated:(NSString*)xibFile
{
    //infoFile check
    NSString* infoFile=[[xibFile stringByDeletingLastPathComponent]stringByAppendingPathComponent:kXibWatchInfoFileName];
    if (![[NSFileManager defaultManager]fileExistsAtPath:xibFile] || ![[NSFileManager defaultManager]fileExistsAtPath:infoFile]){
        return;
    }

    //xib name check
    NSDictionary* info=[NSDictionary dictionaryWithContentsOfFile:infoFile];
    if (![[info objectForKey:kXibWatchInfoXibFile]isEqualToString:xibFile]) {
        return;
    }
    
    //mod date check
    NSDate* modDate=[[[NSFileManager defaultManager]attributesOfItemAtPath:xibFile error:nil]fileModificationDate];
    NSDate* lastModDate=[info objectForKey:kXibWatchInfoXibFileModDate];
    if ([modDate isEqualToDate:lastModDate]) {
        return;
    }

    //update strings
    NSString* stringsFile=[info objectForKey:kXibWatchInfoStringsFile];
    [XLGXibConverter exportToStringsFile:stringsFile fromXibFile:xibFile];
    
    //save mod date info
    NSDictionary* newInfo=@{kXibWatchInfoStringsFile:stringsFile, kXibWatchInfoXibFile:xibFile, kXibWatchInfoXibFileModDate:modDate};
    [newInfo writeToFile:infoFile atomically:YES];
}


- (void)invalidateEventStream
{
    if (_eventStream) {
        FSEventStreamStop(_eventStream);
        FSEventStreamInvalidate(_eventStream);
        FSEventStreamRelease(_eventStream);
        _eventStream = nil;
    }
}

- (void)setupEventStream
{
    [self invalidateEventStream];
    NSArray* watchPaths;

    NSString* watchPath=[XLGXiblingual workingDirectoryRootInCache];
    watchPaths=@[watchPath];
    if (![[NSFileManager defaultManager]fileExistsAtPath:watchPath]) {
        [[NSFileManager defaultManager]createDirectoryAtPath:watchPath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    FSEventStreamCreateFlags flags=(kFSEventStreamCreateFlagUseCFTypes |
                                     kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagFileEvents);
    
	FSEventStreamContext callbackCtx;
	callbackCtx.version = 0;
	callbackCtx.info = (__bridge void *)self;
	callbackCtx.retain = NULL;
	callbackCtx.release = NULL;
	callbackCtx.copyDescription	= NULL;
    
	_eventStream = FSEventStreamCreate(kCFAllocatorDefault,
									   &XLGXibConverterEventsCallback,
									   &callbackCtx,
									   (__bridge CFArrayRef)watchPaths,
									   kFSEventStreamEventIdSinceNow,
									   kXLGXibConverterEventStreamLatency,
									   flags);
    FSEventStreamScheduleWithRunLoop(_eventStream, [[NSRunLoop currentRunLoop]getCFRunLoop], kCFRunLoopDefaultMode);
    if (!FSEventStreamStart(_eventStream)) {
        
    }
}

@end

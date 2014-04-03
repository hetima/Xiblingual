//
//  XLGXibConverter.h
//  Xiblingual


#import <Foundation/Foundation.h>

@interface XLGXibConverter : NSObject

+ (instancetype)si;
+ (NSString*)ibtoolPath;

+ (void)updateStringsFile:(NSString*)stringsFile withBaseXibFile:(NSString*)baseXibFile;
+ (void)updateXibFile:(NSString*)xibFile withBaseXibFile:(NSString*)baseXibFile;
+ (void)previewAsXibStringsFile:(NSString*)stringsFile withBaseXibFile:(NSString*)baseXibFile;

@end

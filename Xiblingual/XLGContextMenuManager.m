//
//  XLGContextMenuManager.m
//  Xiblingual


#import "XLGContextMenuManager.h"
#import "XLGXibConverter.h"

#define kIDEStructureNavigatorMenuItemUpdateStrings 3920
#define kIDEStructureNavigatorMenuItemPreviewAsXib 3921

@implementation XLGContextMenuManager

+(instancetype)si
{
    static id sharedContextMenuManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedContextMenuManager = [[self alloc]init];
        
        KZRMETHOD_SWIZZLING_WITHBLOCK
        (
         "IDEStructureNavigator",
         "menuNeedsUpdate:",
         KZRMethodInspection, call, sel,
         ^ (id slf, id menu){
             call.as_void(slf, sel, menu);
             [sharedContextMenuManager IDEStructureNavigatorMenuNeedsUpdate:menu];
         });
    });
    return sharedContextMenuManager;
}

-(NSMenu*)installToIDEStructureNavigatorMenu:(NSMenu*)menu
{
    NSMenu* subMenu=nil;
    NSInteger idx=[menu indexOfItemWithRepresentedObject:self];
    if (idx>=0) {
        subMenu=[[menu itemAtIndex:idx]submenu];
        NSMenuItem* subItem=[subMenu itemWithTag:kIDEStructureNavigatorMenuItemUpdateStrings];
        [subItem setTarget:nil];
        [subItem setTitle:@"Update Localized File"];
        [subItem setRepresentedObject:nil];
        subItem=[subMenu itemWithTag:kIDEStructureNavigatorMenuItemPreviewAsXib];
        [subItem setTarget:nil];
        [subItem setTitle:@"Preview Layout"];
        [subItem setRepresentedObject:nil];
        return subMenu;
    }
    
    subMenu=[[NSMenu alloc]initWithTitle:@"Xiblingual"];
    NSMenuItem* itm=[[NSMenuItem alloc]initWithTitle:@"Xiblingual" action:nil keyEquivalent:@""];
    [itm setRepresentedObject:self];
    [itm setSubmenu:subMenu];
    
    NSMenuItem* subItem;
    subItem=[subMenu addItemWithTitle:@"Update Localized File" action:@selector(XLGContextMenu_updateResouces:) keyEquivalent:@""];
    [subItem setTag:kIDEStructureNavigatorMenuItemUpdateStrings];
    
    [subMenu addItem:[NSMenuItem separatorItem]];

    subItem=[subMenu addItemWithTitle:@"Preview Layout" action:@selector(XLGContextMenu_PreviewAsXib:) keyEquivalent:@""];
    [subItem setTag:kIDEStructureNavigatorMenuItemPreviewAsXib];
    
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:itm];
    
    return subMenu;
}

-(void)IDEStructureNavigatorMenuNeedsUpdate:(NSMenu*)menu
{
    NSMenu* myMenu=[self installToIDEStructureNavigatorMenu:menu];
    NSString*  selectedFilePath=nil;
    
    id nav=[menu delegate]; //IDEStructureNavigator
    SEL sel_contextMenuSelection=NSSelectorFromString(@"contextMenuSelection");
    if ([nav respondsToSelector:sel_contextMenuSelection]) {
        id selection=objc_msgSend(nav, sel_contextMenuSelection);//IDESelection

        SEL sel_navigableItemArchivableRepresentations=NSSelectorFromString(@"navigableItemArchivableRepresentations");
        if ([selection respondsToSelector:sel_navigableItemArchivableRepresentations]) {
            id selectedItems=objc_msgSend(selection, sel_navigableItemArchivableRepresentations);//NSArray
            if ([selectedItems count]==1) {
                id navigableItemArchivableRepresentation=[selectedItems objectAtIndex:0];
                NSURL* selectedURL=XLG_documentURLForIDENavigableItemArchivableRepresentation(navigableItemArchivableRepresentation);
                if([selectedURL isFileURL]){
                    selectedFilePath=[selectedURL path];
                }
            }
        }
    }
    if (selectedFilePath) {
        XLGResourceFile* res=[[XLGResourceFile alloc]initWithFilePath:selectedFilePath];
        
        if ([res canUpdateResource]) {
            NSMenuItem* subItem=[myMenu itemWithTag:kIDEStructureNavigatorMenuItemUpdateStrings];
            [subItem setTarget:self];
            NSString* title;
            
            if ([res isBaseXibFile]) {
                title=[NSString stringWithFormat:@"Update All Localized %@", [[selectedFilePath lastPathComponent]stringByDeletingPathExtension]];
            }else{
                title=[NSString stringWithFormat:@"Update %@ (%@)", [selectedFilePath lastPathComponent], res.language];
            }
            [subItem setTitle:title];
            [subItem setRepresentedObject:res];
        }
        if ([res canPreviewStringsAsXib]) {
            NSMenuItem* subItem=[myMenu itemWithTag:kIDEStructureNavigatorMenuItemPreviewAsXib];
            [subItem setTarget:self];
            [subItem setTitle:@"Preview Layout"];
            [subItem setRepresentedObject:res];
        }
    }

}


- (void)XLGContextMenu_updateResouces:(id)sender
{
    XLGResourceFile* res=[sender representedObject];
    NSString* baseXibFile;
    NSArray* resourceFiles=nil;
    if ([res isBaseXibFile]) { //base xib
        
        baseXibFile=res.path;
        resourceFiles=[res localizedFilesForBaseXibFile];
        
    }else{ //strings or xib
        
        baseXibFile=[res baseXibFileForLocalizedFile];
        resourceFiles=@[res.path];
    }
    
    for (NSString* resourceFile in resourceFiles) {
        
        NSString* ext=[resourceFile pathExtension];
        if ([ext isEqualToString:@"strings"]) {
            [XLGXibConverter updateStringsFile:resourceFile withBaseXibFile:baseXibFile];
        }else{ // xib or storyboard
            [XLGXibConverter updateXibFile:resourceFile withBaseXibFile:baseXibFile];
        }
    }
}

- (void)XLGContextMenu_PreviewAsXib:(id)sender
{

    XLGResourceFile* res=[sender representedObject];
    
    if ([res isLikeStrings]) {
        NSString* baseXibFile=[res baseXibFileForLocalizedFile];
        [XLGXibConverter previewAsXibStringsFile:res.path withBaseXibFile:baseXibFile];
    }
}

@end

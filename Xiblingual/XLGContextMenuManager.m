//
//  XLGContextMenuManager.m
//  Xiblingual


#import "XLGContextMenuManager.h"
#import "XLGXibConverter.h"

#define kIDEStructureNavigatorMenuItemUpdateStrings 3920
#define kIDEStructureNavigatorMenuItemPreviewAsXib 3921

@implementation XLGContextMenuManager

static void (*orig_XLG_menuNeedsUpdate)(id, SEL, ...);
static void XLG_menuNeedsUpdate(id self, SEL _cmd, id menu)
{
    orig_XLG_menuNeedsUpdate(self, _cmd, menu);
    [[XLGContextMenuManager si]IDEStructureNavigatorMenuNeedsUpdate:menu];
}


+(instancetype)si
{
    static id sharedContextMenuManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedContextMenuManager = [[self alloc]init];
        orig_XLG_menuNeedsUpdate = (void (*)(id, SEL, ...))RMF(
               NSClassFromString(@"IDEStructureNavigator"),
               NSSelectorFromString(@"menuNeedsUpdate:"), XLG_menuNeedsUpdate);
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
        [subItem setTitle:@"Preview as xib"];
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

    subItem=[subMenu addItemWithTitle:@"Preview as xib" action:@selector(XLGContextMenu_PreviewAsXib:) keyEquivalent:@""];
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
        
        if ([XLGXiblingual canUpdateResource:selectedFilePath]) {
            NSMenuItem* subItem=[myMenu itemWithTag:kIDEStructureNavigatorMenuItemUpdateStrings];
            [subItem setTarget:self];
            NSString* title;
            
            if ([XLGXiblingual isBaseXibFile:selectedFilePath]) {
                title=[NSString stringWithFormat:@"Update All Localized %@", [[selectedFilePath lastPathComponent]stringByDeletingPathExtension]];
            }else{
                NSString* lang=[[[selectedFilePath stringByDeletingLastPathComponent]lastPathComponent]stringByDeletingPathExtension];
                title=[NSString stringWithFormat:@"Update %@ (%@)", [selectedFilePath lastPathComponent], lang];
            }
            [subItem setTitle:title];
            [subItem setRepresentedObject:selectedFilePath];
        }
        if ([XLGXiblingual canPreviewStringsAsXib:selectedFilePath]) {
            NSMenuItem* subItem=[myMenu itemWithTag:kIDEStructureNavigatorMenuItemPreviewAsXib];
            [subItem setTarget:self];
            [subItem setTitle:@"Preview as xib"];
            [subItem setRepresentedObject:selectedFilePath];
        }
    }

}


- (void)XLGContextMenu_updateResouces:(id)sender
{
    NSString* path=[sender representedObject];
    NSString* baseXibFile;
    NSArray* resourceFiles=nil;
    if ([XLGXiblingual isBaseXibFile:path]) { //base xib
        
        baseXibFile=path;
        resourceFiles=[XLGXiblingual localizedFilesForBaseXibFile:path];
        
    }else{ //strings or xib
        
        baseXibFile=[XLGXiblingual baseXibFileForLocalizedFile:path];
        resourceFiles=@[path];
    }
    
    for (NSString* resourceFile in resourceFiles) {
        
        NSString* ext=[resourceFile pathExtension];
        if ([ext isEqualToString:@"strings"]) {
            [XLGXibConverter updateStringsFile:resourceFile withBaseXibFile:baseXibFile];
        }else if ([ext isEqualToString:@"xib"]){
            [XLGXibConverter updateXibFile:resourceFile withBaseXibFile:baseXibFile];
        }
    }
}

- (void)XLGContextMenu_PreviewAsXib:(id)sender
{

    NSString* stringsFile=[sender representedObject];
    
    if ([[stringsFile pathExtension]isEqualToString:@"strings"]) {
        NSString* baseXibFile=[XLGXiblingual baseXibFileForLocalizedFile:stringsFile];
        [XLGXibConverter previewAsXibStringsFile:stringsFile withBaseXibFile:baseXibFile];
    }
}

@end

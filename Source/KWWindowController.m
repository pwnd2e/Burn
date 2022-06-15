//
//  KWMainWindowController.m
//  Burn
//
//  Created by Maarten Foukhar on 08-10-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWWindowController.h"
#import "KWCommonMethods.h"
#import "KWTabViewItem.h"
#import <Carbon/Carbon.h>
#import <LetsMove/LetsMove.h>
#import "KWDataController.h"
#import "KWAudioController.h"
#import "KWVideoController.h"
#import "KWCopyController.h"

@interface KWWindowController() <NSToolbarDelegate>

@property (nonatomic, weak) IBOutlet KWDataController *dataController;
@property (nonatomic, weak) IBOutlet KWAudioController *audioController;
@property (nonatomic, weak) IBOutlet KWVideoController *videoController;
@property (nonatomic, weak) IBOutlet KWCopyController *discCopyController;

@property (nonatomic, weak) IBOutlet NSButton *changeRecorderButton;

@end

@implementation KWWindowController

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
    PFMoveToApplicationsFolderIfNecessary();
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

- (void)showNotificationWithTitle:(nonnull NSString *)title withMessage:(nonnull NSString *)message withImage:(NSImage *)image
{
    // TODO: use new methods on the upcoming Mac OS release
    NSUserNotification *userNotification = [[NSUserNotification alloc] init];
    [userNotification setTitle:title];
    [userNotification setInformativeText:message];
    [userNotification setIdentifier:[[NSUUID UUID] UUIDString]];
    [userNotification setSoundName:NSUserNotificationDefaultSoundName];
    if (image != nil)
    {
        [userNotification setContentImage:image];
    }
    
    NSUserNotificationCenter *defaultUserNotificationCenter = [NSUserNotificationCenter defaultUserNotificationCenter];
    [defaultUserNotificationCenter deliverNotification:userNotification];
}

- (void)dealloc 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    DRNotificationCenter *burnNotificationCenter = [DRNotificationCenter currentRunLoopCenter];
    [burnNotificationCenter removeObserver:self name:DRDeviceDisappearedNotification object:nil];
    [burnNotificationCenter removeObserver:self name:DRDeviceAppearedNotification object:nil];
    [burnNotificationCenter removeObserver:self name:DRDeviceStatusChangedNotification object:nil];
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    DRDevice *currentDevice = [KWCommonMethods getCurrentDevice];

    if ([[DRDevice devices] count] > 0)
    {
	    discInserted = ([[[currentDevice status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateMediaPresent]);
    }

    //Notifications
    DRNotificationCenter *burnNotificationCenter = [DRNotificationCenter currentRunLoopCenter];
    [burnNotificationCenter addObserver:self selector:@selector(mediaChanged:) name:DRDeviceDisappearedNotification object:nil];
    [burnNotificationCenter addObserver:self selector:@selector(mediaChanged:) name:DRDeviceAppearedNotification object:nil];
    [burnNotificationCenter addObserver:self selector:@selector(mediaChanged:) name:DRDeviceStatusChangedNotification object:nil];
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter addObserver:self selector:@selector(mediaChanged:) name:@"KWMediaChanged" object:nil];
    [defaultCenter addObserver:self selector:@selector(changeBurnStatus:) name:@"KWChangeBurnStatus" object:nil];
    [defaultCenter addObserver:self selector:@selector(closeWindow:) name:NSWindowWillCloseNotification object:nil];

    [defaultBurner setStringValue:[self getRecorderDisplayNameForDevice:currentDevice]];
    
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    if ([standardUserDefaults boolForKey:@"KWRememberLastTab"])
    [mainTabView selectTabViewItemWithIdentifier:[standardUserDefaults objectForKey:@"KWLastTab"]];

    [self setupToolbar];

    if ([standardUserDefaults boolForKey:@"KWFirstRun"])
    {
	    [self returnToDefaultSizeWindow:self];
	    [mainWindow setFrameOrigin:NSMakePoint(36,[[NSScreen mainScreen] frame].size.height - [mainWindow frame].size.height - 56)];
    }
    
    if (@available(macOS 11, *))
    {
        [mainWindow setTitleVisibility:NSWindowTitleHidden];
    }
}

/////////////////////////
// Main window actions //
/////////////////////////

#pragma mark -
#pragma mark •• Main window actions

- (IBAction)changeRecorder:(id)sender
{
    NSArray *devices = [DRDevice devices];
    
    if ([devices count] > 1)
    {
	    NSInteger x = 0;
        
	    for (NSInteger i = 0; i < [devices count]; i ++)
	    {
    	    if ([[[devices objectAtIndex:i] displayName] isEqualTo:[[[defaultBurner stringValue] componentsSeparatedByString:@"\n"] objectAtIndex:0]])
            {
	    	    x = i + 1;
            }
	    }
    	    
	    if (x > [devices count] - 1)
        {
    	    x = 0;
        }

	    NSMutableDictionary *burnDict = [NSMutableDictionary dictionary];
	    NSDictionary *deviceInfo = [[devices objectAtIndex:x] info];
    
	    [burnDict setObject:[deviceInfo objectForKey:@"DRDeviceProductNameKey"] forKey:@"Product"];
	    [burnDict setObject:[deviceInfo objectForKey:@"DRDeviceVendorNameKey"] forKey:@"Vendor"];
	    [burnDict setObject:@"" forKey:@"SerialNumber"];
    
	    [[NSUserDefaults standardUserDefaults] setObject:burnDict forKey:@"KWDefaultDeviceIdentifier"];
    
	    [[NSNotificationCenter defaultCenter] postNotificationName:@"KWMediaChanged" object:nil];
    }
}

- (IBAction)showItemHelp:(id)sender
{
    NSDictionary *bundleInfo = [[NSBundle bundleForClass:[self class]] infoDictionary];
    NSString *bundleIdent = [bundleInfo objectForKey:@"CFBundleIdentifier"];
    CFBundleRef mainBundle = CFBundleGetBundleWithIdentifier((CFStringRef)bundleIdent);
    
    if (mainBundle)
    {
	    CFURLRef bundleURL = NULL;
	    CFRetain(mainBundle);
	    bundleURL = CFBundleCopyBundleURL(mainBundle);
	    if (bundleURL)
	    {
            AHRegisterHelpBookWithURL(bundleURL);
    	    CFRelease(bundleURL);
	    }
	    
	    CFRelease(mainBundle);
    }
    
    CFBundleRef myApplicationBundle = CFBundleGetMainBundle();
    CFTypeRef myBookName = CFBundleGetValueForInfoDictionaryKey(myApplicationBundle,CFSTR("CFBundleHelpBookName"));
 
    if ([[itemHelp title] isEqualTo:[NSString stringWithFormat:NSLocalizedString(@"%@ Help", nil), NSLocalizedString(@"Data", nil)]])
	    AHLookupAnchor(myBookName, CFSTR("data"));
    else if ([[itemHelp title] isEqualTo:[NSString stringWithFormat:NSLocalizedString(@"%@ Help", nil), NSLocalizedString(@"Audio", nil)]])
	    AHLookupAnchor(myBookName, CFSTR("audio"));
    else if ([[itemHelp title] isEqualTo:[NSString stringWithFormat:NSLocalizedString(@"%@ Help", nil), NSLocalizedString(@"Video", nil)]])
	    AHLookupAnchor(myBookName, CFSTR("video"));
    else if ([[itemHelp title] isEqualTo:[NSString stringWithFormat:NSLocalizedString(@"%@ Help", nil), NSLocalizedString(@"Copy", nil)]])
	    AHLookupAnchor(myBookName, CFSTR("copy"));
}

- (IBAction)newTabViewAction:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type", nil]];
    [mainTabView selectTabViewItemAtIndex:[newTabView selectedSegment]];
}

//////////////////
// Menu actions //
//////////////////

#pragma mark -
#pragma mark •• Menu actions

//File menu

#pragma mark -
#pragma mark •• - File menu

- (IBAction)openFile:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:NO];

    NSMutableArray *fileTypes = [NSMutableArray array];

    [fileTypes addObject:@"burn"];
    [fileTypes addObjectsFromArray:[KWCommonMethods diskImageTypes]];

    [openPanel beginSheetModalForWindow:mainWindow completionHandler:^ (NSModalResponse response)
    {
        if (response == NSModalResponseOK)
        {
            [self open:[[openPanel URL] path]];
        }
    }];
}

//Recorder menu

#pragma mark -
#pragma mark •• - Recorder menu

- (IBAction)eraseRecorder:(id)sender
{
    eraser = [[KWEraser alloc] init];
    [eraser beginEraseSheetForWindow:mainWindow completion:^(NSDictionary *response)
    {
        NSString *returnCode = response[@"ReturnCode"];
        if ([returnCode isEqualTo:@"KWFailure"])
        {
            NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)];
            [self showNotificationWithTitle:NSLocalizedString(@"Erasing failed", nil) withMessage:NSLocalizedString(@"There was a problem erasing the disc", nil) withImage:image];
            
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
            [alert setMessageText:NSLocalizedString(@"Erasing failed", nil)];
            [alert setInformativeText:NSLocalizedString(@"There was a problem erasing the disc", nil)];
            [alert setAlertStyle:NSWarningAlertStyle];
        
            [alert beginSheetModalForWindow:self->mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
        }
        else
        {
            NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)];
            [self showNotificationWithTitle:NSLocalizedString(@"Finished erasing", nil) withMessage:NSLocalizedString(@"The disc has been succesfully erased", nil) withImage:image];
        }
    }];
}

- (IBAction)ejectRecorder:(id)sender
{
    if ([[DRDevice devices] count] > 1)
    {
	    if (ejecter == nil)
        {
    	    ejecter = [[KWEjecter alloc] init];
        }

	    [ejecter startEjectSheetForWindow:mainWindow forDevice:[KWCommonMethods getCurrentDevice]];
    }
    else
    {
        [[[DRDevice devices] objectAtIndex:0] ejectMedia];
    }
}

//Window menu

#pragma mark -
#pragma mark •• - Window menu

- (IBAction)returnToDefaultSizeWindow:(id)sender
{
    [mainWindow setFrame:NSMakeRect([mainWindow frame].origin.x , [mainWindow frame].origin.y - ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultWindowHeight"] intValue] - [mainWindow frame].size.height), [[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultWindowWidth"] intValue], [[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultWindowHeight"] intValue]) display:YES];
}

//////////////////////////
// Notification actions //
/////////////////////////

#pragma mark -
#pragma mark •• Notification actions

- (void)closeWindow:(NSNotification *)notification
{
    if ([notification object] == mainWindow)
    {
	    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
	    if ([defaults boolForKey:@"KWRememberLastTab"] == YES)
    	    [defaults setObject:[[mainTabView selectedTabViewItem] identifier] forKey:@"KWLastTab"];
    	    
	    [defaults synchronize];
    
	    [NSApp terminate:self];
    }
}

- (void)changeBurnStatus:(NSNotification *)notification
{
    [burnButton setEnabled:([[notification object] boolValue])];
    [defaultBurner setStringValue:[self getRecorderDisplayNameForDevice:[KWCommonMethods getCurrentDevice]]];
}

- (void)mediaChanged:(NSNotification *)notification
{
    [defaultBurner setStringValue:[self getRecorderDisplayNameForDevice:[KWCommonMethods getCurrentDevice]]];
    [[self changeRecorderButton] setEnabled:[[DRDevice devices] count] > 1];
}

/////////////////////
// Toolbar actions //
/////////////////////

#pragma mark -
#pragma mark •• Toolbar actions

// TODO: Rename, it's not a toolbar anymore
- (void)setupToolbar
{
    //First setup accessibility support since it can't be done from interface builder
    id segmentElement = NSAccessibilityUnignoredDescendant(newTabView);
    NSArray *segments = [segmentElement accessibilityAttributeValue:NSAccessibilityChildrenAttribute];


    id segment;
    NSArray *descriptions = [NSArray arrayWithObjects:NSLocalizedString(@"Select to create a data disc", nil),NSLocalizedString(@"Select to create a audio disc", nil),NSLocalizedString(@"Select to create a video disc", nil),NSLocalizedString(@"Select to copy a disc or disk image", nil), nil];
    NSEnumerator *e = [segments objectEnumerator];
    
    NSInteger i = 0;
    while ((segment = [e nextObject]))
    {
        [segment accessibilitySetOverrideValue:[descriptions objectAtIndex:i] forAttribute:NSAccessibilityHelpAttribute];
        [segment accessibilitySetOverrideValue:[descriptions objectAtIndex:i] forAttribute:NSAccessibilityHelpAttribute];
        i = i + 1;
    }
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    
    if ([itemIdentifier isEqualToString:@"Main"])
	    return mainItem;
    
    return item;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return [NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, @"Main", nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    return [NSArray arrayWithObjects:NSToolbarFlexibleSpaceItemIdentifier,@"Main",NSToolbarFlexibleSpaceItemIdentifier, nil];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (NSString *)getRecorderDisplayNameForDevice:(DRDevice *)device
{
    if (device)
    {
	    float space;
    
	    if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateMediaPresent])
	    {
    	    NSDictionary *mediaInfo = [[device status] objectForKey:DRDeviceMediaInfoKey];
	    
    	    if ([[mediaInfo objectForKey:DRDeviceMediaIsBlankKey] boolValue] || [[NSUserDefaults standardUserDefaults] boolForKey:@"KWShowOverwritableSpace"] == NO)
	    	    space = [[mediaInfo objectForKey:DRDeviceMediaFreeSpaceKey] floatValue] * 2048 / 1024 / 2;
    	    else if ([[mediaInfo objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassDVD])
	    	    space = [[mediaInfo objectForKey:DRDeviceMediaOverwritableSpaceKey] floatValue] * 2048 / 1024 / 2;
    	    else
	    	    space = [KWCommonMethods defaultSizeForMedia:@"KWDefaultCDMedia"];
	    }
	    else
	    {
    	    NSInteger media = [[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultMedia"] intValue];
	    
    	    if (media == 1)
	    	    space = [KWCommonMethods defaultSizeForMedia:@"KWDefaultCDMedia"];
    	    else if (media == 2)
	    	    space = [KWCommonMethods defaultSizeForMedia:@"KWDefaultDVDMedia"];
    	    else
	    	    space = -1;
	    }
	    
	    if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateInTransition] || space == -1)
	    {
    	    return [NSString stringWithFormat:@"%@\n%@", [device displayName], NSLocalizedString(@"No disc", nil)];
	    }
	    else
	    {
    	    NSString *percent;
    	    KWTabViewItem *tabViewItem = (KWTabViewItem *)[mainTabView selectedTabViewItem];
    	    id controller = [tabViewItem myController];
    	    float totalSize = [[controller performSelector:@selector(totalSize)] floatValue];
	    
    	    if (space > 0)
	    	    percent = [NSString stringWithFormat: @"(%.0f%@)", totalSize / space * 100, @"%"];
    	    else
	    	    percent = @"";
	    	    
    	    return [NSString stringWithFormat:@"%@\n%@ %@", [device displayName], [NSString stringWithFormat:NSLocalizedString(@"%@ free", nil), [KWCommonMethods makeSizeFromFloat:space * 2048]], percent];
	    }
    }
    else
    {
	    return NSLocalizedString(@"No Recorder", nil);
    }
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    [self open:filename];
    
    return YES;
}

- (void)open:(NSString *)pathname
{
    BOOL isDiscImage = [[KWCommonMethods diskImageTypes] containsObject:[[pathname pathExtension] lowercaseString]];
    BOOL isDiscVolume = [[[NSWorkspace sharedWorkspace] mountedLocalVolumePaths] containsObject:pathname];
    if (isDiscImage || isDiscVolume)
    {
	    [mainTabView selectTabViewItemWithIdentifier:@"Copy"];
        [[self discCopyController] checkImage:pathname];
    }
    else if ([[[pathname pathExtension] lowercaseString] isEqualTo:@"burn"])
    {
	    NSDictionary *burnFile = [NSDictionary dictionaryWithContentsOfFile:pathname];
	    
	    if (burnFile)
	    {
    	    [mainTabView selectTabViewItemAtIndex:[[burnFile objectForKey:@"KWType"] intValue]];
         
            KWTabViewItem *tabViewItem = (KWTabViewItem *)[mainTabView selectedTabViewItem];
            id controller = [tabViewItem myController];
            [controller openBurnDocument:pathname];
	    }
	    else 
	    {
            NSString *message = NSLocalizedString(@"Invalid Burn file", nil);
            NSString *information = NSLocalizedString(@"The Burn file is corrupt or a wrong filetype", nil);
    	    [KWCommonMethods standardAlertWithMessageText:message withInformationText:information withParentWindow:mainWindow];
	    }
    }
    else if ([[[pathname pathExtension] lowercaseString] isEqualTo:@"burntheme"])
    {
	    [[NSNotificationCenter defaultCenter] postNotificationName:@"KWDVDThemeOpened" object:[NSArray arrayWithObjects:pathname, nil]];
    }
    else
    {
	    [mainTabView selectTabViewItemWithIdentifier:@"Data"];
	    [[self dataController] addDroppedOnIconFiles:@[pathname]];
    }
}

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSInteger segment = [aTabView indexOfTabViewItem:[aTabView selectedTabViewItem]];
    [newTabView setSelectedSegment:segment];
    
    id controller = [(KWTabViewItem *)[aTabView selectedTabViewItem] myController];
    
    [itemHelp setTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ Help", nil), [newTabView labelForSegment:segment]]];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeBurnStatus" object:[NSNumber numberWithBool:([controller numberOfRows] > 0)]];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    if ([mainWindow attachedSheet] && aSelector != @selector(showItemHelp:))
	    return NO;

    return [super respondsToSelector:aSelector];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)theApplication
{
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    
    if ([standardDefaults boolForKey:@"KWFirstRun"] == YES)
	    [standardDefaults setObject:[NSNumber numberWithBool:NO] forKey:@"KWFirstRun"];
    return YES;
}

@end

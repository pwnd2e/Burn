//
//  KWDiscCreator.m
//  Burn
//
//  Created by Maarten Foukhar on 15-11-08.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWDiscCreator.h"
#import "KWDataController.h"
#import "KWAudioController.h"
#import "KWVideoController.h"
#import "KWCopyController.h"
#import "KWCommonMethods.h"
#import "KWTrackProducer.h"
#import "KWSVCDImager.h"
#import <DiscRecording/DiscRecording.h>
#import "KWBurner.h"
#import "KWProgressManager.h"
#import "KWDRFolder.h"
#import "KWWindowController.h"
#import "KWConstants.h"

@interface KWBurner(Private)

- (IBAction)combineSessions:(id)sender;
- (void)prepareTypes;
- (void)setCombineBox:(id)box;

@end

@interface KWDiscCreator()

@property (nonatomic, weak) IBOutlet NSWindow *mainWindow;
@property (nonatomic, weak) IBOutlet NSTabView *mainTabView;
// TODO: Find a better way to set the notification delegate and send a notification
@property (nonatomic, weak) IBOutlet KWWindowController *windowController;

// Controllers
@property (nonatomic, weak) IBOutlet KWDataController *dataController;
@property (nonatomic, weak) IBOutlet KWAudioController *audioController;
@property (nonatomic, weak) IBOutlet KWVideoController *videoController;
@property (nonatomic, weak) IBOutlet KWCopyController *discCopyController; // copyController is not allowed

// Sessions
@property (nonatomic, weak) IBOutlet NSButton *saveCombineSessions;
@property (nonatomic, weak) IBOutlet NSImageView *saveImageView;

// Variables
@property (nonatomic, strong) KWBurner *burner;
@property (nonatomic, getter = isBurning) BOOL burning;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *fileSystem;
@property (nonatomic, strong) NSDictionary *theme;
@property (nonatomic, copy) NSString *discName;
@property (nonatomic, copy) NSString *imagePath;
@property (nonatomic, getter = shouldHideExtension) BOOL hiddenExtension;
@property (nonatomic, strong) NSMutableArray *extensionHiddenArray;
@property (nonatomic, copy) NSString *errorString;
@property (nonatomic) BOOL shouldWait;

@end

@implementation KWDiscCreator

#pragma mark - Sessions Methods

- (IBAction)saveCombineSessions:(id)sender
{
    [[self burner] combineSessions:sender];
}

#pragma mark - Image Methods

- (void)saveImageWithName:(NSString *)name withType:(NSInteger)type withFileSystem:(NSString *)fileSystem
{
    NSString *extension;
    NSArray *info;
    [self setName:name];
    [self setFileSystem:fileSystem];
    
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    NSBundle *themeBundle = [NSBundle bundleWithPath:[self currentThemePath]];
    NSString *themePropertyListFile = [themeBundle pathForResource:@"Theme" ofType:@"plist"];
    NSArray *themeArray = [NSArray arrayWithContentsOfFile:themePropertyListFile];
    NSInteger formatIndex = [[standardDefaults objectForKey:@"KWDVDThemeFormat"] intValue];
    NSDictionary *theme = themeArray[formatIndex];
    [self setTheme:theme];
    
    if ([fileSystem isEqualTo:@"-vcd"] || [fileSystem isEqualTo:@"-svcd"] || [fileSystem isEqualTo:@"-audio-cd"])
    {
	    extension = @"cue";
    }
    else
    {
	    extension = @"iso";
    }

    //Setup save sheet
    NSSavePanel *sheet = [NSSavePanel savePanel];
    [sheet setMessage:NSLocalizedString(@"Choose a location to save the image file", nil)];
    [sheet setAllowedFileTypes:@[extension]];
    [sheet setCanSelectHiddenExtension:YES];
    [sheet setNameFieldStringValue:name];
    
    NSButton *saveCombineSessions = [self saveCombineSessions];
    [saveCombineSessions setState:NSOffState];

    if (type < 4)
    {
	    //Setup image burner
	    KWBurner *burner = [[KWBurner alloc] init];
	    [burner setType:type];
    
	    //Setup combining options
	    NSArray *types = [self getCombinableFormats:YES];

	    if ([types count] > 1 && [types containsObject:@(type)])
	    {
    	    [burner setCombinableTypes:types];
    	    [burner prepareTypes];
    	    [burner setCombineBox:saveCombineSessions];
    	    [sheet setAccessoryView:[self saveImageView]];
	    }
     
        [self setBurner:burner];
    
	    info = @[name];
    }
    else
    {
	    info = @[name, fileSystem];
    }
    
    //Show save sheet
    NSWindow *mainWindow = [self mainWindow];
    [sheet beginSheetModalForWindow:mainWindow completionHandler:^(NSModalResponse result)
    {
         if (result == NSModalResponseOK)
        {
            NSURL *imageURL = [sheet URL];
            
            KWProgressManager *progressManager = [KWProgressManager sharedManager];
            [progressManager setTask:NSLocalizedString(@"Creating image file", nil)];
            [progressManager setStatus:NSLocalizedString(@"Preparing...", nil)];
            [progressManager setIconImage:[[NSWorkspace sharedWorkspace] iconForFileType:[imageURL pathExtension]]];
            [progressManager setMaximumValue:0.0];
            [progressManager beginSheetForWindow:mainWindow];
            [self setImagePath:[imageURL path]];
            
            if ([info count] == 1)
            {
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageFinished:) name:@"KWBurnFinished" object:[self burner]];
                [self setHiddenExtension:[sheet isExtensionHidden]];
                [self burnTracks:[self theme]];
            }
            else
            {
               [self createImageAtPath:[imageURL path] hideExtension:[sheet isExtensionHidden]];
            }
        }
    }];
}

- (void)createImageAtPath:(NSString *)path hideExtension:(BOOL)hideExtension
{
    [[[NSOperationQueue alloc] init] addOperationWithBlock:^
    {
        NSInteger success = 0;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageFinished:) name:@"KWBurnFinished" object:[self burner]];
        
        KWSVCDImager *SVCDImager = [[KWSVCDImager alloc] init];
        NSString *anErrorString;
        success = [SVCDImager createSVCDImage:[path stringByDeletingPathExtension] withFiles:[[self videoController] files] withLabel:[self name] createVCD:[[self fileSystem] isEqualTo:@"-vcd"] hideExtension:@(hideExtension) errorString:&anErrorString];
        [self setErrorString:anErrorString];
        
        if (success == 0)
        {
            [self imageFinished:@"KWSuccess"];
        }
        else if (success == 1)
        {
            [self imageFinished:@"KWFailure"];
        }
        else
        {
            [self imageFinished:@"KWCanceled"];
        }
    }];
}

- (void)showAuthorFailedOfType:(NSInteger)type
{    
    [[KWProgressManager sharedManager] endSheetWithCompletion:^
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
        
        if (type == 0)
            [alert setMessageText:NSLocalizedString(@"Failed to create temporary folder", nil)];
        else
            [alert setMessageText:NSLocalizedString(@"Authoring failed", nil)];
        
        if (type < 3)
            [alert setInformativeText:NSLocalizedString(@"There was a problem authoring the DVD", nil)];
        else
            [alert setInformativeText:NSLocalizedString(@"There was a problem copying the disc", nil)];
        
        NSString *errorString = [self errorString];
        if (errorString != nil)
        {
            if ([errorString rangeOfString:@"KWConsole:"].length ==  0)
            {
                [alert setInformativeText:[self errorString]];
            }
        }
        
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[self mainWindow] modalDelegate:self didEndSelector:nil contextInfo:nil];
    }];
}

- (void)imageFinished:(id)object
{
    NSMutableArray *extensionHiddenArray = [self extensionHiddenArray];
    if (extensionHiddenArray)
    {
        // TODO: change something, do at least not use a dictionary since they're pretty prone to errors
	    for (NSDictionary *hideFileExtensionInfo in extensionHiddenArray)
	    {
            NSNumber *hideFileExtension = hideFileExtensionInfo[@"Extension Hidden"];
            NSString *path = hideFileExtensionInfo[@"Path"];
    	    [[NSFileManager defaultManager] setAttributes:@{NSFileExtensionHidden: hideFileExtension} ofItemAtPath:path error:nil];
        }
	    
	    [self setExtensionHiddenArray:nil];
    }

    NSString *returnCode;
    if ([object superclass] == [NSNotification class])
	    returnCode = [[object userInfo] objectForKey:@"ReturnCode"];
    else
	    returnCode = object;

    if (![self isBurning] || [returnCode isEqualTo:@"KWCanceled"])
    {
	    [[KWProgressManager sharedManager] endSheet];
    }
    
    KWBurner *burner = [self burner];
    
    if ([returnCode isEqualTo:@"KWSuccess"])
    {
        NSString *imagePath = [self imagePath];
	    if ([[imagePath pathExtension] isEqualTo:@"cue"] && burner)
        {
    	    [KWCommonMethods writeString:[[self audioController] cueStringWithBinFile:[[[imagePath lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"bin"]] toFile:imagePath errorString:nil];
        }
        
        // TODO: why???
        [[NSOperationQueue mainQueue] addOperationWithBlock:^
        {
            if ([[[[self mainTabView] selectedTabViewItem] identifier] isEqualTo:@"Copy"])
            {
                KWCopyController *copyControllerOutlet = [self discCopyController];
                [copyControllerOutlet remount:nil];
            
                NSDictionary *infoDict = [copyControllerOutlet isoInfo];
                
                if (infoDict)
                {
                    [infoDict writeToFile:[[imagePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"isoInfo"] atomically:YES];
                }
            }
        }];
	    
        NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType:@".iso"];
        [[self windowController] showNotificationWithTitle:NSLocalizedString(@"Image created", nil) withMessage:NSLocalizedString(@"Succesfully created a disk image", nil) withImage:image];
    }
    else if ([returnCode isEqualTo:@"KWFailure"])
    {
        NSString *imagePath = [self imagePath];
	    if (burner)
        {
    	    [KWCommonMethods removeItemAtPath:imagePath];
        }
        
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Failed to create '%@'", nil), [[NSFileManager defaultManager] displayNameAtPath:imagePath]];
        NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType:@".iso"];
        [[self windowController] showNotificationWithTitle:NSLocalizedString(@"Image failed", nil) withMessage:message withImage:image];
        
        [[KWProgressManager sharedManager] endSheetWithCompletion:^
        {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
            [alert setMessageText:NSLocalizedString(@"Image failed", nil)];
            [alert setAlertStyle:NSWarningAlertStyle];
            
            // TODO: why can be empty
            if (burner && [object userInfo][@"Error"])
            {
                [alert setInformativeText:[[object userInfo] objectForKey:@"Error"]];
            }
            else
            {
                [alert setInformativeText:NSLocalizedString(@"There was a problem creating the image", nil)];
            }
        
            NSString *errorString = [self errorString];
            if ([errorString rangeOfString:@"KWConsole:"].length == 0)
            {
                [alert setInformativeText:errorString == nil ? NSLocalizedString(@"There was a problem creating the image", nil) : errorString];
            }
            
            [alert beginSheetModalForWindow:[self mainWindow] modalDelegate:self didEndSelector:nil contextInfo:nil];
        }];
    }
    else if ([returnCode isEqualTo:@"KWCanceled"])
    {
	    if (burner)
        {
    	    [KWCommonMethods removeItemAtPath:[self imagePath]];
        }
    }
    
    if (burner)
    {
	    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"KWBurnFinished" object:burner];
    }
    else
    {
	    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"KWImagerFinished" object:nil];
    }

    [self setImagePath:nil];
    
    // TODO: Since it's always yes, just delete files when needed
    [[self dataController] deleteTemporayFiles:YES];
    // TODO: make it a protocol???
//    [[self audioControllerOutlet] deleteTemporayFiles:YES];
//    [[self videoControllerOutlet] deleteTemporayFiles:YES];
    [[self discCopyController] deleteTemporayFiles:YES];
}

#pragma mark - Burn Methods

- (void)burnDiscWithName:(NSString *)name withType:(NSInteger)type
{
    KWBurner *burner = [[KWBurner alloc] init];
    [self setBurner:burner];
    
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    NSBundle *themeBundle = [NSBundle bundleWithPath:[self currentThemePath]];
    NSDictionary *theme = [[NSArray arrayWithContentsOfFile:[themeBundle pathForResource:@"Theme" ofType:@"plist"]] objectAtIndex:[[standardDefaults objectForKey:@"KWDVDThemeFormat"] intValue]];
    [self setTheme:theme];
    [self setName:name];
    
    NSWindow *mainWindow = [self mainWindow];

    //Check if the user wants to copy the disc in the burning device
    KWCopyController *copyControllerOutlet = [self discCopyController];
    [burner setIgnoreModeEnabled:(type == 3 && [[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] && [[copyControllerOutlet myDisc] isEqualTo:[@"/dev/" stringByAppendingString:[[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaBSDNameKey]]])];

    [burner setType:type];
    [burner setCombinableTypes:[self getCombinableFormats:NO]];
    [burner beginBurnSetupSheetForWindow:mainWindow completion:^(NSModalResponse returnCode)
    {
        if (returnCode == NSModalResponseOK)
        {
            NSTabView *mainTabView = [self mainTabView];
            if ((([copyControllerOutlet isCueFile] || ([copyControllerOutlet isAudioCD] && [[[mainTabView selectedTabViewItem] identifier] isEqualTo:@"Copy"])) || ([[self audioController] isAudioCD] && [[[mainTabView selectedTabViewItem] identifier] isEqualTo:@"Audio"])) && ![burner isCD])
            {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
                [alert setMessageText:NSLocalizedString(@"No CD", nil)];
                [alert setAlertStyle:NSWarningAlertStyle];
                
                if ([copyControllerOutlet isCueFile])
                {
                    [alert setInformativeText:NSLocalizedString(@"A cue/bin file needs to be burned on a CD", nil)];
                }
                else
                {
                    [alert setInformativeText:NSLocalizedString(@"To burn a Audio-CD the media should be a CD", nil)];
                }
            
                [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
            }
            else
            {
                KWProgressManager *progressManager = [KWProgressManager sharedManager];
                [progressManager setIconImage:[NSImage imageNamed:@"Burn"]];
                [progressManager setTask:[NSString stringWithFormat:NSLocalizedString(@"Burning '%@'", nil), [self name]]];
                [progressManager setStatus:NSLocalizedString(@"Preparing...", nil)];
                [progressManager setMaximumValue:0.0];
                [progressManager beginSheetForWindow:mainWindow];
                
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(burnFinished:) name:@"KWBurnFinished" object:burner];
                
                [self burnTracks:[self theme]];
            }
        }
    }];
}

// TODO: find a better way to pass the theme and make this method shorter please!
- (void)burnTracks:(NSDictionary *)theme
{
    [[[NSOperationQueue alloc] init] addOperationWithBlock:^
    {
        NSMutableArray *tracks = [NSMutableArray array];
        NSInteger result = 0;
        BOOL maskSet = NO;
        NSNumber *layerBreak = nil;

        DRFolder *rootFolder = [[DRFolder alloc] initWithName:[self name]];
        [rootFolder setExplicitFilesystemMask:0];
    
        KWBurner *burner = [self burner];
        if ([[burner types] containsObject:@(1)])
        {
            NSString *anErrorString;
            id audioTracks = [[self audioController] myTrackWithBurner:burner errorString:&anErrorString];
            [self setErrorString:anErrorString];
            
            if (audioTracks)
            {
                if ([audioTracks isKindOfClass:[DRFSObject class]])
                {
                    [rootFolder setExplicitFilesystemMask:([audioTracks explicitFilesystemMask])];
                    maskSet = YES;
                    
                    if ([audioTracks isVirtual])
                    {
                        for (DRFSObject *child in [audioTracks children])
                        {
                            [rootFolder addChild:[self newDRFSObject:child]];
                        }
                    }
                    else
                    {
                        [rootFolder addChild:[self newDRFSObject:audioTracks]];
                    }
                }
                else if ([audioTracks isKindOfClass:[NSNumber class]])
                {
                    result = [audioTracks intValue];
                }
                else if ([audioTracks isKindOfClass:[NSArray class]])
                {
                    [tracks addObjectsFromArray:audioTracks];
                }
                else
                {
                    [tracks addObject:audioTracks];
                }
            }
        }
        
        if ([[burner types] containsObject:@(2)] && result == 0)
        {
            NSString *anErrorString;
            id videoTracks = [[self videoController] myTrackWithBurner:burner theme:[self theme] errorString:&anErrorString];
            [self setErrorString:anErrorString];

            if (videoTracks)
            {
                if ([videoTracks isKindOfClass:[DRFSObject class]])
                {
                    if (maskSet)
                    {
                        [rootFolder setExplicitFilesystemMask:([rootFolder explicitFilesystemMask] || [videoTracks explicitFilesystemMask])];
                    }
                    else
                    {
                        [rootFolder setExplicitFilesystemMask:([videoTracks explicitFilesystemMask])];
                        maskSet = YES;
                    }
                    
                    if ([videoTracks isVirtual])
                    {
                        for (DRFSObject *child in [videoTracks children])
                        {
                            [rootFolder addChild:[self newDRFSObject:child]];
                        }
                    }
                    else
                    {
                        [rootFolder addChild:[self newDRFSObject:videoTracks]];
                    }
                }
                else if ([videoTracks isKindOfClass:[NSNumber class]])
                {
                    result = [videoTracks intValue];
                }
                else if ([videoTracks isKindOfClass:[NSArray class]])
                {
                    [tracks addObjectsFromArray:videoTracks];
                }
                else
                {
                    [tracks addObject:videoTracks];
                }
            }
        }

        if ([[burner types] containsObject:@(0)] && result == 0)
        {
            NSString *anErrorString;
            id dataTracks = [[self dataController]
            
             myTrackWithErrorString:&anErrorString];
            [self setErrorString:anErrorString];
        
            if ([dataTracks isKindOfClass:[DRFSObject class]])
            {
                if (maskSet)
                {
                    [rootFolder setExplicitFilesystemMask:([rootFolder explicitFilesystemMask] || [dataTracks explicitFilesystemMask])];
                }
                else
                {
                    [rootFolder setExplicitFilesystemMask:([dataTracks explicitFilesystemMask])];
                    maskSet = YES;
                }
                
                if ([dataTracks isVirtual])
                {
                    if ([KWCommonMethods fsObjectContainsHFS:dataTracks])
                    {
                        [self setExtensionHiddenArray:[[NSMutableArray alloc] init]];
                    }
                
                    for (DRFSObject *child in [dataTracks children])
                    {
                        if ([[child baseName] isEqualTo:@".VolumeIcon.icns"])
                        {
                            [rootFolder setProperty:[NSNumber numberWithUnsignedShort:1024] forKey:DRMacFinderFlags inFilesystem:DRHFSPlus];
                        }
                    
                        [rootFolder addChild:[self newDRFSObject:child]];
                    }
                }
                else
                {
                    [rootFolder addChild:[self newDRFSObject:dataTracks]];
                }
            }
            else if ([dataTracks isKindOfClass:[NSNumber class]])
            {
                result = [dataTracks intValue];
            }
            else if ([dataTracks isKindOfClass:[NSArray class]])
            {
                [tracks addObjectsFromArray:dataTracks];
            }
            else
            {
                [tracks addObject:dataTracks];
            }
        }
        
        if ([[burner types] containsObject:@(3)] && result == 0)
        {
            NSString *anErrorString;
            id copyTracks = [[self discCopyController] myTrackWithErrorString:&anErrorString andLayerBreak:&layerBreak];
            [self setErrorString:anErrorString];
        
            if ([copyTracks isKindOfClass:[NSNumber class]])
            {
                result = [copyTracks intValue];
            }
            else if ([copyTracks isKindOfClass:[NSArray class]])
            {
                [tracks addObjectsFromArray:copyTracks];
            }
            else
            {
                [tracks addObject:copyTracks];
            }
        }

        if (result == 0)
        {
            if (maskSet)
                [tracks addObject:[DRTrack trackForRootFolder:rootFolder]];

            NSString *imagePath = [self imagePath];
            if (imagePath)
            {
                KWProgressManager *progressManager = [KWProgressManager sharedManager];
                [progressManager setMaximumValue:0.0];
                [progressManager setTask:[NSString stringWithFormat:NSLocalizedString(@"Creating image file '%@'", nil), [[NSFileManager defaultManager] displayNameAtPath:imagePath]]];
                [progressManager setStatus:NSLocalizedString(@"Preparing...", nil)];
                
                NSString *anErrorString;
                if ([KWCommonMethods createFileAtPath:imagePath attributes:@{NSFileExtensionHidden: @([self shouldHideExtension])} errorString:&anErrorString])
                {
                    NSDictionary *options = @{@"Path": imagePath, @"Track": tracks};
                    [burner performSelectorOnMainThread:@selector(burnTrackToImage:) withObject:options waitUntilDone:YES];
                }
                else
                {
                    burner = nil;
                    [self performSelectorOnMainThread:@selector(imageFinished:) withObject:@"KWFailure" waitUntilDone:YES];
                }
                [self setErrorString:anErrorString];
            }
            else
            {
                KWProgressManager *progressManager = [KWProgressManager sharedManager];
                [progressManager setMaximumValue:0.0];
                [progressManager setCancelHandler:^
                {
                    [self stopWaiting];
                }];
                
                [self setShouldWait:YES];

                
            
                if ([self waitForMediaIfNeeded] == YES)
                {
                    KWProgressManager *progressManager = [KWProgressManager sharedManager];
                    [progressManager setCancelHandler:nil];
                    [progressManager setTask:[NSString stringWithFormat:NSLocalizedString(@"Burning '%@'", nil), [self name]]];
                    [progressManager setStatus:NSLocalizedString(@"Preparing...", nil)];
                    [burner performSelectorOnMainThread:@selector(setLayerBreak:) withObject:layerBreak waitUntilDone:YES];
                    [burner performSelectorOnMainThread:@selector(burnTrack:) withObject:tracks waitUntilDone:YES];
                }
                else
                {
                    [[KWProgressManager sharedManager] endSheet];
                }
            
                [[NSNotificationCenter defaultCenter] removeObserver:self name:@"KWStopWaiting" object:nil];
            
                [self setShouldWait:NO];
            }
        }
        else if (result == 1)
        {
            [self showAuthorFailedOfType:[burner type]];
        }
        else
        {
            [[KWProgressManager sharedManager] endSheet];
            [self setImagePath:nil];
        }
    }];
}

- (void)burnFinished:(NSNotification*)notif
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"KWDoneBurning" object:nil];
    
    NSMutableArray *extensionHiddenArray = [self extensionHiddenArray];
    if (extensionHiddenArray)
    {
	    // TODO: change something, do at least not use a dictionary since they're pretty prone to errors
        for (NSDictionary *hideFileExtensionInfo in extensionHiddenArray)
        {
            NSNumber *hideFileExtension = hideFileExtensionInfo[@"Extension Hidden"];
            NSString *path = hideFileExtensionInfo[@"Path"];
            [[NSFileManager defaultManager] setAttributes:@{NSFileExtensionHidden: hideFileExtension} ofItemAtPath:path error:nil];
        }
	    [self setExtensionHiddenArray:nil];
    }

    [self setBurning:NO];

    NSString *returnCode = [[notif userInfo] objectForKey:@"ReturnCode"];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"KWBurnFinished" object:[self burner]];
    
    if ([returnCode isEqualTo:@"KWSuccess"])
    {
        [[KWProgressManager sharedManager] endSheet];
        
        NSString *messageName = [NSString stringWithFormat:NSLocalizedString(@"'%@' was burned succesfully", nil), [self name]];
        NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)];
        [[self windowController] showNotificationWithTitle:NSLocalizedString(@"Finished burning", nil) withMessage:messageName withImage:image];
    }
    else if ([returnCode isEqualTo:@"KWFailure"])
    {
        NSString *messageName = [NSString stringWithFormat:NSLocalizedString(@"Failed to burn '%@'", nil), [self name]];
        NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)];
        [[self windowController] showNotificationWithTitle:NSLocalizedString(@"Burning failed", nil) withMessage:messageName withImage:image];
     
        [[KWProgressManager sharedManager] endSheetWithCompletion:^
        {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
            [alert setMessageText:NSLocalizedString(@"Burning failed", nil)];
            [alert setInformativeText:[[notif userInfo] objectForKey:@"Error"]];
            [alert setAlertStyle:NSWarningAlertStyle];
        
            [alert beginSheetModalForWindow:[self mainWindow] modalDelegate:self didEndSelector:nil contextInfo:nil];
        }];
    }
    else
    {
        [[KWProgressManager sharedManager] endSheet];
    }
    
    // TODO: Since it's always yes, just delete files when needed
    [[self dataController] deleteTemporayFiles:YES];
    [[self audioController] deleteTemporayFiles:YES];
    [[self videoController] deleteTemporayFiles:YES];
    [[self discCopyController] deleteTemporayFiles:YES];
}

#pragma mark - Convenient Methods

- (NSArray *)getCombinableFormats:(BOOL)needAudioCDCheck
{
    NSMutableArray *formats = [NSMutableArray array];
    
    KWDataController *dataControllerOutlet = [self dataController];
    KWAudioController *audioControllerOutlet = [self audioController];
    KWVideoController *videoControllerOutlet = [self videoController];

    if ([dataControllerOutlet isCombinable] && ([dataControllerOutlet isOnlyHFSPlus] || (![audioControllerOutlet isAudioCD] || needAudioCDCheck)))
    {
	    [formats addObject:@(0)];
    }
    
    if ([audioControllerOutlet isCombinable])
    {
	    [formats addObject:@(1)];
    }
    
    if ([videoControllerOutlet isCombinable] && (![audioControllerOutlet isAudioCD] || needAudioCDCheck))
    {
	    [formats addObject:@(2)];
    }

    return formats;
}

- (DRFSObject *)newDRFSObject:(DRFSObject *)object
{
    DRFSObject *newObject;
	    
    if ([object isVirtual])
    {
        newObject = [DRFolder virtualFolderWithName:[object baseName]];
    
        for (DRFSObject *child in [(DRFolder *)object children])
        {
            [(DRFolder *)newObject addChild:[self newDRFSObject:child]];
        }
    }
    else
    {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[object sourcePath] error:nil];
        NSNumber *isExtensionHiddenNumber = attributes[NSFileExtensionHidden];
        
        [object setProperty:[isExtensionHiddenNumber boolValue] ? @(0x0010) : @(0) forKey:DRMacFinderFlags inFilesystem:DRHFSPlus];
 
        BOOL isDir;
        [[NSFileManager defaultManager] fileExistsAtPath:[object sourcePath] isDirectory:&isDir];
    
        if (isDir)
        {
            newObject = [DRFolder folderWithPath:[object sourcePath]];
        }
        else
        {
            NSMutableArray *extensionHiddenArray = [self extensionHiddenArray];
            if (extensionHiddenArray)
            {
                // TODO: make it into an object instead of a dictionary
                [extensionHiddenArray addObject:@{@"Path": [object sourcePath], @"Extension Hidden": isExtensionHiddenNumber}];
            }
            
            newObject = [DRFile fileWithPath:[object sourcePath]];
        }
        
        [newObject setBaseName:[object baseName]];
    }
	    
    [newObject setExplicitFilesystemMask:[object explicitFilesystemMask]];
    
    NSString *name = [object specificNameForFilesystem:DRHFSPlus];
    if (name != nil)
    {
        [newObject setSpecificName:name forFilesystem:DRHFSPlus];
    }
    name = [object specificNameForFilesystem:DRISO9660];
    if (name != nil)
    {
        [newObject setSpecificName:name forFilesystem:DRISO9660];
    }
    name = [object specificNameForFilesystem:DRJoliet];
    if (name != nil)
    {
        [newObject setSpecificName:name forFilesystem:DRJoliet];
    }
    name = [object specificNameForFilesystem:DRUDF];
    if (name != nil)
    {
        [newObject setSpecificName:name forFilesystem:DRUDF];
    }
    
    NSDictionary *properties = [object propertiesForFilesystem:DRHFSPlus mergeWithOtherFilesystems:NO];
    if (properties != nil)
    {
        [newObject setProperties:properties inFilesystem:DRHFSPlus];
    }
    properties = [object propertiesForFilesystem:DRISO9660 mergeWithOtherFilesystems:NO];
    if (properties != nil)
    {
        [newObject setProperties:properties inFilesystem:DRISO9660];
    }
    properties = [object propertiesForFilesystem:DRJoliet mergeWithOtherFilesystems:NO];
    if (properties != nil)
    {
        [newObject setProperties:properties inFilesystem:DRJoliet];
    }
    properties = [object propertiesForFilesystem:DRUDF mergeWithOtherFilesystems:NO];
    if (properties != nil)
    {
        [newObject setProperties:properties inFilesystem:DRUDF];
    }

    return newObject;
}

- (BOOL)waitForMediaIfNeeded
{
    BOOL correctMedia = ![[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateNone];

    BOOL shouldWait = [self shouldWait];
    while (correctMedia == NO && shouldWait == YES)
    {
	    if ([[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateMediaPresent])
	    {
            // TODO: is a bit too long :P
    	    if ([[[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsBlankKey] boolValue] || [[[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsAppendableKey] boolValue] || ([[[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsOverwritableKey] boolValue] && [[[[self burner] properties] objectForKey:DRBurnOverwriteDiscKey] boolValue]))
            {
                return YES;
            }
    	    else
            {
	    	    [[KWCommonMethods savedDevice] ejectMedia];
            }
	    }
	    else if ([[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateInTransition])
	    {
    	    [[KWProgressManager sharedManager] setStatus:NSLocalizedString(@"Waiting for the drive...", nil)];
	    }
	    else if ([[[[KWCommonMethods savedDevice] status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateNone])
	    {
    	    [[KWProgressManager sharedManager] setStatus:NSLocalizedString(@"Waiting for a disc to be inserted...", nil)];
	    }
    }
    
    if (shouldWait == NO)
	    return NO;
    
    return YES;
}

- (void)stopWaiting
{
    [self setShouldWait:NO];
}

- (NSString *)currentThemePath
{
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    NSString *themePath = [standardDefaults objectForKey:@"KWDVDThemePath"];
    NSString *themeName = [standardDefaults stringForKey:KWDVDThemeName];
    if (themePath != nil)
    {
        NSString *possibleThemeName = [[themePath lastPathComponent] stringByDeletingPathExtension];
        if (![possibleThemeName isEqualToString:@"Seperator"])
        {
            themeName = possibleThemeName;
            [standardDefaults setObject:themeName forKey:KWDVDThemeName];
        }
        [standardDefaults removeObjectForKey:@"KWDVDThemePath"];
    }
    
    NSInteger selectedThemeIndex = [standardDefaults integerForKey:KWDVDTheme];
    NSString *themesPath = selectedThemeIndex < 3 ? [[NSBundle mainBundle] pathForResource:@"Themes" ofType:nil] : [@"~/Library/Application Support/Burn/Themes" stringByExpandingTildeInPath];
    NSString *currentThemePath = [[themesPath stringByAppendingPathComponent:themeName] stringByAppendingPathExtension:@"burnTheme"];

    if (![[NSFileManager defaultManager] fileExistsAtPath:currentThemePath])
    {
        currentThemePath = [themesPath stringByAppendingPathComponent:@"Default.burnTheme"];
        [standardDefaults setObject:@"Default" forKey:KWDVDThemeName];
    }

    return currentThemePath;
}

@end

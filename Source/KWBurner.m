#import "KWBurner.h"
#import "KWTrackProducer.h"
#import "KWProgressManager.h"
#import <DiscRecording/DiscRecording.h>
#import "KWCommonMethods.h"

@interface DRCallbackDevice : DRDevice
- (void)initWithConsumer:(id)consumer;
@end

@interface KWBurner()

//Main Sheet outlets
@property (nonatomic, weak) IBOutlet NSButton *burnButton;
@property (nonatomic, weak) IBOutlet NSPopUpButton *burnerPopup;
@property (nonatomic, weak) IBOutlet NSButton *closeButton;
@property (nonatomic, weak) IBOutlet NSButton *eraseCheckBox;
@property (nonatomic, weak) IBOutlet NSButton *sessionsCheckBox;
@property (nonatomic, weak) IBOutlet NSPopUpButton *speedPopup;
@property (nonatomic, weak) IBOutlet NSTextField *statusText;
@property (nonatomic, weak) IBOutlet NSButton *combineCheckBox;
@property (nonatomic, weak) IBOutlet NSTextField *numberOfCopiesText;
@property (nonatomic, weak) IBOutlet NSBox *numberOfCopiesBox;

//Session Panel Outlets
@property (nonatomic, weak) IBOutlet NSPanel *sessionsPanel;
@property (nonatomic, weak) IBOutlet NSMatrix *sessions;
@property (nonatomic, weak) IBOutlet NSButton *dataSession;
@property (nonatomic, weak) IBOutlet NSButton *audioSession;
@property (nonatomic, weak) IBOutlet NSButton *videoSession;

//Variables
@property (nonatomic, weak) NSButton *currentCombineCheckBox;

@property (nonatomic) NSInteger size;
@property (nonatomic) NSInteger trackNumber; //Must delete

@property (nonatomic) BOOL shouldClose;
@property (nonatomic, getter = didUserCancel) BOOL userCanceled;
@property (nonatomic, getter = isOverwritable) BOOL overwritable;

@property (nonatomic, strong) DRBurn *burn;
@property (nonatomic, strong) DRDevice *savedDevice;
@property (nonatomic, copy) NSString *imagePath;
@property (nonatomic, strong) NSNumber *layerBreak;

@end

@implementation KWBurner

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        [[NSBundle mainBundle] loadNibNamed:@"KWBurner" owner:self topLevelObjects:nil];
    }

    return self;
}

#pragma mark - Main Methods

- (void)beginBurnSetupSheetForWindow:(NSWindow *)window completion:(void (^)(NSModalResponse returnCode))completion
{
    NSWindow *myWindow = [self window];
    
    NSPopUpButton *burnerPopup = [self burnerPopup];
    [burnerPopup removeAllItems];

    NSInteger i;
    for (i=0;i< [[DRDevice devices] count];i++)
    {
	    NSString *displayName = [[[DRDevice devices] objectAtIndex:i] displayName];
	    [burnerPopup addItemWithTitle:displayName];
    }
    
    NSString *displayName = [[self savedDevice] displayName];
    if ([burnerPopup indexOfItemWithTitle:displayName] > -1)
	    [burnerPopup selectItemAtIndex:[burnerPopup indexOfItemWithTitle:displayName]];
    
    [self updateDevice:[self currentDevice]];

    NSInteger height = 205;
    
    NSArray *combinableTypes = [self combinableTypes];
    NSInteger type = [self type];
    NSButton *combineCheckBox = [self combineCheckBox];
    if (type < 3 && [combinableTypes count] > 1 && [combinableTypes containsObject:@(type)])
    {
	    [self prepareTypes];
	    [combineCheckBox setHidden:NO];
    }
    else
    {
	    height = height - 20;
	    [combineCheckBox setHidden:YES];
    }
    
    [myWindow setContentSize:NSMakeSize([myWindow frame].size.width, height)];
    
    DRNotificationCenter *currentCenter = [DRNotificationCenter currentRunLoopCenter];
    [currentCenter addObserver:self selector:@selector(statusChanged:) name:DRDeviceStatusChangedNotification object:nil];
    [currentCenter addObserver:self selector:@selector(mediaChanged:) name:DRDeviceDisappearedNotification object:nil];
    [currentCenter addObserver:self selector:@selector(mediaChanged:) name:DRDeviceAppearedNotification object:nil];
    
    [window beginSheet:myWindow completionHandler:^(NSModalResponse returnCode)
    {
        DRNotificationCenter *currentCenter = [DRNotificationCenter currentRunLoopCenter];
        [currentCenter removeObserver:self name:DRDeviceStatusChangedNotification object:nil];
        [currentCenter removeObserver:self name:DRDeviceDisappearedNotification object:nil];
        [currentCenter removeObserver:self name:DRDeviceAppearedNotification object:nil];

        if (returnCode == NSOKButton)
        {
            //Save the preferences
            NSArray *speeds;
            DRDevice *currentDevice = [self currentDevice];
            NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
            
            BOOL isIgnoreModeEnabled = [self isIgnoreModeEnabled];
            if (isIgnoreModeEnabled == NO)
            {
                speeds = [[[currentDevice status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceBurnSpeedsKey];
            }
            
            NSNumber *speed;
            
            NSPopUpButton *speedPopup = [self speedPopup];
            if ([speedPopup indexOfSelectedItem] == 0 || isIgnoreModeEnabled == YES)
            {
                speed = @(65535.0f);
            }
            else
            {
                speed = [speeds objectAtIndex:[speedPopup indexOfSelectedItem] - 2];
            }

            [standardDefaults setObject:speed forKey:@"DRBurnOptionsBurnSpeed"];

            NSMutableDictionary *burnDict = [[NSMutableDictionary alloc] init];
            NSDictionary *deviceInfo = [currentDevice info];

            [burnDict setObject:[deviceInfo objectForKey:@"DRDeviceProductNameKey"] forKey:@"Product"];
            [burnDict setObject:[deviceInfo objectForKey:@"DRDeviceVendorNameKey"] forKey:@"Vendor"];
            [burnDict setObject:@"" forKey:@"SerialNumber"];

            [standardDefaults setObject:burnDict forKey:@"KWDefaultDeviceIdentifier"];

            [[NSNotificationCenter defaultCenter] postNotificationName:@"KWMediaChanged" object:nil];

            //We're gonna store our setup values for later :-)
            [self setSavedDevice:currentDevice];

            NSMutableDictionary *mutableDict = [NSMutableDictionary dictionary];

            //Set speed
            if ([speedPopup indexOfSelectedItem] == 0 && isIgnoreModeEnabled == NO)
            {
                mutableDict[DRBurnRequestedSpeedKey] = [speeds objectAtIndex:[speeds count] -1];
            }
            else
            {
                mutableDict[DRBurnRequestedSpeedKey] = speed;
            }
            //Set more sessions allowed
            [mutableDict setObject:[NSNumber numberWithBool:([[self sessionsCheckBox] state] == NSOnState)] forKey:DRBurnAppendableKey];
            //Set overwrite / erase before burning
            [mutableDict setObject:[NSNumber numberWithBool:([[self eraseCheckBox] state] == NSOnState)] forKey:DRBurnOverwriteDiscKey];
            //Set should verify from preferences
            [mutableDict setObject:[standardDefaults objectForKey:@"KWBurnOptionsVerifyBurn"] forKey:DRBurnVerifyDiscKey];
            //Set completion action from preferences if one disc
            [mutableDict setObject:[standardDefaults objectForKey:@"KWBurnOptionsCompletionAction"] forKey:DRBurnCompletionActionKey];

            [self setProperties:mutableDict];
        }
        
        completion(returnCode);
    }];
}

- (void)burnDiskImageAtPath:(NSString *)path
{
    [self setSize:[self getImageSizeAtPath:path]];

    if ([self canBurn])
    {
	    DRBurn *burn = [[DRBurn alloc] initWithDevice:[self savedDevice]];
	    [burn setProperties:[self properties]];
	    [[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(burnNotification:) name:DRBurnStatusChangedNotification object:burn];
	    
        id layout = [DRBurn layoutForImageFile:path];
    
        if (layout != nil)
        {
            [burn writeLayout:layout];
            [self setBurn:burn];
        }
        else
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWFailure" forKey:@"ReturnCode"]];
        }
    }
    else
    {
	    [[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWCanceled" forKey:@"ReturnCode"]];
    }
}

- (void)writeTrack:(id)track
{
    BOOL hasTracks = YES;
    id burnTrack = track;
    
    if ([track isKindOfClass:[DRTrack class]])
    {
	    [self setSize:[track estimateLength]];
    }
    else
    {
	    NSInteger numberOfTracks = [(NSArray *)track count];
	    if (numberOfTracks > 0)
	    {
    	    NSInteger i;
    	    for (i=0;i<numberOfTracks;i++)
    	    {
	    	    id newTrack = [(NSArray *)track objectAtIndex:i];
    	    
	    	    if ([newTrack isKindOfClass:[NSDictionary class]])
	    	    {
    	    	    burnTrack = newTrack;
    	    	    newTrack = [newTrack objectForKey:@"_DRBurnCueLayout"];
	    	    }

	    	    if ([newTrack isKindOfClass:[DRTrack class]])
	    	    {
                    NSInteger size = [self size];
                    [self setSize:size + [(DRTrack *)newTrack estimateLength]];
	    	    }
	    	    else
	    	    {
    	    	    for (DRTrack *track in newTrack)
    	    	    {
                        NSInteger size = [self size];
                        [self setSize:size + [track estimateLength]];
    	    	    }
	    	    }
    	    }
	    }
	    else
	    {
    	    hasTracks = NO;
	    }
    }
    
    if (hasTracks == NO)
    {
    
	    [[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWFailure" forKey:@"ReturnCode"]];
    }
    else if ([self canBurn])
    {
        DRBurn *burn = [self burn];
	    [burn writeLayout:burnTrack];
	    
	    [[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(burnNotification:) name:DRBurnStatusChangedNotification object:burn];
     
        [[KWProgressManager sharedManager] setCancelHandler:^
        {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^
            {
                if ([self isOverwritable])
                {
                    [self setUserCanceled:YES];
                    [burn abort];
                }
                else
                {
                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert addButtonWithTitle:NSLocalizedString(@"Continue", nil)];
                    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
                    [alert setMessageText:NSLocalizedString(@"Are you sure you want to cancel?", nil)];
                    [alert setInformativeText:NSLocalizedString(@"After canceling the disc can't be used anymore?", nil)];
                    [alert setAlertStyle:NSWarningAlertStyle];

                    if ([alert runModal] == NSAlertFirstButtonReturn)
                    {
                        [self setUserCanceled:YES];
                        [burn abort];
                    }
                }
            }];
        }];
    }
    else
    {
	    [[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWCanceled" forKey:@"ReturnCode"]];
    }
}

- (void)burnTrack:(id)track 
{
    DRBurn *burn = [[DRBurn alloc] initWithDevice:[self savedDevice]];
    [self setBurn:burn];
    
    NSMutableDictionary *burnProperties = [[NSMutableDictionary alloc] initWithDictionary:[self properties] copyItems:YES];
    
    NSDictionary *extraBurnProperties = [self extraBurnProperties];
    if (extraBurnProperties)
    {
	    [burnProperties addEntriesFromDictionary:extraBurnProperties];
    }
    
    [burnProperties setObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"KWSimulateBurn"] forKey:DRBurnTestingKey];
    
    NSNumber *layerBreak = [self layerBreak];
    if (layerBreak== nil)
    {
        layerBreak = @(0.5);
        [self setLayerBreak:layerBreak];
    }
    [burnProperties setObject:layerBreak forKey:@"DRBurnDoubleLayerL0DataZoneBlocksKey"];
    
    [burn setProperties:burnProperties];
    [self writeTrack:track];
    
    DRDevice *savedDevice = [self savedDevice];
    BOOL isOverwritable;
    if ([[savedDevice status] objectForKey:DRDeviceMediaInfoKey])
    {
	    isOverwritable = [[[[savedDevice status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsOverwritableKey] boolValue];
    }
    else
    {
	    isOverwritable = NO;
    }
    [self setOverwritable:isOverwritable];
}

- (void)burnTrackToImage:(NSDictionary *)dict
{
    NSString *path = [dict objectForKey:@"Path"];
    id track =  [dict objectForKey:@"Track"];
    
    if ([[path pathExtension] isEqualTo:@"cue"])
    {
	    path = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"bin"];
    }
    
    [self setImagePath:path];
    DRCallbackDevice *device = [[DRCallbackDevice alloc] init];
    [device initWithConsumer:self];
    DRBurn *burn = [[DRBurn alloc] initWithDevice:device];
    [self setBurn:burn];
    [self writeTrack:track];
    
    [self setOverwritable:YES];
}

- (NSInteger)getImageSizeAtPath:(NSString *)path
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];

    if ([[path pathExtension] isEqualTo:@"cue"])
    {
        NSDictionary *attributes = [defaultManager attributesOfItemAtPath:[[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"bin"] error:nil];
	    return (NSInteger)[attributes[NSFileSize] floatValue] / 1024;
    }
    else if ([[path pathExtension] isEqualTo:@"toc"])
    {
	    float appendSize = 0;
	    NSArray *paths = [[KWCommonMethods stringWithContentsOfFile:path] componentsSeparatedByString:@"FILE \""];
	    NSString  *filePath;
    	    
	    NSInteger z;
	    for (z=1;z<[paths count];z++)
	    {
    	    filePath = [[[paths objectAtIndex:z] componentsSeparatedByString:@"\""] objectAtIndex:0];
    	    
    	    if ([[filePath stringByDeletingLastPathComponent] isEqualTo:@""])
	    	    filePath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:filePath];
            
            NSDictionary *attributes = [defaultManager attributesOfItemAtPath:filePath error:nil];
    	    appendSize = appendSize + [attributes[NSFileSize] floatValue];
	    }
    	    
	    return (NSInteger)appendSize / 1024;
    }
    else
    {
        NSDictionary *attributes = [defaultManager attributesOfItemAtPath:path error:nil];
	    return (NSInteger)[attributes[NSFileSize] floatValue] / 1024;
    }
}

- (void)updateDevice:(DRDevice *)device
{
    if ([self isIgnoreModeEnabled] == YES)
    {
	    [[self eraseCheckBox] setEnabled:YES];
	    [[self closeButton] setEnabled:NO];
	    [[self sessionsCheckBox] setEnabled:YES];
	    [[self closeButton] setTitle:NSLocalizedString(@"Eject", nil)];
	    [[self statusText] setStringValue:NSLocalizedString(@"Ready to copy", nil)];
	    [[self burnButton] setEnabled:YES];
    }
    else if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateMediaPresent])
    {
	    if ([[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsBlankKey] boolValue] || [[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsAppendableKey] boolValue] || [[[[device status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsOverwritableKey] boolValue])
	    {
    	    [self populateSpeeds:device];
    	    [[self speedPopup] setEnabled:YES];
	    
    	    NSDictionary *mediaInfo = [[device status] objectForKey:DRDeviceMediaInfoKey];
    	    BOOL erasable = [[mediaInfo objectForKey:DRDeviceMediaIsErasableKey] boolValue];
    	    BOOL appendable = [[mediaInfo objectForKey:DRDeviceMediaIsAppendableKey] boolValue];
    	    BOOL blank = [[mediaInfo objectForKey:DRDeviceMediaIsBlankKey] boolValue];
    	    BOOL isCD = [[mediaInfo objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassCD];
    	    
            NSButton *eraseCheckBox = [self eraseCheckBox];
    	    [eraseCheckBox setEnabled:(erasable && appendable && !blank)];
    	    [eraseCheckBox setState:(erasable && !appendable && !blank)];
    	    [[self sessionsCheckBox] setEnabled:isCD];
            
            NSButton *closeButton = [self closeButton];
    	    [closeButton setEnabled:YES];
    	    [closeButton setTitle:NSLocalizedString(@"Eject", nil)];
	    
    	    [[self statusText] setStringValue:NSLocalizedString(@"Ready to burn", nil)];
	    
    	    [[self burnButton] setEnabled:YES];
	    }
	    else
	    {
    	    [device ejectMedia];
	    }
    }
    else if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateInTransition])
    {
	    [[self speedPopup] setEnabled:NO];
	    [[self eraseCheckBox] setEnabled:NO];
	    [[self eraseCheckBox] setState:NSOffState];
	    [[self sessionsCheckBox] setEnabled:NO];
	    [[self closeButton] setEnabled:NO];
	    [[self statusText] setStringValue:NSLocalizedString(@"Waiting for the drive...", nil)];
	    [[self burnButton] setEnabled:NO];
    }
    else if ([[[device status] objectForKey:DRDeviceMediaStateKey] isEqualTo:DRDeviceMediaStateNone])
    {
	    [self populateSpeeds:device];
	    [[self speedPopup] setEnabled:NO];
	    [[self eraseCheckBox] setEnabled:NO];
	    [[self eraseCheckBox] setState:NSOffState];
	    [[self sessionsCheckBox] setEnabled:NO];
        
        NSButton *closeButton = [self closeButton];
	    if ([[device info][DRDeviceLoadingMechanismCanOpenKey] boolValue])
	    {
    	    [closeButton setEnabled:YES];
	    
    	    if ([[device status][DRDeviceIsTrayOpenKey] boolValue])
            {
	    	    [closeButton setTitle:NSLocalizedString(@"Close", nil)];
            }
    	    else
            {
	    	    [closeButton setTitle:NSLocalizedString(@"Open", nil)];
            }
	    }
	    else
	    {
    	    [closeButton setTitle:NSLocalizedString(@"Close", nil)];
    	    [closeButton setEnabled:NO];
	    }
	    
	    [[self statusText] setStringValue:NSLocalizedString(@"Waiting for a disc to be inserted...", nil)];
	    [[self burnButton] setEnabled:NO];
    }
}

#pragma mark - Main Sheet Methods

- (IBAction)burnerPopup:(id)sender
{
    DRDevice *currentDevice = [self currentDevice];

    if ([[currentDevice info][DRDeviceLoadingMechanismCanOpenKey] boolValue])
    {
	    if ([[currentDevice status][DRDeviceIsTrayOpenKey] boolValue] == NO)
	    {
    	    [currentDevice openTray];
            [self setShouldClose:YES];
	    }
    }
    
    NSInteger i = 0;
    for (DRDevice *device in [DRDevice devices])
    {
	    if ([[device info][DRDeviceLoadingMechanismCanOpenKey] boolValue] && [[device status][DRDeviceIsTrayOpenKey] boolValue] && (!i) == [[self burnerPopup] indexOfSelectedItem])
        {
    	    [device closeTray];
        }
        
        i++;
    }

    [self updateDevice:currentDevice];
}

- (IBAction)cancelButton:(id)sender
{
    if ([self shouldClose])
    {
	    [[self currentDevice] closeTray];
    }
    
    NSWindow *window = [self window];
    [[window sheetParent] endSheet:window returnCode:NSCancelButton];
    [window orderOut:self];
}

- (IBAction)closeButton:(id)sender
{
    DRDevice *currentDevice = [self currentDevice];
    NSString *closeButtonTitle = [[self closeButton] title];

    if ([closeButtonTitle isEqualTo:NSLocalizedString(@"Eject", nil)])
    {
	    [currentDevice ejectMedia];
    }
    else if ([closeButtonTitle isEqualTo:NSLocalizedString(@"Close", nil)])
    {
	    [currentDevice closeTray];
    }
    else if ([closeButtonTitle isEqualTo:NSLocalizedString(@"Open", nil)])
    {
	    [self setShouldClose:YES];
	    [currentDevice openTray];
    }
}

- (IBAction)burnButton:(id)sender
{
    NSWindow *window = [self window];
    [[window sheetParent] endSheet:window returnCode:NSOKButton];
    [window orderOut:self];
}

- (IBAction)combineSessions:(id)sender
{
    BOOL combineSessionEnabled = [sender state] == NSOnState;
    [self setCombineSessionsEnabled:combineSessionEnabled];

    if (combineSessionEnabled)
    {
	    [NSApp runModalForWindow:[self sessionsPanel]];
    }
}

#pragma mark - Session Sheet Methods

- (IBAction)okSession:(id)sender
{
    [self setCombinedDataSessionEnabled:[[self dataSession] state] == NSOnState];
    [self setCombinedAudioSessionEnabled:[[self audioSession] state] == NSOnState];
    [self setCombinedVideoSessionEnabled:[[self videoSession] state] == NSOnState];

    [NSApp stopModal];
    [[self sessionsPanel] orderOut:self];
}

- (IBAction)cancelSession:(id)sender
{
    [NSApp stopModal];
    [[self sessionsPanel] orderOut:self];
    [[self currentCombineCheckBox] setState:NSOffState];
}

#pragma mark - Notification Methods

- (void)statusChanged:(NSNotification *)notif
{
    DRDevice *device = [notif object];

    if ([[device displayName] isEqualTo:[[self burnerPopup] title]])
    [self updateDevice:device];
}

- (void)mediaChanged:(NSNotification *)notification
{
    NSPopUpButton *burnerPopup = [self burnerPopup];
    [burnerPopup removeAllItems];
    
    NSArray *devices = [DRDevice devices];

    NSInteger i;
    for (i=0;i< [devices count];i++)
    {
	    [burnerPopup addItemWithTitle:[[devices objectAtIndex:i] displayName]];
    }
    
    NSString *saveDeviceName = [[self savedDevice] displayName];
    
    if ([burnerPopup indexOfItemWithTitle:saveDeviceName] > -1)
    {
	    [burnerPopup selectItemAtIndex:[burnerPopup indexOfItemWithTitle:saveDeviceName]];
    }
    
    [self updateDevice:[self currentDevice]];
}

- (void)burnNotification:(NSNotification*)notification    
{
    NSDictionary *status = [notification userInfo];
    NSString *currentStatusString = [status objectForKey:DRStatusStateKey];
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    NSString *time = nil;
    NSString *statusString = nil;
    
    KWLog(@"%@", [status description]);
    
    if ([[status objectForKey:DRStatusPercentCompleteKey] floatValue] > 0)
    {
	    if (![currentStatusString isEqualTo:DRStatusStateTrackOpen])
	    {
    	    NSNumber *percent = [status objectForKey:DRStatusPercentCompleteKey];
    	    double currentPercent = [percent doubleValue];
         
            KWProgressManager *progressManager = [KWProgressManager sharedManager];
            [progressManager setMaximumValue:1.0];
            [progressManager setValue:currentPercent];
    	    
    	    if (![self imagePath])
    	    {
	    	    float currentSpeed = [[status objectForKey:DRStatusCurrentSpeedKey] floatValue];
                NSInteger size = [self size];
	    	    time = [KWCommonMethods formatTime:size / currentSpeed - (size / currentSpeed * currentPercent)];
    	    }
    	    else
    	    {
	    	    time = [NSString stringWithFormat:@"%.0f%@", currentPercent * 100, @"%"];
    	    }
	    }
    }
    else
    {
        [[KWProgressManager sharedManager] setMaximumValue:0.0];
    }
    
    if ([currentStatusString isEqualTo:DRStatusStatePreparing])
    {
	    statusString = NSLocalizedString(@"Preparing...", nil);
    }
    else if ([currentStatusString isEqualTo:DRStatusStateTrackOpen])
    {
	    if ([[status objectForKey:DRStatusTotalTracksKey] intValue] > 1)
    	    statusString = [NSString stringWithFormat:NSLocalizedString(@"Opening track %ld", nil),[[status objectForKey:DRStatusCurrentTrackKey] longValue]];
	    else
    	    statusString = NSLocalizedString(@"Opening track", nil);
    }
    else if ([currentStatusString isEqualTo:DRStatusStateTrackWrite])
    {
	    if (time)
	    {
    	    if ([[status objectForKey:DRStatusTotalTracksKey] intValue] > 1)
	    	    statusString = [NSString stringWithFormat:NSLocalizedString(@"Writing track %ld of %ld (%@)", nil), [[status objectForKey:DRStatusCurrentTrackKey] longValue], [[status objectForKey:DRStatusTotalTracksKey] longValue], time];
    	    else
	    	    statusString = [NSString stringWithFormat:NSLocalizedString(@"Writing track (%@)", nil), time];
	    }
    }
    else if ([currentStatusString isEqualTo:DRStatusStateTrackClose])
    {
	    if ([[status objectForKey:DRStatusTotalTracksKey] intValue] > 1)
    	    statusString = [NSString stringWithFormat:NSLocalizedString(@"Closing track %ld of %ld (%@)", nil), [[status objectForKey:DRStatusCurrentTrackKey] longValue], [[status objectForKey:DRStatusTotalTracksKey] longValue], time];
	    else
    	    statusString = [NSString stringWithFormat:NSLocalizedString(@"Closing track (%@)", nil), time];
    }
    else if ([currentStatusString isEqualTo:DRStatusStateSessionClose])
    {
	    statusString = NSLocalizedString(@"Closing session", nil);
    }
    else if ([currentStatusString isEqualTo:DRStatusStateFinishing])
    {
	    statusString = NSLocalizedString(@"Finishing...", nil);
    }
    else if ([currentStatusString isEqualTo:DRStatusStateVerifying])
    {
	    statusString = NSLocalizedString(@"Verifying...", nil);
    }
    else if ([currentStatusString isEqualTo:DRStatusStateDone])
    {
        [[KWProgressManager sharedManager] setCancelHandler:nil];
	    [[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRBurnStatusChangedNotification object:[notification object]];
	    
    
	    [[NSNotificationCenter defaultCenter] postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWSuccess" forKey:@"ReturnCode"]];
    }
    else if ([currentStatusString isEqualTo:DRStatusStateFailed])
    {
        [[KWProgressManager sharedManager] setCancelHandler:nil];
	    [[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRBurnStatusChangedNotification object:[notification object]];
	    
	    
	    if ([self didUserCancel])
	    {
    	    [defaultCenter postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObject:@"KWCanceled" forKey:@"ReturnCode"]];
	    }
	    else
	    {
    	    NSString *errorString;
	    
    	    if ([[status objectForKey:DRErrorStatusKey] objectForKey:@"DRErrorStatusErrorInfoStringKey"])
            {
	    	    errorString = [[status objectForKey:DRErrorStatusKey] objectForKey:@"DRErrorStatusErrorInfoStringKey"];
            }
    	    else
            {
	    	    errorString = [[status objectForKey:DRErrorStatusKey] objectForKey:DRErrorStatusErrorStringKey];
            }

    	    [defaultCenter postNotificationName:@"KWBurnFinished" object:self userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"KWFailure", errorString, nil] forKeys:[NSArray arrayWithObjects:@"ReturnCode",@"Error", nil]]];
	    }
	    
    }
    
    if (statusString)
    {
        [[KWProgressManager sharedManager] setStatus:statusString];
    }
}

#pragma mark - Image Methods

- (BOOL)writeBlocks:(char*)wBlocks blockCount:(uint32_t)bCount blockSize:(uint32_t)bSize atAddress:(uint64_t)address
{
    NSOutputStream *imageStream = [NSOutputStream outputStreamToFileAtPath:[self imagePath] append:YES];
    [imageStream open];    
    [imageStream write:(const uint8_t *)wBlocks maxLength:bSize * bCount];
    [imageStream close];

    return NO;
}

- (BOOL)prepareBurn:(DRBurn *)burnObject
{
    return NO;
}

- (BOOL)prepareTrack:(id)track trackIndex:(id)index
{
    NSInteger trackNumber = [self trackNumber];
    [self setTrackNumber:trackNumber + 1];
    return NO;
}

- (BOOL)prepareSession:(id)session sessionIndex:(id)index
{
    return NO;
}

- (BOOL)cleanupSessionAfterBurn:(id)session sessionIndex:(id)index
{
    return NO;
}

- (BOOL)cleanupAfterBurn:(DRBurn *)burnObject
{
    return NO;
}

- (BOOL)cleanupTrackAfterBurn:(DRTrack *)track trackIndex:(id)index
{
    return NO;
}

#pragma mark - Other actions

- (void)prepareTypes
{
    NSMatrix *sessions = [self sessions];

    NSInteger i;
    for (i=0;i< 3;i++)
    {
	    [[sessions cellWithTag:i] setState:NSOffState];
	    
	    if (![[self combinableTypes] containsObject:[NSNumber numberWithInt:i]])
    	    [[sessions cellWithTag:i] setEnabled:NO];
    }
    
    NSInteger type = [self type];
    [[sessions cellWithTag:type] setEnabled:NO];
    [[sessions cellWithTag:type] setState:NSOnState];
}

- (void)setCombineBox:(id)box
{
    [self setCurrentCombineCheckBox:box];
}

- (DRDevice *)currentDevice
{
    return [[DRDevice devices] objectAtIndex:[[self burnerPopup] indexOfSelectedItem]];
}

- (void)populateSpeeds:(DRDevice *)device
{
    NSDictionary *mediaInfo = [[device status] objectForKey:DRDeviceMediaInfoKey];
    NSArray *speeds = [mediaInfo objectForKey:DRDeviceBurnSpeedsKey];
    
    NSPopUpButton *speedPopup = [self speedPopup];
    [speedPopup removeAllItems];

    if ([speeds count] > 0)
    {
	    float speed;
    
	    NSInteger z;
	    for (z=0;z<[speeds count];z++)
	    {
    	    speed = [[speeds objectAtIndex:z] floatValue];
	    
    	    if ([[mediaInfo objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassCD])
	    	    speed = speed / DRDeviceBurnSpeedCD1x;
    	    else
	    	    speed = speed / DRDeviceBurnSpeedDVD1x;

    	    [speedPopup addItemWithTitle:[NSString stringWithFormat:@"%.0fx", speed]];
	    }

    [speedPopup insertItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Maximum Possible (%.0fx)", nil), speed] atIndex:0];
    [[speedPopup menu] insertItem:[NSMenuItem separatorItem] atIndex:1];


	    NSNumber *burnSpeed = [[NSUserDefaults standardUserDefaults] objectForKey:@"DRBurnOptionsBurnSpeed"];
	    
	    if (!burnSpeed)
	    {
    	    if ([speeds containsObject:burnSpeed])
    	    {
	    	    [speedPopup selectItemAtIndex:[speeds indexOfObject:burnSpeed] + 2];
    	    }
    	    else
    	    {
	    	    [speedPopup selectItemAtIndex:0];
    	    }
	    }
	    else
	    {
    	    [speedPopup selectItemAtIndex:0];
	    }
    }
    else
    {
	    [speedPopup addItemWithTitle:NSLocalizedString(@"Maximum Possible", nil)];
    }
}

- (DRDevice *)savedDevice
{
    NSArray *devices = [DRDevice devices];
    
    NSInteger i;
    for (i=0;i< [devices count];i++)
    {
	    DRDevice *device = [devices objectAtIndex:i];
    
	    if ([[[device info] objectForKey:@"DRDeviceProductNameKey"] isEqualTo:[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"KWDefaultDeviceIdentifier"] objectForKey:@"Product"]])
	    {
    	    return device;
	    }
    }
    
    return [devices objectAtIndex:0];
}

- (BOOL)canBurn
{
    if ([self imagePath])
    {
	    return YES;
    }

    NSInteger space;
    NSDictionary *mediaInfo = [[[self savedDevice] status] objectForKey:DRDeviceMediaInfoKey];

    if ([[mediaInfo objectForKey:DRDeviceMediaIsBlankKey] boolValue])
    {
	    space = [[mediaInfo objectForKey:DRDeviceMediaFreeSpaceKey] floatValue];
    }
    else if ([[mediaInfo objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassDVD])
    {
	    space = [[mediaInfo objectForKey:DRDeviceMediaOverwritableSpaceKey] floatValue];
    }
    else
    {
	    space = (NSInteger)[KWCommonMethods defaultSizeForMedia:@"KWDefaultCDMedia"];
    }
	    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWAllowOverBurning"])
    {
	    return YES;
    }
    else if (space < [self size])
    {
	    NSAlert *alert = [[NSAlert alloc] init];
	    [alert addButtonWithTitle:NSLocalizedString(@"Burn", nil)];
	    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
	    [alert setMessageText:NSLocalizedString(@"Not enough space", nil)];
	    [alert setInformativeText:NSLocalizedString(@"Still try to burn the disc?", nil)];
	    [alert setAlertStyle:NSWarningAlertStyle];
	    
	    return ([alert runModal] == NSAlertFirstButtonReturn);
    }
    else
    {
	    return YES;
    }
}

- (BOOL)isCD
{
    return [[[[[self savedDevice] status] objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaClassKey] isEqualTo:DRDeviceMediaClassCD];
}

- (void)setType:(NSInteger)type
{
    _type = type;
    
    if (_combinableTypes == nil)
    {
        _combinableTypes = @[@(_type)];
    }
}

- (void)setCombinableTypes:(NSArray *)types
{
    _combinableTypes = types;
}

- (NSArray *)types
{
    if ([self isCombineSessionsEnabled])
    {
        NSMutableArray *types = [NSMutableArray array];
        
        if ([self isCombinedDataSessionEnabled])
        {
            [types addObject:[NSNumber numberWithInt:0]];
        }
        
        if ([self isCombinedAudioSessionEnabled])
        {
            [types addObject:[NSNumber numberWithInt:1]];
        }
        
        if ([self isCombinedVideoSessionEnabled])
        {
            [types addObject:[NSNumber numberWithInt:2]];
        }
        
        return types;
    }
    else
    {
        return [NSArray arrayWithObject:[NSNumber numberWithInt:[self type]]];
    }
}

@end

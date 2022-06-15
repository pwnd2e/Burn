#import "KWEraser.h"
#import "KWProgressManager.h"

@interface KWEraser()

//Interface
@property (nonatomic, weak) IBOutlet NSPopUpButton *burnerPopup;
@property (nonatomic, weak) IBOutlet NSButton *closeButton;
@property (nonatomic, weak) IBOutlet NSButton *completelyErase;
@property (nonatomic, weak) IBOutlet NSButton *eraseButton;
@property (nonatomic, weak) IBOutlet NSButton *quicklyErase;
@property (nonatomic, weak) IBOutlet NSTextField *statusText;

@property (nonatomic, weak) NSWindow *modalWindow;
@property (copy) void(^completion)(NSDictionary *response);
@property (nonatomic) BOOL shouldClose;

@end

@implementation KWEraser

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        [[NSBundle mainBundle] loadNibNamed:@"KWEraser" owner:self topLevelObjects:nil];
    }

    return self;
}

///////////////////
// Main actions //
///////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)setupWindow
{
    NSPopUpButton *burnerPopup = [self burnerPopup];
    [burnerPopup removeAllItems];
    
    for (DRDevice *device in [DRDevice devices])
    {
	    [burnerPopup addItemWithTitle:[device displayName]];
    }
    
    NSString *displayName = [[self savedDevice] displayName];
    if ([burnerPopup indexOfItemWithTitle:displayName] > -1)
    {
	    [burnerPopup selectItemAtIndex:[burnerPopup indexOfItemWithTitle:displayName]];
    }
    
    [self updateDevice:[self currentDevice]];

    [[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(statusChanged:) name:DRDeviceStatusChangedNotification object:nil];
}

- (void)beginEraseSheetForWindow:(NSWindow *)modalWindow completion:(void (^)(NSDictionary *response))completion
{
    [self setModalWindow:modalWindow];
    [self setCompletion:completion];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^
    {
        [self setupWindow];
        
        NSWindow *window = [self window];
        [modalWindow beginSheet:window completionHandler:^(NSModalResponse returnCode)
        {
            [[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRDeviceStatusChangedNotification object:nil];
            if (returnCode == NSModalResponseOK)
            {
                [window orderOut:nil];
                [self erase];
            }
            else
            {
                if (completion != nil)
                {
                    completion(@{@"ReturnCode": @"KWCanceled"});
                }
            }
        }];
    }];
}

- (void)erase
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^
    {
        KWProgressManager *progressManager = [KWProgressManager sharedManager];
        [progressManager setIconImage:[NSImage imageNamed:@"Burn"]];
        [progressManager setTask:NSLocalizedString(@"Erasing disc", nil)];
        [progressManager setStatus:NSLocalizedString(@"Preparing...", nil)];
        [progressManager setMaximumValue:0.0];
        [progressManager setAllowCanceling:NO];
        [progressManager beginSheetForWindow:[self modalWindow]];

        DRErase *erase = [[DRErase alloc] initWithDevice:[self currentDevice]];

        if ([[self completelyErase] state] == NSOnState)
            [erase setEraseType:DREraseTypeComplete];
        else
            [erase setEraseType:DREraseTypeQuick];
        
        //Save burner
        NSMutableDictionary *burnDict = [[NSMutableDictionary alloc] init];

        [burnDict setObject:[[[self currentDevice] info] objectForKey:@"DRDeviceProductNameKey"] forKey:@"Product"];
        [burnDict setObject:[[[self currentDevice] info] objectForKey:@"DRDeviceVendorNameKey"] forKey:@"Vendor"];
        [burnDict setObject:@"" forKey:@"SerialNumber"];

        [[NSUserDefaults standardUserDefaults] setObject:burnDict forKey:@"KWDefaultDeviceIdentifier"];

        [[NSNotificationCenter defaultCenter] postNotificationName:@"KWMediaChanged" object:nil];

        [[DRNotificationCenter currentRunLoopCenter] addObserver:self selector:@selector(eraseNotification:) name:DREraseStatusChangedNotification object:erase];

        [erase start];
    }];
}

- (void)updateDevice:(DRDevice *)device
{
    NSDictionary *deviceStatus = [device status];
    NSString *statusString = [deviceStatus objectForKey:DRDeviceMediaStateKey];

    if ([statusString isEqualTo:DRDeviceMediaStateMediaPresent])
    {
	    if ([[[deviceStatus objectForKey:DRDeviceMediaInfoKey] objectForKey:DRDeviceMediaIsErasableKey] boolValue])
	    {
            NSButton *closeButton = [self closeButton];
    	    [closeButton setEnabled:YES];
    	    [closeButton setTitle:NSLocalizedString(@"Eject", nil)];
	    
    	    [[self statusText] setStringValue:NSLocalizedString(@"Ready to erase", nil)];
	    
    	    [[self eraseButton] setEnabled:YES];
	    }
	    else
	    {
    	    [device ejectMedia];
	    }
    }
    else if ([statusString isEqualTo:DRDeviceMediaStateInTransition])
    {
	    [[self closeButton] setEnabled:NO];
	    [[self statusText] setStringValue:NSLocalizedString(@"Waiting for the drive...", nil)];
	    [[self eraseButton] setEnabled:NO];
    }
    else if ([statusString isEqualTo:DRDeviceMediaStateNone])
    {
        NSButton *closeButton = [self closeButton];
        
	    if ([[[device info] objectForKey:DRDeviceLoadingMechanismCanOpenKey] boolValue])
	    {
    	    [closeButton setEnabled:YES];
	    
    	    if ([[deviceStatus objectForKey:DRDeviceIsTrayOpenKey] boolValue])
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
	    [[self eraseButton] setEnabled:NO];
    }
}

///////////////////////
// Interface actions //
///////////////////////

#pragma mark -
#pragma mark •• Interface actions

- (IBAction)burnerPopup:(id)sender
{
    DRDevice *currentDevice = [self currentDevice];

    if ([[[currentDevice info] objectForKey:DRDeviceLoadingMechanismCanOpenKey] boolValue])
    {
	    if (![[[currentDevice status] objectForKey:DRDeviceIsTrayOpenKey] boolValue])
	    {
    	    [currentDevice openTray];
            [self setShouldClose:YES];
	    }
    }
    
    NSInteger i;
    for (DRDevice *device in [DRDevice devices])
    {
	    if ([[[device info] objectForKey:DRDeviceLoadingMechanismCanOpenKey] boolValue] && [[[device status] objectForKey:DRDeviceIsTrayOpenKey] boolValue] && (!i) == [[self burnerPopup] indexOfSelectedItem])
        {
    	    [device closeTray];
        }
        
        i ++;
    }

    [self updateDevice:currentDevice];
}

- (IBAction)cancelButton:(id)sender
{
    if ([self shouldClose])
	    [[[DRDevice devices] objectAtIndex:[[self burnerPopup] indexOfSelectedItem]] closeTray];
	    
    [[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DREraseStatusChangedNotification object:nil];
    
    if ([[self window] isSheet])
    {
        NSWindow *window = [self window];
	    [[window sheetParent] endSheet:window returnCode:NSModalResponseCancel];
        [window orderOut:self];
    }
    else
    {
	    [NSApp stopModalWithCode:NSModalResponseCancel];
    }
}

- (IBAction)closeButton:(id)sender
{
    DRDevice *selectedDevice = [[DRDevice devices] objectAtIndex:[[self burnerPopup] indexOfSelectedItem]];

    NSButton *closeButton = [self closeButton];
    if ([[closeButton title] isEqualTo:NSLocalizedString(@"Eject", nil)])
    {
	    [selectedDevice ejectMedia];
    }
    else if ([[closeButton title] isEqualTo:NSLocalizedString(@"Close", nil)])
    {
	    [selectedDevice closeTray];
    }
    else if ([[closeButton title] isEqualTo:NSLocalizedString(@"Open", nil)])
    {
        [self setShouldClose:YES];
	    [selectedDevice openTray];
    }
}

- (IBAction)eraseButton:(id)sender
{
    [[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DREraseStatusChangedNotification object:nil];
    
    if ([[self window] isSheet])
    {
        NSWindow *window = [self window];
        NSWindow *sheetParent = [window sheetParent];
        [window orderOut:self];
        [sheetParent endSheet:window returnCode:NSModalResponseOK];
    }
    else
    {
	    [NSApp stopModalWithCode:NSModalResponseOK];
    }
}

//////////////////////////
// Notification actions //
//////////////////////////

#pragma mark -
#pragma mark •• Notification actions

- (void)statusChanged:(NSNotification *)notif
{
    DRDevice *notifDevice = [notif object];

    if ([[notifDevice displayName] isEqualTo:[[self burnerPopup] title]])
    [self updateDevice:notifDevice];
}

- (void)eraseNotification:(NSNotification*)notification    
{    
    NSDictionary* status = [notification userInfo];
    DRErase *eraseObject = [notification object];
    NSString *currentStatusString = [status objectForKey:DRStatusStateKey];
    NSString *time = @"";
    NSString *statusString = nil;
    
    KWLog(@"%@", [status description]);
    
    double percent = [[status objectForKey:DRStatusPercentCompleteKey] doubleValue];
    if (percent > 0)
    {
        KWProgressManager *progressManager = [KWProgressManager sharedManager];
        [progressManager setMaximumValue:1.0];
        [progressManager setValue:percent];
	    
	    NSString *progressString = [KWCommonMethods formatTime:[[[status objectForKey:@"DRStatusProgressInfoKey"] objectForKey:@"DRStatusProgressRemainingTime"] intValue]];
	    
	    time = [NSString stringWithFormat:@" (%@)", progressString];
    }
    else
    {
        [[KWProgressManager sharedManager] setMaximumValue:0.0];
    }

    if ([currentStatusString isEqualTo:DRStatusStatePreparing])
    {
	    statusString = NSLocalizedString(@"Preparing...", nil);
    }
    else if ([currentStatusString isEqualTo:DRStatusStateErasing])
    {
	    statusString = [NSLocalizedString(@"Erasing disc", nil) stringByAppendingString:time];
    }
    else if ([currentStatusString isEqualTo:DRStatusStateFinishing])
    {
	    statusString = NSLocalizedString(@"Finishing...", nil);
    }
    else if ([currentStatusString isEqualTo:DRStatusStateDone])
    {
	    [[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DREraseStatusChangedNotification object:eraseObject];
	    
	    [[KWProgressManager sharedManager] endSheetWithCompletion:^
        {
            void(^completion)(NSDictionary *response) = [self completion];
            if (completion != nil)
            {
                completion(@{@"ReturnCode": @"KWSuccess"});
            }
        }];
        
        return;
    }
    else if ([currentStatusString isEqualTo:DRStatusStateFailed])
    {
	    [[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DREraseStatusChangedNotification object:eraseObject];
    
	    [[KWProgressManager sharedManager] endSheetWithCompletion:^
        {
            void(^completion)(NSDictionary *response) = [self completion];
            if (completion != nil)
            {
                completion(@{@"ReturnCode": @"KWFailure"});
            }
        }];
        
        return;
    }
    
    if (statusString)
    {
        [[KWProgressManager sharedManager] setStatus:statusString];
    }
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (DRDevice *)currentDevice
{
    return [[DRDevice devices] objectAtIndex:[[self burnerPopup] indexOfSelectedItem]];
}

- (DRDevice *)savedDevice
{
    NSArray *devices = [DRDevice devices];
    for (DRDevice *device in devices)
    {
        if ([[[device info] objectForKey:@"DRDeviceProductNameKey"] isEqualTo:[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"KWDefaultDeviceIdentifier"] objectForKey:@"Product"]])
	    {
    	    return device;
	    }
    }
    
    return devices[0];
}

@end

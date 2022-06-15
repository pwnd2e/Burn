#import "KWRecorderInfo.h"
#import "KWCommonMethods.h"

@interface KWRecorderInfo()

@property (nonatomic, weak) IBOutlet NSPopUpButton *recorderPopUp;
@property (nonatomic, weak) IBOutlet NSTextField *productTextField;
@property (nonatomic, weak) IBOutlet NSTextField *vendorTextField;
@property (nonatomic, weak) IBOutlet NSTextField *writesTextField;
@property (nonatomic, weak) IBOutlet NSTextField *connectionTypeTextField;
@property (nonatomic, weak) IBOutlet NSTextField *cacheTextField;
@property (nonatomic, weak) IBOutlet NSTextField *bufferTextField;

@property (nonatomic, strong) NSDictionary *discTypeMappings;

@end

@implementation KWRecorderInfo

- (instancetype)init
{
    if( self = [super init] )
    {
        _discTypeMappings = @{  DRDeviceCanWriteCDRKey: @"CD-R",
                                DRDeviceCanWriteCDRWKey: @"CD-RW",
                                DRDeviceCanWriteDVDRKey: @"DVD-R",
                                DRDeviceCanWriteDVDRWKey: @"DVD-RW",
                                DRDeviceCanWriteDVDRAMKey: @"DVD-RAM",
                                DRDeviceCanWriteDVDPlusRKey: @"DVD+R",
                                DRDeviceCanWriteDVDPlusRDoubleLayerKey: @"DVD+R(DL)",
                                DRDeviceCanWriteDVDPlusRWKey: @"DVD+RW",
                                DRDeviceCanWriteBDRKey: @"BD-R",
                                DRDeviceCanWriteBDREKey: @"BD-RE",
                                DRDeviceCanWriteHDDVDRKey: @"HD DVD-R",
                                DRDeviceCanWriteHDDVDRDualLayerKey: @"HD DVD-R(DL)",
                                DRDeviceCanWriteHDDVDRAMKey: @"HD DVD-RAM",
                                DRDeviceCanWriteHDDVDRWKey: @"HD DVD-RW",
                                DRDeviceCanWriteHDDVDRWDualLayerKey: @"HD DVD-RW(DL)"
                             };
        
        [[NSBundle mainBundle] loadNibNamed:@"KWRecorderInfo" owner:self topLevelObjects:nil];
    }
    
    return self;
}

- (void)dealloc
{
    [[DRNotificationCenter currentRunLoopCenter] removeObserver:self name:DRDeviceStatusChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    NSWindow *myWindow = [self window];
    DRNotificationCenter *currentCenter = [DRNotificationCenter currentRunLoopCenter];

    [currentCenter addObserver:self selector:@selector(updateRecorderInfo) name:DRDeviceDisappearedNotification object:nil];
    [currentCenter addObserver:self selector:@selector(updateRecorderInfo) name:DRDeviceAppearedNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveFrame) name:NSWindowWillCloseNotification object:nil];
    
    // TODO: is this necessary?
    [myWindow setFrameUsingName:@"Recorder Info"];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWFirstRun"] == YES)
    {
	    [myWindow setFrameOrigin:NSMakePoint(500.0, [[NSScreen mainScreen] frame].size.height - 310.0)];
    }
}

#pragma mark - Main Methods

- (void)showRecorderInfoForDevice:(DRDevice *)device
{
    NSWindow *myWindow = [self window];

    if ([myWindow isVisible])
    {
	    [myWindow orderOut:self];
    }
    else
    {
        NSPopUpButton *recorderPopup = [self recorderPopUp];
	    [recorderPopup removeAllItems];
        
	    for (DRDevice *device in [DRDevice devices])
	    {
    	    [recorderPopup addItemWithTitle:[device displayName]];
	    }
    	    
	    [recorderPopup selectItemWithTitle:[device displayName]];
	    
	    [self setupRecorderInfoForDevice:device];
	    
	    [myWindow makeKeyAndOrderFront:self];
    }
}

#pragma mark - Interface Methods

- (IBAction)changeRecorder:(NSPopUpButton *)recorderPopUp
{
    NSInteger indexOfSelectedItem = [recorderPopUp indexOfSelectedItem];
    NSArray *devices = [DRDevice devices];
    
    if (indexOfSelectedItem < [devices count])
    {
        DRDevice *device = devices[indexOfSelectedItem];
        [self setupRecorderInfoForDevice:device];
    }
    else
    {
        [self setupRecorderInfoForDevice:nil];
    }
}

#pragma mark - Convenient Methods

- (void)setupRecorderInfoForDevice:(nullable DRDevice *)device
{
    NSDictionary *deviceInfo = [device info];

	if (deviceInfo != nil)
	{
		[[self productTextField] setStringValue:deviceInfo[DRDeviceProductNameKey]];
		[[self vendorTextField] setStringValue:deviceInfo[DRDeviceVendorNameKey]];
		[[self connectionTypeTextField] setStringValue:deviceInfo[DRDevicePhysicalInterconnectKey]];
		
		NSString *cache = [NSString localizedStringWithFormat:NSLocalizedString(@"%.0f KB", nil), [deviceInfo[@"DRDeviceWriteBufferSizeKey"] doubleValue]];
		[[self cacheTextField] setStringValue:cache];

		NSDictionary *writeCapabilities = deviceInfo[DRDeviceWriteCapabilitiesKey];
		BOOL cdUnderrunProtect = [writeCapabilities[DRDeviceCanUnderrunProtectCDKey] boolValue];
		BOOL canWriteDVD = [writeCapabilities[DRDeviceCanWriteDVDKey] boolValue];
		
		if (cdUnderrunProtect && !canWriteDVD)
		{
			[[self bufferTextField] setStringValue:NSLocalizedString(@"Yes", nil)];
		}
		
		if (canWriteDVD)
		{
			BOOL dvdUnderrunProtect = [writeCapabilities[DRDeviceCanUnderrunProtectDVDKey] boolValue];
			NSString *cdUnderrun = cdUnderrunProtect ? NSLocalizedString(@"Yes", nil) : NSLocalizedString(@"No", nil);
			NSString *dvdUnderrun = dvdUnderrunProtect ? NSLocalizedString(@"Yes", nil) : NSLocalizedString(@"No", nil);
			[[self bufferTextField] setStringValue:[NSString stringWithFormat:@"CD: %@ DVD: %@", cdUnderrun, dvdUnderrun]];
		}
		
		NSDictionary *discTypes = [self discTypeMappings];
		NSString *writesOn = @"";
		NSString *space = @"";
		
		for (NSString *key in [discTypes allKeys])
		{
			if ([writeCapabilities[key] boolValue])
			{
				writesOn = [NSString stringWithFormat:@"%@%@%@", writesOn, space, discTypes[key]];
				space = @" ";
			}
		}
		
		[[self writesTextField] setStringValue:writesOn];
    }
    else
    {
		[[self productTextField] setStringValue:@""];
		[[self vendorTextField] setStringValue:@""];
		[[self connectionTypeTextField] setStringValue:@""];
		[[self cacheTextField] setStringValue:@""];
		[[self bufferTextField] setStringValue:@""];
		[[self writesTextField] setStringValue:@""	];
    }
}

- (void)updateRecorderInfo
{
    NSPopUpButton *recorderPopUp = [self recorderPopUp];
    NSString *title = [[recorderPopUp title] copy];

    [recorderPopUp removeAllItems];
    
    for (DRDevice *device in [DRDevice devices])
    {
	    [recorderPopUp addItemWithTitle:[device displayName]];
    }
	    
    if ([recorderPopUp indexOfItemWithTitle:title] > -1)
    {
        [recorderPopUp selectItemWithTitle:title];
    }
    
    [self changeRecorder:[self recorderPopUp]];
}

// TODO: is this necessary?
- (void)saveFrame
{
    [[self window] saveFrameUsingName:@"Recorder Info"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

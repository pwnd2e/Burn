#import "KWDiscInfo.h"
#import "KWCommonMethods.h"

@interface KWDiscInfo()

@property (nonatomic, weak) IBOutlet NSPopUpButton *recorderPopUp;
@property (nonatomic, weak) IBOutlet NSTextField *kindTextField;
@property (nonatomic, weak) IBOutlet NSTextField *freeSpaceTextField;
@property (nonatomic, weak) IBOutlet NSTextField *usedSpaceTextField;
@property (nonatomic, weak) IBOutlet NSTextField *writableTextField;

@property (nonatomic, strong) NSDictionary *discTypeMappings;

@end

@implementation KWDiscInfo

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        _discTypeMappings = @{  DRDeviceMediaTypeCDROM: @"CD-ROM",
                                DRDeviceMediaTypeDVDROM: @"DVD-ROM",
                                DRDeviceMediaTypeCDR: @"CD-R",
                                DRDeviceMediaTypeCDRW: @"CD-RW",
                                DRDeviceMediaTypeDVDR: @"DVD-R",
                                DRDeviceMediaTypeDVDRW: @"DVD-RW",
                                DRDeviceMediaTypeDVDRAM: @"DVD-RAM",
                                DRDeviceMediaTypeDVDPlusR: @"DVD+R",
                                DRDeviceMediaTypeDVDPlusRW: @"DVD+RW",
                                DRDeviceMediaTypeDVDRDualLayer: @"DVD-R DL",
                                DRDeviceMediaTypeDVDRWDualLayer: @"DVD-RW DL",
                                DRDeviceMediaTypeDVDPlusRDoubleLayer: @"DVD+R DL",
                                DRDeviceMediaTypeDVDPlusRWDoubleLayer: @"DVD+RW DL",
                                DRDeviceMediaTypeBDR: @"BD-R",
                                DRDeviceMediaTypeBDRE: @"BD-RE",
                                DRDeviceMediaTypeBDROM: @"BD-ROM",
                                DRDeviceMediaTypeHDDVDROM: @"HD DVD-ROM",
                                DRDeviceMediaTypeHDDVDR: @"HD DVD-R",
                                DRDeviceMediaTypeHDDVDRDualLayer: @"HD DVD-R DL",
                                DRDeviceMediaTypeHDDVDRAM: @"HD DVD-RAM",
                                DRDeviceMediaTypeHDDVDRW: @"HD DVD-RW",
                                DRDeviceMediaTypeHDDVDRWDualLayer: @"HD DVD-RW DL",
                                DRDeviceMediaTypeUnknown: @"????"
                            };
        
        [[NSBundle mainBundle] loadNibNamed:@"KWDiscInfo" owner:self topLevelObjects:nil];
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

    [currentCenter addObserver:self selector:@selector(updateDiscInfo) name:DRDeviceDisappearedNotification object:nil];
    [currentCenter addObserver:self selector:@selector(updateDiscInfo) name:DRDeviceAppearedNotification object:nil];
    [currentCenter addObserver:self selector:@selector(updateDiscInfo) name:DRDeviceStatusChangedNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveFrame) name:NSWindowWillCloseNotification object:nil];

    // TODO: is this necessary?
    [myWindow setFrameUsingName:@"Disc Info"];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWFirstRun"] == YES)
    {
	    [myWindow setFrameOrigin:NSMakePoint(500.0, [[NSScreen mainScreen] frame].size.height - 500.0)];
    }
}

#pragma mark - Main Methods

- (void)showDiskInfoForDevice:(DRDevice *)device
{    
    NSWindow *myWindow = [self window];

    if ([myWindow isVisible])
    {
	    [myWindow orderOut:self];
    }
    else 
    {
        NSPopUpButton *recorderPopUp = [self recorderPopUp];
        [recorderPopUp removeAllItems];
        
	    for (DRDevice *device in [DRDevice devices])
	    {
    	    [recorderPopUp addItemWithTitle:[device displayName]];
	    }
    	    
	    [recorderPopUp selectItemWithTitle:[device displayName]];
	    
	    [self setupDiscInfoForDevice:device];
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
        [self setupDiscInfoForDevice:device];
    }
    else
    {
        // This shouldn't happen, but just to be sure :)
        [self updateDiscInfo];
    }
}

#pragma mark -  Convenient Methods

- (void)setupDiscInfoForDevice:(DRDevice *)device
{
    NSDictionary *mediaInfo = [device status][DRDeviceMediaInfoKey];
    NSString *type = [mediaInfo objectForKey:DRDeviceMediaTypeKey];
    NSString *kind = [self discTypeMappings][type];

    if (kind != nil)
    {
        NSString *freeSpace = [KWCommonMethods makeSizeFromFloat:[mediaInfo[DRDeviceMediaFreeSpaceKey] floatValue] * 2048];
        NSString *usedSpace = [KWCommonMethods makeSizeFromFloat:[mediaInfo[DRDeviceMediaUsedSpaceKey] floatValue] * 2048];
    
	    [[self kindTextField] setStringValue:kind];
	    [[self freeSpaceTextField] setStringValue:freeSpace];
	    [[self usedSpaceTextField] setStringValue:usedSpace];

	    if ([[mediaInfo[DRDeviceMediaBlocksOverwritableKey] stringValue] isEqualTo:@"0"])
    	    [[self writableTextField] setStringValue:NSLocalizedString(@"No", nil)];
	    else
    	    [[self writableTextField] setStringValue:NSLocalizedString(@"Yes", nil)];
    }
    else
    {
	    [[self kindTextField] setStringValue:NSLocalizedString(@"No disc", nil)];
	    [[self freeSpaceTextField] setStringValue:@""];
	    [[self usedSpaceTextField] setStringValue:@""];
	    [[self writableTextField] setStringValue:@""];
    }
}

- (void)updateDiscInfo
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
    [[self window] saveFrameUsingName:@"Disc Info"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

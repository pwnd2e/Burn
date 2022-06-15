#import "KWApplication.h"
#import "KWCommonMethods.h"
#import "KWConstants.h"
#import "KWPreferences.h"
#import "KWRecorderInfo.h"
#import "KWDiscInfo.h"
#import "KWEjecter.h"
#import "KWInspector.h"

@interface KWApplication()

@property (nonatomic, strong) KWPreferences *preferences;
@property (nonatomic, strong) KWRecorderInfo *recorderInfo;
@property (nonatomic, strong) KWDiscInfo *discInfo;
@property (nonatomic, strong) KWEjecter *ejecter;
@property (nonatomic, strong) KWInspector *inspector;

@property (nonatomic, weak) id currentObject;
@property (nonatomic, strong) NSString *currentType;

@end

@implementation KWApplication

// Register our defaults
+ (void)initialize
{
    // Register defaults to the preferences
    NSDictionary *defaults = @{ KWRememberLastTab: @(YES),
                                KWRememberPopups: @(YES),
                                KWBurnOptionsVerifyBurn: @(NO),
                                KWShowOverwritableSpace: @(NO),
                                KWDefaultCDMedia: @(6),
                                KWDefaultDVDMedia: @(4),
                                KWDefaultMedia: @(0),
                                KWDefaultDataType: @(0),
                                KWShowFilePackagesAsFolder: @(NO),
                                KWCalculateFilePackageSizes: @(YES),
                                KWCalculateFolderSizes: @(YES),
                                KWCalculateTotalSize: @(YES),
                                KWDefaultAudioType: @(0),
                                KWDefaultPregap: @(2),
                                KWUseCDText: @(NO),
                                KWDefaultMP3Bitrate: @(128),
                                KWDefaultMP3Mode: @(1),
                                KWCreateArtistFolders: @(YES),
                                KWCreateAlbumFolders: @(YES),
                                KWDefaultVideoType: @(0),
                                KWDefaultDVDSoundType: @(0),
                                KWCustomDVDVideoBitrate: @(NO),
                                KWDefaultDVDVideoBitrate: @(6000),
                                KWCustomDVDSoundBitrate: @(NO),
                                KWDefaultDVDSoundBitrate: @(448),
                                KWDVDForceAspect: @(0),
                                KWForceMPEG2: @(NO),
                                KWMuxSeperateStreams: @(NO),
                                KWRemuxMPEG2Streams: @(NO),
                                KWLoopDVD: @(NO),
                                KWUseTheme: @(YES),
                                KWDVDThemeName: @"Default",
                                KWDVDThemeFormat: @(0),
                                KWDefaultDivXSoundType: @(0),
                                KWCustomDivXVideoBitrate: @(NO),
                                KWDefaultDivXVideoBitrate: @(768),
                                KWCustomDivXSoundBitrate: @(NO),
                                KWDefaultDivxSoundBitrate: @(128),
                                KWCustomDivXSize: @(NO),
                                KWDefaultDivXWidth: @(320),
                                KWDefaultDivXHeight: @(240),
                                KWCustomFPS: @(NO),
                                KWDefaultFPS: @(25),
                                KWAllowMSMPEG4: @(NO),
                                KWForceDivX: @(NO),
                                KWSaveBorders: @(NO),
                                KWSaveBorderSize: @(0),
                                KWDebug: @(NO),
                                KWUseCustomFFMPEG: @(NO),
                                KWCustomFFMPEG: @"",
                                KWAllowOverBurning: @(NO),
                                KWDefaultDeviceIdentifier: @"",
                                KWBurnOptionsCompletionAction: DRBurnCompletionActionMount,
                                KWSavedPrefView: @"General",
                                KWLastTab: @"Data",
                                KWAdvancedFilesystems: @[@"HFS+"],
                                KWDVDTheme: @(0),
                                KWDefaultWindowWidth: @(430),
                                KWDefaultWindowHeight: @(436),
                                KWFirstRun: @(YES),
                                KWEncodingThreads: @(8),
                                KWSimulateBurn: @(NO),
                                KWDVDAspectMode: @(0)
                               };

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (instancetype)init
{
    self = [super init];
    
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter addObserver:self selector:@selector(openPreferencesAndAddTheme:) name:@"KWDVDThemeOpened" object:nil];
    [defaultCenter addObserver:self selector:@selector(changeInspector:) name:@"KWChangeInspector" object:nil];
}

- (void)dealloc 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Menu Methods

- (IBAction)showPreferences:(id)sender
{
    KWPreferences *preferences = [self preferences];
    if (preferences == nil)
    {
        preferences = [[KWPreferences alloc] init];
        [self setPreferences:preferences];
    }
    
    [preferences showPreferences];
}

- (IBAction)showInspector:(id)sender
{
    KWInspector *inspector = [self inspector];
    if (inspector == nil)
    {
	    inspector = [[KWInspector alloc] init];
        [self setInspector:inspector];
    }
    
    [inspector beginWindowForType:[self currentType] withObject:[self currentObject]];
}

- (IBAction)showRecorderInfo:(id)sender
{
    KWRecorderInfo *recorderInfo = [self recorderInfo];
    if (recorderInfo == nil)
    {
	    recorderInfo = [[KWRecorderInfo alloc] init];
        [self setRecorderInfo:recorderInfo];
    }

    [recorderInfo showRecorderInfoForDevice:[KWCommonMethods getCurrentDevice]];
}

- (IBAction)showDiscInfo:(id)sender
{
    KWDiscInfo *discInfo = [self discInfo];
    if (discInfo == nil)
    {
	    discInfo = [[KWDiscInfo alloc] init];
        [self setDiscInfo:discInfo];
    }

    [discInfo showDiskInfoForDevice:[KWCommonMethods getCurrentDevice]];
}

- (IBAction)openBurnSite:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://burn-osx.sourceforge.io"]];
}

- (IBAction)contactSupport:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedString(@"menu-help-mail-link", nil)]];
}

#pragma mark - Notification Methods

- (void)openPreferencesAndAddTheme:(NSNotification *)notif
{
    [self showPreferences:self];
    [[self preferences] addThemeAndShow:[notif object]];
}

- (void)changeInspector:(NSNotification *)notif
{
    NSString *currentObject = [notif object];
    NSString *currentType = [notif userInfo][@"Type"];

    [self setCurrentObject:currentObject];
    [self setCurrentType:currentType];

    [[self inspector] updateForType:currentType withObject:currentObject];
}

@end

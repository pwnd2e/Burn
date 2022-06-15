#import "KWEjecter.h"
#import "KWCommonMethods.h"

@interface KWEjecter()

@property (nonatomic, weak) IBOutlet NSPopUpButton *recorderPopUpButton;

@end

@implementation KWEjecter

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        [[NSBundle mainBundle] loadNibNamed:@"KWEjecter" owner:self topLevelObjects:nil];
    }
    
    return self;
}

#pragma mark - Main Methods

- (void)startEjectSheetForWindow:(NSWindow *)atachWindow forDevice:(DRDevice *)device
{
    NSPopUpButton *recorderPopUpButton = [self recorderPopUpButton];
    [recorderPopUpButton removeAllItems];
    
    for (DRDevice *listDevice in [DRDevice devices])
    {
	    [recorderPopUpButton addItemWithTitle:[listDevice displayName]];
    }
    
    [recorderPopUpButton selectItemWithTitle:[device displayName]];

    [NSApp beginSheet:[self window] modalForWindow:atachWindow modalDelegate:self didEndSelector: @selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
}

#pragma mark - Interface Methods

- (IBAction)close:(id)sender
{
    NSWindow *window = [self window];
    [[window sheetParent] endSheet:window];
}

- (IBAction)ejectDisc:(id)sender
{
    NSArray *devices = [DRDevice devices];
    NSInteger indexOfSelectedItem = [[self recorderPopUpButton] indexOfSelectedItem];
    
    if (indexOfSelectedItem >= [devices count] || (![devices[indexOfSelectedItem] ejectMedia]))
    {
        NSString *message = NSLocalizedString(@"Failed to eject", nil);
        NSString *information = NSLocalizedString(@"Could not eject media from the drive", nil);
    
        [KWCommonMethods standardAlertWithMessageText:message withInformationText:information withParentWindow:nil];
    }
    
    NSWindow *window = [self window];
    [[window sheetParent] endSheet:window];
}

@end

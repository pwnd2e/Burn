/* KWPreferences */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import "KWCommonMethods.h"

@interface KWPreferences : NSWindowController
{
    //Preferences window outlets
    IBOutlet id generalView;
    IBOutlet id burnerView;
    IBOutlet id dataView;
    IBOutlet id audioView;
    IBOutlet id videoView;
    IBOutlet id advancedView;
    
    //Save tabviewitems
    NSTabViewItem *savedAudioItem;
    
    //General outlets
    IBOutlet id temporaryFolderPopup;
    //Burner outlets
    IBOutlet id burnerPopup;
    IBOutlet id completionActionMatrix;
    IBOutlet id cdPopup;
    IBOutlet id dvdPopup;
    //Audio outlets
    IBOutlet id audioTab;
    IBOutlet id audioTabGeneral;
    IBOutlet id cdTextCheckbox;
    //Video outlets
    IBOutlet id videoTab;
    IBOutlet id themePopup;
    IBOutlet id previewImagePopup;
    IBOutlet id previewImageView;
    IBOutlet id previewWindow;
    
    NSArray *preferenceMappings;
    NSInteger dataViewHeight;
    NSMutableArray *themeNames;
}
//PrefPane actions
- (void)showPreferences;
- (IBAction)setPreferenceOption:(id)sender;

//Burner actions
- (IBAction)setBurner:(id)sender;
- (IBAction)setCompletionAction:(id)sender;
//Video actions
- (IBAction)setTheme:(id)sender;
//- (IBAction)addTheme:(id)sender;
//- (IBAction)deleteTheme:(id)sender;
- (IBAction)showPreview:(id)sender;
- (IBAction)setPreviewImage:(id)sender;
//Advanced actions
- (IBAction)chooseFFMPEG:(id)sender;

//Toolbar actions
- (void)toolbarAction:(id)object;
- (id)myViewWithIdentifier:(NSString *)identifier;

//Other actions
- (void)mediaChanged:(NSNotification *)notification;
- (void)resizeWindowOnSpotWithRect:(NSRect)aRect;
- (void)settingsChangedByOptionsMenuInMainWindow;
- (void)addThemeAndShow:(NSArray *)files;
- (void)setViewOptions:(NSArray *)views;
- (void)checkForExceptions:(NSButton *)button;

@end

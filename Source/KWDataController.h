#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import "KWProgressManager.h"
#import "KWBurner.h"
#import "KWDRFolder.h"
#import "KWTrackProducer.h"
#import "KWWindowController.h"

@class TreeNode;

@interface KWDataController : NSObject 
{    
    //Main Window
    IBOutlet KWWindowController *windowController;
    IBOutlet id    mainWindow;
    IBOutlet NSOutlineView    *outlineView;
    IBOutlet id    fileSystemPopup;
    IBOutlet id    discName;
    IBOutlet id    totalSizeText;
    IBOutlet id    iconView;
    
    //Options menu
    IBOutlet id optionsPopup;
    
    //New folder sheet
    IBOutlet id    newFolderSheet;
    IBOutlet id    folderName;
    //Add to local
    IBOutlet id folderIcon;
    
    //Advanced Sheet
    IBOutlet id    advancedSheet;
    IBOutlet NSMatrix *advancedCheckboxes;
    IBOutlet id    okSheet;
    
    //Disc creation
    IBOutlet id myDiscCreationController;
    
    //Variables
    TreeNode *treeData;
    NSArray *draggedNodes;
    NSString *lastSelectedItem;
    NSDictionary *discProperties;
    BOOL loadingBurnFile;
    NSArray *optionsMappings;
    NSMutableArray *temporaryFiles;
    NSArray *mainFilesystems;
    NSArray *advancedFilesystems;
}

//Main actions
- (IBAction)openFiles:(id)sender;
- (void)addDroppedOnIconFiles:(NSArray *)paths;
- (void)addFiles:(NSArray *)paths removeFiles:(BOOL)remove;
- (IBAction)deleteFiles:(id)sender;
- (IBAction)newVirtualFolder:(id)sender;
- (void)setTotalSize;
- (NSNumber *)totalSize;
- (void)updateFileSystem;
- (IBAction)dataPopupChanged:(id)sender;
- (IBAction)changeBaseName:(id)sender;

//Option menu actions
- (IBAction)accessOptions:(id)sender;
- (IBAction)setOption:(id)sender;

//Advanced Sheet actions
- (IBAction)filesystemSelectionChanged:(id)sender;
- (IBAction)okSheet:(id)sender;
- (IBAction)cancelSheet:(id)sender;
- (void)setupAdvancedSheet;

//Disc creation actions
- (void)burn:(id)sender;
- (void)saveImage:(id)sender;
- (id)myTrackWithErrorString:(NSString **)error;
- (BOOL)createVirtualFolder:(NSArray *)items atPath:(NSString *)path errorString:(NSString **)error;

//Save actions
- (void)saveDocument:(id)sender;
- (NSDictionary *)getSaveDictionary;
- (NSArray *)getFileArray:(NSArray *)items;
- (void)openBurnDocument:(NSString *)path;
- (void)loadSaveDictionary:(NSDictionary *)savedDictionary;
- (void)loadOutlineItems:(NSArray *)ar originalArray:(NSArray *)orAr;
- (NSDictionary *)saveDictionaryForObject:(DRFSObject *)object;
- (void)setPropertiesFor:(DRFSObject *)object fromDictionary:(NSDictionary *)dict;

//Other actions
@property (nonatomic, copy) NSString *diskName;
- (BOOL)isCombinable;
- (BOOL)isCompatible;
- (BOOL)isOnlyHFSPlus;
- (void)deleteTemporayFiles:(BOOL)needed;

//Inspector actions
- (void)volumeLabelSelected:(NSNotification *)notif;
- (void)outlineViewSelectionDidChange:(NSNotification *)notification;
- (NSArray *)selectedDRFSObjects;

//Outline actions
- (void)reloadOutlineView;
- (NSArray *)selectedDRFSObjects;
- (void)setOutlineViewState:(NSNotification *)notif;
- (IBAction)outlineViewAction:(id)sender;
- (NSInteger)numberOfRows;

@end

//
//  KWMediaListController.h
//  Burn
//
//  Created by Maarten Foukhar on 13-09-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KWProgressManager.h"
#import "KWConverter.h"
#import "KWBurner.h"
#import "KWMediaListController.h"
#import "KWTextField.h"
#import "KWWindowController.h"

@interface KWMediaListController : NSObject <NSTableViewDelegate, NSTableViewDataSource>
{    
    //Main Window
    IBOutlet KWWindowController *windowController;
    IBOutlet id mainWindow;
    IBOutlet id popupIcon;
    IBOutlet id nameTextField;
    IBOutlet id discLabel;
    IBOutlet id totalText;
    IBOutlet id tableViewPopup;
    IBOutlet NSTableView *tableView;
    IBOutlet id accessOptions;
    
    //Disc creation
    IBOutlet id myDiscCreationController;
    
    //Save View
    IBOutlet id saveView;
    IBOutlet id regionPopup;
    
    //Variables
    NSMutableArray *tableData;
    NSMutableArray *incompatibleFiles;
    NSMutableArray *protectedFiles;
    NSMutableArray *knownProtectedFiles;
    NSMutableArray *temporaryFiles;
    NSArray *allowedFileTypes;
    NSArray *optionsMappings;
    NSString *dvdFolderName;
    NSString *convertExtension;
    NSInteger convertKind;
    NSString *currentFileSystem;
    BOOL useRegion;
    BOOL isDVD;
    BOOL canBeReorderd;
    BOOL cancelAddingFiles;
    NSInteger currentDropRow;
    NSInteger currentType;
    NSInteger selectedTypeIndex;

    KWConverter *converter;
    id optionsPopup;
}

//Main actions
//Show a open panel to add files
- (IBAction)openFiles:(id)sender;
//Delete the selected row(s)
- (IBAction)deleteFiles:(id)sender;
//Bogusmethod used in subclass
- (void)addFile:(id)file isSelfEncoded:(BOOL)selfEncoded;
//Add a DVD-Folder and delete the rest
- (void)addDVDFolder:(NSString *)path;
//Check files in a seperate thread
- (void)checkFiles:(NSArray *)paths;
//Check if it is QuickTime protected file
- (BOOL)isProtected:(NSString *)path;

//Option menu actions
//Setup options menu and open the right popup
- (IBAction)accessOptions:(id)sender;
//Set option in the preferences
- (IBAction)setOption:(id)sender;

//Convert actions
//Convert files to path
- (void)convertFiles:(NSString *)path;
//Show an alert if needed (protected or no default files
- (void)showAlert;
//Show an alert if some files failed to be converted
- (void)showConvertFailAlert:(NSString *)errorString;

//Disc creation actions
//Burn the disc
- (void)burn:(id)sender;
//Save a image
- (void)saveImage:(id)sender;
//Bogusmethod used in subclass
- (id)myTrackWithBurner:(KWBurner *)burner errorString:(NSString **)error;
- (id)myTrackWithBurner:(KWBurner *)burner theme:(NSDictionary *)theme errorString:(NSString **)error;

//Save actions
//Open .burn document
- (void)openBurnDocument:(NSString *)path;
//Save .burn document
- (void)saveDocument:(id)sender;

//Tableview actions
//Bogusmethod used in subclass
- (IBAction)tableViewPopup:(id)sender;
//Method used in subclass to sort if needed
- (void)sortIfNeeded;

//Other actions
//Check for rows
- (NSInteger)numberOfRows;
//Set total size or time
- (void)setTotal;
//Get the total size
- (NSNumber *)totalSize;
//Find name in array of folders
- (DRFolder *)checkArray:(NSArray *)array forFolderWithName:(NSString *)name;
//Use some c to get the real path
- (NSString *)getRealPath:(NSString *)inPath;
//Return tableData to external objects
- (NSMutableArray *)myDataSource;

// Table view data source methods
- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;

@property (nonatomic, strong) NSString *discName;

- (void)deleteTemporayFiles:(BOOL)needed;

@end

//
//  KWMediaListController.m
//  Burn
//
//  Created by Maarten Foukhar on 13-09-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWMediaListController.h"
#import "KWCommonMethods.h"
#import "KWDiscCreator.h"

@implementation KWMediaListController

- (id)init
{
    self = [super init];

    // Storage room for files
    incompatibleFiles = [[NSMutableArray alloc] init];
    protectedFiles =  [[NSMutableArray alloc] init];
    
    // Known protected files can't be converted
    knownProtectedFiles = [[[NSArray alloc] initWithObjects:@"m4p",
                                                            @"m4b",
                                                            NSFileTypeForHFSTypeCode('M4P '),
                                                            NSFileTypeForHFSTypeCode('M4B '),
                                                            nil] mutableCopy];
    
    // Here we store our temporary files which will be deleted acording to the preferences set for deletion
    temporaryFiles = [[NSMutableArray alloc] init];
    
    // Set a starting row for dropping files in the list
    currentDropRow = -1;
    
    return self;
}

- (void)dealloc
{
    //  Stop listening to notifications from the default notification center
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
 
    [self setDiscName:NSLocalizedString(@"Untitled", nil)];
 
    // Notifications
    // Used to save the popups when the user selects this option in the preferences
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(tableViewPopup:)
                                                 name:@"KWTogglePopups"
                                               object:nil];
    // Prevent files being dropped when, for example, a sheet is open
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(setTableViewState:)
                                                 name:@"KWSetDropState"
                                               object:nil];
    // Updates the Inspector window with the new item selected in the list
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(tableViewSelectionDidChange:)
                                                 name:@"KWListSelected"
                                               object:tableView];
    // Updates the Inspector window to show information about the disc
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(volumeLabelSelected:)
                                                 name:@"KWDiscNameSelected"
                                               object:nameTextField];
    // How should our tableview update its sizes when adding and modifying files?
    [tableView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    // The user can drag files into the tableview (including iMovie files)
    [tableView registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,@"NSGeneralPboardType",
                                                                                       @"CorePasteboardFlavorType 0x6974756E", // "CorePasteboardFlavorType ITUN"
                                                                                       nil]];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

//Show a open panel to add files
- (IBAction)openFiles:(id)sender
{
    NSOpenPanel *sheet = [NSOpenPanel openPanel];
    [sheet setCanChooseFiles:YES];
    [sheet setCanChooseDirectories:YES];
    [sheet setAllowsMultipleSelection:YES];
    [sheet setAllowedFileTypes:allowedFileTypes];
    [sheet beginSheetModalForWindow:mainWindow completionHandler:^(NSModalResponse result)
    {
        if (result == NSModalResponseOK)
        {
            NSMutableArray *fileNames = [[NSMutableArray alloc] init];
            for (NSURL *url in [sheet URLs])
            {
                [fileNames addObject:[url path]];
            }
            
            [self checkFiles:fileNames];
        }
    }];
}

//Delete the selected row(s)
- (IBAction)deleteFiles:(id)sender
{    
    //Remove rows
    NSIndexSet *selectedRowIndexes = [tableView selectedRowIndexes];
    [tableData removeObjectsAtIndexes:selectedRowIndexes];
    
    //Update the tableview
    [tableView deselectAll:nil];
    [tableView reloadData];
    
    //Reset the total size
    [self setTotal];
}

//Bogusmethod used in subclass
- (void)addFile:(id)file isSelfEncoded:(BOOL)selfEncoded{}

//Add a DVD-Folder and delete the rest
- (void)addDVDFolder:(NSString *)path
{
    NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
    [rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
    [rowData setObject:path forKey:@"Path"];
    [rowData setObject:[KWCommonMethods makeSizeFromFloat:[KWCommonMethods calculateRealFolderSize:path] * 2048] forKey:@"Size"];
    [rowData setObject:[[[NSWorkspace sharedWorkspace] iconForFile:path] copy] forKey:@"Icon"];

    [tableData removeAllObjects];
    [tableData addObject:rowData];
    [tableView reloadData];
}

//Check files in a seperate thread
- (void)checkFiles:(NSArray *)paths
{
    cancelAddingFiles = NO;
    
    KWProgressManager *progressManager = [KWProgressManager sharedManager];
    [progressManager setTask:NSLocalizedString(@"Checking files...", nil)];
    [progressManager setStatus:NSLocalizedString(@"Scanning for files and folders", nil)];
    [progressManager setIconImage:[NSImage imageNamed:@"Burn"]];
    [progressManager setMaximumValue:0.0];
    [progressManager beginSheetForWindow:mainWindow completionHandler:^(NSModalResponse returnCode)
    {
        if (returnCode == NSModalResponseCancel)
        {
            self->cancelAddingFiles = YES;
        }
    }];
    
    [[[NSOperationQueue alloc] init] addOperationWithBlock:^
    {
        [self checkFilesInThread:paths];
    }];
}

//Check if it is QuickTime protected file
- (BOOL)isProtected:(NSString *)path
{
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return ([knownProtectedFiles containsObject:[[path pathExtension] lowercaseString]] || [knownProtectedFiles containsObject:NSFileTypeForHFSTypeCode([attributes[NSFileHFSTypeCode] longValue])]);
}

//Check if the file is folder or file, if it is folder scan it, when a file
//if it is a correct file
- (void)checkFilesInThread:(NSArray *)paths
{
    //Needed because we're in a new thread
    if ([paths count] == 1 && [[[[paths objectAtIndex:0] lastPathComponent] lowercaseString] isEqualTo:[dvdFolderName lowercaseString]] && isDVD)
    {
	    [self addDVDFolder:[paths objectAtIndex:0]];
    }
    else if ([paths count] == 1 && [[NSFileManager defaultManager] fileExistsAtPath:[[paths objectAtIndex:0] stringByAppendingPathComponent:dvdFolderName]] && isDVD)
    {
	    [self addDVDFolder:[[paths objectAtIndex:0] stringByAppendingPathComponent:dvdFolderName]];
	    [nameTextField setStringValue:[[paths objectAtIndex:0] lastPathComponent]];
    }
    else
    {
	    NSFileManager *defaultManager = [NSFileManager defaultManager];
        NSMutableArray *pathList = [self flattenTree:paths];
        NSMutableArray *files = [[pathList sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)] mutableCopy];
        
	    NSInteger numberOfFiles = [files count];
	    BOOL audioCD = [currentFileSystem isEqualTo:@"-audio-cd"];
    	    
	    if (audioCD)
        {
    	    [[KWProgressManager sharedManager] setMaximumValue:(CGFloat)numberOfFiles];
        }
        
	    for (NSInteger i = 0; i < [files count]; i ++)
	    {
            NSString *file = [files objectAtIndex:i];
     
    	    if (cancelAddingFiles == YES)
            {
	    	    break;
            }
        
    	    if (audioCD)
    	    {
	    	    NSString *fileName = [defaultManager displayNameAtPath:file];
	    	    [[KWProgressManager sharedManager] setStatus:[NSString stringWithFormat:NSLocalizedString(@"Processing: %@ (%i of %i)", nil), fileName, i + 1, numberOfFiles]];
    	    }
	    	    
            [self addFile:file isSelfEncoded:NO];
	    	    
    	    if (audioCD)
	    	    [[KWProgressManager sharedManager] setValue:(CGFloat)i + 1];
	    }
    }
    cancelAddingFiles = NO;
    currentDropRow = -1;
    [[KWProgressManager sharedManager] endSheetWithCompletion:^
    {
        [self showAlert];
    }];
}

- (NSMutableArray *)flattenTree:(NSArray *)droppedPaths
{
    NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:0];
    
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSInteger x = 0;
    for (x = 0; x < [droppedPaths count]; x ++)
    {
        if (cancelAddingFiles == YES)
            break;
        
        NSDirectoryEnumerator *enumer;
        NSString* pathName;
        NSString *realPath = [self getRealPath:[droppedPaths objectAtIndex:x]];
        BOOL fileIsFolder = NO;
        
        [defaultManager fileExistsAtPath:realPath isDirectory:&fileIsFolder];
        
        if (fileIsFolder)
        {
            enumer = [defaultManager enumeratorAtPath:realPath];
            while (pathName = [enumer nextObject])
            {
                if (cancelAddingFiles == YES)
                {
                    break;
                }
                
                NSString *realPathName = [self getRealPath:[realPath stringByAppendingPathComponent:pathName]];
                
                if (![self isProtected:realPathName])
                {
                    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:realPathName error:nil];
                    NSString *hfsType = NSFileTypeForHFSTypeCode([attributes[NSFileHFSTypeCode] longValue]);
                    
                    if ([allowedFileTypes containsObject:[[realPathName pathExtension] lowercaseString]] || [allowedFileTypes containsObject:hfsType])
                    {
                        [returnArray addObject:realPathName];
                    }
                }
            }
        }
        else
        {
            if (cancelAddingFiles == YES)
                break;
            
            if (![self isProtected:realPath])
            {
                NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:realPath error:nil];
                NSString *hfsType = NSFileTypeForHFSTypeCode([attributes[NSFileHFSTypeCode] longValue]);
                
                if ([allowedFileTypes containsObject:[[realPath pathExtension] lowercaseString]] || [allowedFileTypes containsObject:hfsType])
                {
                    [returnArray addObject:realPath];
                }
            }
        }
    }
    return returnArray;
}

/////////////////////////
// Option menu actions //
/////////////////////////

#pragma mark -
#pragma mark •• Option menu actions

//Setup options menu and open the right popup
- (IBAction)accessOptions:(id)sender
{    
    //Setup options menus
    NSInteger i = 0;
    for (i=0;i<[optionsPopup numberOfItems]-1;i++)
    {
	    [[optionsPopup itemAtIndex:i+1] setState:[[[NSUserDefaults standardUserDefaults] objectForKey:[optionsMappings objectAtIndex:i]] intValue]];
    }

    [optionsPopup performClick:self];
}

//Set option in the preferences
- (IBAction)setOption:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOffState) forKey:[optionsMappings objectAtIndex:[optionsPopup indexOfItem:sender] - 1]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/////////////////////
// Convert actions //
/////////////////////

#pragma mark -
#pragma mark •• Convert actions

//Convert files to path
- (void)convertFiles:(NSString *)path
{
    [[[NSOperationQueue alloc] init] addOperationWithBlock:^
    {
        [[KWDebugger sharedDebugger] clearLog];
    
        NSMutableArray *filePaths = [[NSMutableArray alloc] init];
        
        for (NSDictionary *fileDictionary in incompatibleFiles)
        {
            [filePaths addObject:fileDictionary[@"Path"]];
        }

        [incompatibleFiles removeAllObjects];

        converter = [[KWConverter alloc] init];
        
        NSDictionary *options = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:path, convertExtension, [[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultRegion"], [NSNumber numberWithInt:convertKind], nil]  forKeys:[NSArray arrayWithObjects:@"KWConvertDestination", @"KWConvertExtension", @"KWConvertRegion", @"KWConvertKind", nil]];
        NSString *errorString;
        
        NSInteger result = [converter batchConvert:filePaths withOptions:options errorString:&errorString];

        NSArray *succeededFiles = [NSArray arrayWithArray:[converter succesArray]];
        
        for (NSString *filePath in succeededFiles)
        {
            [self addFile:filePath isSelfEncoded:YES];
        }

        if (result == 0)
        {
            [[KWProgressManager sharedManager] endSheet];
        
            NSString *finishMessage;
        
            if ([filePaths count] > 1)
            {
                finishMessage = [NSString stringWithFormat:NSLocalizedString(@"Finished converting %ld files", nil),(long)[filePaths count]];
            }
            else
            {
                finishMessage = NSLocalizedString(@"Finished converting 1 file", nil);
            }
            
            NSString *firstPath = filePaths[0];
            NSImage *image = [[NSWorkspace sharedWorkspace] iconForFile:firstPath];
            [windowController showNotificationWithTitle:NSLocalizedString(@"Finished converting", nil) withMessage:finishMessage withImage:image];
        }
        else if (result == 1)
        {
            [[KWProgressManager sharedManager] endSheetWithCompletion:^
            {
                [self showConvertFailAlert:errorString];
            }];
        }
    }];
}

//Show an alert if needed (protected or no default files
- (void)showAlert
{
    if ([incompatibleFiles count] > 0)
    {
	    NSAlert *alert = [[NSAlert alloc] init];
	    [alert addButtonWithTitle:NSLocalizedString(@"Convert", nil)];
	    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
	    [[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\E"];
	    
	    NSString *convertString;
	    NSString *protectedString = @"";
	    
	    if ([protectedFiles count] > 1)
	    {
    	    protectedString = NSLocalizedString(@"\n(Note: there are a few protected mp4 files which can't be converted)", nil);
	    }
	    else if ([protectedFiles count] > 0)
	    {
    	    protectedString = NSLocalizedString(@"\n(Note: there is a protected mp4 file which can't be converted)", nil);
	    }
	    
	    if ([incompatibleFiles count] > 1)
	    {
    	    [alert setMessageText:NSLocalizedString(@"Some incompatible files", nil)];
    	    convertString = [NSString stringWithFormat:NSLocalizedString(@"Would you like to convert those files to %@?%@", nil),convertExtension,protectedString];
	    }
	    else
	    {
    	    [alert setMessageText:NSLocalizedString(@"One incompatible file", nil)];
    	    convertString = [NSString stringWithFormat:NSLocalizedString(@"Would you like to convert that file to %@?%@", nil),convertExtension,protectedString];
	    }
	    
	    [alert setInformativeText:convertString];
	    
	    [protectedFiles removeAllObjects];
//        [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        [alert beginSheetModalForWindow:mainWindow completionHandler:^(NSModalResponse response)
        {
            [self alertDidEnd:alert returnCode:response contextInfo:nil];
        }];
    }
    else if ([protectedFiles count] > 0)
    {
	    NSString *message;
	    NSString *information;
    	    
	    if ([protectedFiles count] > 1)
	    {
    	    message = NSLocalizedString(@"Some protected mp4 files", nil);
    	    information = NSLocalizedString(@"These files can't be converted", nil);
	    }
	    else
	    {
    	    message = NSLocalizedString(@"One protected mp4 file", nil);
    	    information = NSLocalizedString(@"This file can't be converted", nil);
	    }
	    
	    [protectedFiles removeAllObjects];
	    [KWCommonMethods standardAlertWithMessageText:message withInformationText:information withParentWindow:mainWindow];
    }
}

//Alert did end, whe don't need to do anything special, well releasing the alert we do, the user should
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[alert window] orderOut:self];
    
    if (returnCode == NSAlertFirstButtonReturn) 
    {
	    NSOpenPanel *sheet = [NSOpenPanel openPanel];
	    [sheet setCanChooseFiles: NO];
	    [sheet setCanChooseDirectories: YES];
	    [sheet setAllowsMultipleSelection: NO];
	    [sheet setCanCreateDirectories: YES];
	    [sheet setPrompt:NSLocalizedString(@"Choose", nil)];
	    [sheet setMessage:[NSString stringWithFormat:NSLocalizedString(@"Choose a location to save the %@ files", nil),convertExtension]];
	    
    	    if (useRegion)
    	    {
	    	    [regionPopup selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultRegion"] intValue]];
	    	    [sheet setAccessoryView:saveView];
    	    }
	    
        [sheet beginSheetModalForWindow:mainWindow completionHandler:^(NSModalResponse result)
        {
            if (result == NSModalResponseOK) 
            {
                if (useRegion)
                {
                    [[NSUserDefaults standardUserDefaults] setObject:[regionPopup objectValue] forKey:@"KWDefaultRegion"];
                }
                
                KWProgressManager *progressManager = [KWProgressManager sharedManager];
                [progressManager setTask:NSLocalizedString(@"Preparing to encode", nil)];
                [progressManager setStatus:NSLocalizedString(@"Checking file...", nil)];
                [progressManager setIconImage:[[NSWorkspace sharedWorkspace] iconForFileType:convertExtension]];
                [progressManager setMaximumValue:100.0 * [incompatibleFiles count]];
                [progressManager beginSheetForWindow:mainWindow];
                
                [self convertFiles:[[sheet URL] path]];
            }
            else
            {
                [incompatibleFiles removeAllObjects];
            }
        }];
    }
    else
    {
	    [incompatibleFiles removeAllObjects];
    }
}

//Show an alert if some files failed to be converted
- (void)showConvertFailAlert:(NSString *)errorString
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    
    if ([errorString rangeOfString:@"\n"].length > 0)
    {
        [alert setMessageText:NSLocalizedString(@"Burn failed to encode some files", nil)];
    }
    else
    {
        [alert setMessageText:NSLocalizedString(@"Burn failed to encode one file", nil)];
    }

    [alert setInformativeText:errorString];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
}

///////////////////////////
// Disc creation actions //
///////////////////////////

#pragma mark -
#pragma mark •• Disc creation actions

//Burn the disc
- (void)burn:(id)sender
{
    // Force to update the name
    [NSApp sendAction:[nameTextField action] to:[nameTextField target] from:nameTextField];
    
    [myDiscCreationController burnDiscWithName:[nameTextField stringValue] withType:currentType];
}

//Save a image
- (void)saveImage:(id)sender
{
    // Force to update the name
    [NSApp sendAction:[nameTextField action] to:[nameTextField target] from:nameTextField];

    [myDiscCreationController saveImageWithName:[self discName] withType:currentType withFileSystem:currentFileSystem];
}

//Bogusmethod used in subclass
- (id)myTrackWithBurner:(KWBurner *)burner errorString:(NSString **)error
{
    return [self myTrackWithBurner:burner theme:nil errorString:error];
}

- (id)myTrackWithBurner:(KWBurner *)burner theme:(NSDictionary *)theme errorString:(NSString **)error
{
    return nil;
}

//////////////////
// Save actions //
//////////////////

#pragma mark -
#pragma mark •• Save actions

//Open .burn document
- (void)openBurnDocument:(NSString *)path
{    
    NSDictionary *burnDocument = [NSDictionary dictionaryWithContentsOfFile:path];

    [tableViewPopup setObjectValue:[burnDocument objectForKey:@"KWSubType"]];

    NSDictionary *savedDictionary = [burnDocument objectForKey:@"KWProperties"];
    NSArray *savedArray = [savedDictionary objectForKey:@"Files"];
    
    [self tableViewPopup:self];
    NSMutableDictionary *rowData = [NSMutableDictionary dictionary];

    [tableData removeAllObjects];

	    NSInteger i;
	    for (i=0;i<[savedArray count];i++)
	    {
    	    NSDictionary *currentDictionary = [savedArray objectAtIndex:i];
    	    NSString *path = [currentDictionary objectForKey:@"Path"];

    	    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
    	    {
	    	    [rowData addEntriesFromDictionary:currentDictionary];
	    	    [rowData setObject:[[NSWorkspace sharedWorkspace] iconForFile:path] forKey:@"Icon"];
	    	    [tableData addObject:[rowData mutableCopy]];
	    	    [rowData removeAllObjects];
    	    }
	    }
	    
    [tableView reloadData];
    
    [self setTotal];

    [nameTextField setStringValue:[savedDictionary objectForKey:@"Name"]];
    
    [self sortIfNeeded];
}

//Save .burn document
- (void)saveDocument:(id)sender
{
    NSSavePanel *sheet = [NSSavePanel savePanel];
    [sheet setAllowedFileTypes:@[@"burn"]];
    [sheet setCanSelectHiddenExtension:YES];
    [sheet setMessage:NSLocalizedString(@"Choose a location to save the burn file", nil)];
    [sheet setNameFieldStringValue:[[nameTextField stringValue] stringByAppendingPathExtension:@"burn"]];
    [sheet beginSheetModalForWindow:mainWindow completionHandler:^(NSModalResponse result)
    {
        if (result == NSModalResponseOK) 
        {
            NSMutableArray *tempArray = [NSMutableArray arrayWithArray:tableData];
            NSMutableDictionary *tempDict;
        
            NSInteger i;
            for (i=0;i<[tempArray count];i++)
            {
                NSMutableDictionary *currentDict = [tempArray objectAtIndex:i];
                tempDict = [NSMutableDictionary dictionaryWithDictionary:currentDict];
                [tempDict removeObjectForKey:@"Icon"];
                [tempArray replaceObjectAtIndex:i withObject:tempDict];
            }
        
            NSDictionary *burnFileProperties = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:tempArray,[nameTextField stringValue], nil] forKeys:[NSArray arrayWithObjects:@"Files",@"Name", nil]];
            
            NSInteger type = currentType;
            
                if (currentType == 4)
                type = 2;
            
            NSDictionary *burnFile = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:type],[NSNumber numberWithInt:[tableViewPopup indexOfSelectedItem]],burnFileProperties, nil] forKeys:[NSArray arrayWithObjects:@"KWType",@"KWSubType",@"KWProperties", nil]];
            NSString *errorString;
            
            if ([KWCommonMethods writeDictionary:burnFile toFile:[[sheet URL] path] errorString:&errorString])
            {    
                if ([sheet isExtensionHidden])
                {
                    [[NSFileManager defaultManager] setAttributes:@{NSFileExtensionHidden: @([sheet isExtensionHidden])} ofItemAtPath:[[sheet URL] path] error:nil];
                }
            }
            else
            {
                [KWCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Failed to save Burn file", nil) withInformationText:errorString withParentWindow:mainWindow];
            }
        }
    }];
}

///////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

//Popup clicked
- (IBAction)tableViewPopup:(id)sender{}

- (void)sortIfNeeded{}

- (void)setTableViewState:(NSNotification *)notif
{
    if ([[notif object] boolValue] == YES)
	    [tableView registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,@"NSGeneralPboardType",
                                                                                           @"CorePasteboardFlavorType 0x6974756E",
                                                                                           nil]];
    else
	    [tableView unregisterDraggedTypes];
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{    
    return NO; 
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
    NSInteger result = NSDragOperationNone;

    if (op == NSTableViewDropAbove && canBeReorderd)
    {
	    result = NSDragOperationMove;
    }
    else
    {
	    [tv setDropRow:[tv numberOfRows] dropOperation:NSTableViewDropAbove];
	    result = NSTableViewDropAbove;
    }

    return (result);
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op
{
    NSPasteboard *pboard = [info draggingPasteboard];

    if ([[pboard types] containsObject:@"NSGeneralPboardType"] && canBeReorderd)
    {
	    NSArray *draggedRows = [pboard propertyListForType:@"KWDraggedRows"];
	    NSMutableArray *draggedObjects = [NSMutableArray array];
	    
	    NSInteger i;
	    for (i = 0; i < [draggedRows count]; i ++)
	    {
    	    NSInteger currentRow = [[draggedRows objectAtIndex:i] intValue];
    	    [draggedObjects addObject:[tableData objectAtIndex:currentRow]];
	    }
	    
	    NSInteger numberOfRows = [tableData count];
	    [tableData removeObjectsInArray:draggedObjects];
	    
	    BOOL shouldSelectRow = ([draggedRows count] > 1 || [tableView isRowSelected:[[draggedRows objectAtIndex:0] intValue]]);
	    
	    [tableView deselectAll:nil];
	    
	    for (i = 0; i < [draggedObjects count]; i ++)
	    {
    	    id object = [draggedObjects objectAtIndex:i];
    	    NSInteger destinationRow = row + i;
    	    
    	    if (row > numberOfRows)
    	    {
	    	    [tableData addObject:object];
    	    
	    	    destinationRow = [tableData count] - 1;
    	    }
    	    else
    	    {
	    	    if ([[draggedRows objectAtIndex:i] intValue] < destinationRow)
    	    	    destinationRow = destinationRow - [draggedRows count];
	    	    
	    	    [tableData insertObject:object atIndex:destinationRow];
    	    }
    	    
    	    if (shouldSelectRow)
	    	    [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:destinationRow] byExtendingSelection:YES];
	    }
    
	    [tableView reloadData];
    }
    else if ([[pboard types] containsObject:@"CorePasteboardFlavorType 0x6974756E"])
    {
	    NSArray *keys = [[[pboard propertyListForType:@"CorePasteboardFlavorType 0x6974756E"] objectForKey:@"Tracks"] allKeys];
	    NSMutableArray *fileList = [NSMutableArray array];
    
	    NSInteger i;
	    for (i=0;i<[keys count];i++)
	    {
    	    NSURL *url = [[NSURL alloc] initWithString:[[[[pboard propertyListForType:@"CorePasteboardFlavorType 0x6974756E"] objectForKey:@"Tracks"] objectForKey:[keys objectAtIndex:i]] objectForKey:@"Location"]];
    	    [fileList addObject:[url path]];
	    }
	    
	    [self checkFiles:fileList];
    }
    else
    {
	    if (canBeReorderd)
	    currentDropRow = row;

	    [self checkFiles:[pboard propertyListForType:NSFilenamesPboardType]];
    }

return YES;
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
    return [tableData count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([tableData count] > 0)
    {
        NSDictionary *rowData = [tableData objectAtIndex:row];
	    return [rowData objectForKey:[tableColumn identifier]];
    }
    else
    {
	    return nil;
    }
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *identifier = [tableColumn identifier];
    
    NSDictionary *rowData = [tableData objectAtIndex:row];
    id objectValue = [rowData objectForKey:[tableColumn identifier]];

    NSTableCellView *cellView = [tableView makeViewWithIdentifier:[tableColumn identifier] owner:self];
    if ([identifier isEqualToString:@"Icon"])
    {
        [[cellView imageView] setImage:objectValue];
    }
    else
    {
        [[cellView textField] setStringValue:objectValue];
    }
    
    return cellView;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSMutableDictionary *rowData = [tableData objectAtIndex:row];
    [rowData setObject:anObject forKey:[tableColumn identifier]];
}

- (BOOL)tableView:(NSTableView *)view writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
    if (canBeReorderd)
    {
	    id object = [tableData objectAtIndex:[[rows lastObject] intValue]];
	    NSData *data = [NSArchiver archivedDataWithRootObject:object];

	    [pboard declareTypes: [NSArray arrayWithObjects:@"NSGeneralPboardType",@"KWRemoveRowPboardType",@"KWDraggedRows", nil] owner:nil];
	    [pboard setData:data forType:@"NSGeneralPboardType"];
	    [pboard setString:[[rows lastObject] stringValue] forType:@"KWRemoveRowPboardType"];
	    [pboard setPropertyList:rows forType:@"KWDraggedRows"];
   
	    return YES;
    }
    else
    {
	    return NO;
    }
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

//Check for rows
- (NSInteger)numberOfRows
{
    return [tableData count];
}

//Set total size
- (void)setTotal
{
    [totalText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Total size: %@", nil), [KWCommonMethods makeSizeFromFloat:[[self totalSize] floatValue] * 2048]]];
    
    // TODO: somehow auto layout doesn't work for this NSTextField, so do what we normally would do on macOS 10.11 < in KWAutoLayoutTextField
    [totalText sizeToFit];
    [totalText setPreferredMaxLayoutWidth:[totalText frame].size.width];
}

//Calculate and return total size as float
- (NSNumber *)totalSize
{
    if ([tableData count] > 0 && [[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:[dvdFolderName lowercaseString]] && isDVD)
    {
	    return [NSNumber numberWithFloat:[KWCommonMethods calculateRealFolderSize:[[tableData objectAtIndex:0] objectForKey:@"Path"]]];
    }
    else
    {
	    DRFolder *discRoot = [DRFolder virtualFolderWithName:@"Untitled"];
        NSFileManager *defaultManager = [NSFileManager defaultManager];
    
	    NSInteger i;
	    DRFSObject *fsObj;
	    for (i=0;i<[tableData count];i++)
	    {
            NSString *path = [[tableData objectAtIndex:i] valueForKey:@"Path"];
            if ([defaultManager fileExistsAtPath:path])
            {
    	        fsObj = [DRFile fileWithPath:path];
            }
            else
            {
                fsObj = [DRFile virtualFileWithName:[path lastPathComponent] data:[NSData data]];
            }
    	    [discRoot addChild:fsObj];
	    }
        
        [discRoot setExplicitFilesystemMask:DRFilesystemInclusionMaskUDF];

	    return [NSNumber numberWithFloat:[[DRTrack trackForRootFolder:discRoot] estimateLength]];
    }
}

//Find name in array of folders
- (DRFolder *)checkArray:(NSArray *)array forFolderWithName:(NSString *)name
{
    NSInteger i;
    for (i=0;i<[array count];i++)
    {
	    DRFolder *currentFolder = [array objectAtIndex:i];
    
	    if ([[currentFolder baseName] isEqualTo:name])
    	    return currentFolder;
    }
    
    return nil;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    if (((aSelector == @selector(burn:) || aSelector == @selector(saveImage:) || aSelector == @selector(saveDocument:))) && [tableData count] == 0)
	    return NO;
	    
    return [super respondsToSelector:aSelector];
}

//Delete the temporary files used
- (void)deleteTemporayFiles:(BOOL)needed
{
    if (needed)
    {
	    NSInteger i;
	    for (i=0;i<[temporaryFiles count];i++)
	    {
    	    [KWCommonMethods removeItemAtPath:[temporaryFiles objectAtIndex:i]];
	    }
    }
    
    [temporaryFiles removeAllObjects];
}

//Use some c to get the real path
- (NSString *)getRealPath:(NSString *)inPath
{
    NSURL *url = [NSURL fileURLWithPath:inPath];
    
    CFErrorRef *errorRef = NULL;
    CFDataRef bookmark = CFURLCreateBookmarkDataFromFile (NULL, (__bridge CFURLRef)url, errorRef);
    if (bookmark == nil)
    {
        return inPath;
    }
    
    CFURLRef resolvedUrl = CFURLCreateByResolvingBookmarkData (NULL, bookmark, kCFBookmarkResolutionWithoutUIMask, NULL, NULL, false, errorRef);
    CFRelease(bookmark);
    return CFBridgingRelease(resolvedUrl);
}

//Return tableData to external objects
- (NSMutableArray *)myDataSource
{
    return tableData;
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
    NSInteger maxCharacters = 32;
    NSString *nameString = [nameTextField stringValue];
    
    if ([nameString length] > maxCharacters)
    {
	    NSBeep();
    
	    [nameTextField setStringValue:[nameString substringWithRange:NSMakeRange(0, maxCharacters)]];
    }
}

@end

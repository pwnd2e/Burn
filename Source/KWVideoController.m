//
//  KWVideoController.m
//  Burn
//
//  Created by Maarten Foukhar on 13-09-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWVideoController.h"
#import "KWWindowController.h"
#import "KWCommonMethods.h"
#import "KWTrackProducer.h"
#import "KWConstants.h"

@implementation KWVideoController

- (id)init
{
    self = [super init];
    
    //Setup our arrays for the options menus
    dvdOptionsMappings = [[NSArray alloc] initWithObjects:	    @"KWDVDForce43",    	    //0
	    	    	    	    	    	    	    	    @"KWForceMPEG2",    	    //1
	    	    	    	    	    	    	    	    @"KWMuxSeperateStreams",    //2
	    	    	    	    	    	    	    	    @"KWRemuxMPEG2Streams",	    //3
	    	    	    	    	    	    	    	    @"KWLoopDVD",	    	    //4
	    	    	    	    	    	    	    	    @"---",	    	    	    //5 >> Seperator
	    	    	    	    	    	    	    	    @"KWUseTheme",	    	    //6
	    	    	    	    	    	    	    	    nil];
    	    	    	    	    	    	    	    
    divxOptionsMappings = [[NSArray alloc] initWithObjects:	    @"KWForceDivX",	    	    //0
	    	    	    	    	    	    	    	    nil];

    //Here are our tableviews data stored
    vcdTableData = [[NSMutableArray alloc] init];
    svcdTableData = [[NSMutableArray alloc] init];
    dvdTableData = [[NSMutableArray alloc] init];
    divxTableData = [[NSMutableArray alloc] init];
    
    //Setup supported filetypes (QuickTime and ffmpeg)
    allowedFileTypes = [KWCommonMethods mediaTypes];
    
    //Set the dvd folder name (different for audio and video)
    dvdFolderName = @"VIDEO_TS";
    
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    //Set save popup title
    selectedTypeIndex = [[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultVideoType"] intValue];
    [tableViewPopup selectItemAtIndex:selectedTypeIndex];
    [self tableViewPopup:self];
    
    [popupIcon setImage:[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)]];
    
    [self updateRegionPopUp];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateRegionPopUp) name:KWRegionChanged object:nil];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)addFile:(id)file isSelfEncoded:(BOOL)selfEncoded
{
    NSString *path;
    NSMutableArray *chapters = [NSMutableArray array];
    
    if ([file isKindOfClass:[NSString class]])
    {
	    path = file;
    }
    else
    {
	    chapters = [file objectForKey:@"Chapters"];
	    path = [file objectForKey:@"Path"];
    }

    BOOL isWide;
    BOOL unsavediMovieProject = NO;
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    
    if ([path rangeOfString:@".iMovieProject"].length > 0)
    {
	    if (![[[path stringByDeletingLastPathComponent] lastPathComponent] isEqualTo:@"iDVD"])
	    unsavediMovieProject = YES;
    }

    //iMove projects can only be used if saved / contain a iDVD folder
    if (!unsavediMovieProject)
    {
    //Check if the file is allready the right file
    BOOL checkFile;
    converter = [[KWConverter alloc] init];

	    if (selectedTypeIndex == 0)
	    {
    	    checkFile = [converter isVCD:path];
	    }
	    else if (selectedTypeIndex == 1)
	    {
    	    checkFile = [converter isSVCD:path];
	    }
	    else if (selectedTypeIndex == 2)
	    {
    	    checkFile = (([converter isDVD:path isWideAspect:&isWide] && [standardDefaults boolForKey:@"KWForceMPEG2"] == NO) || selfEncoded == YES);
    	    
    	    if ([[path pathExtension] isEqualTo:@"m2v"] && [standardDefaults boolForKey:@"KWMuxSeperateStreams"] == YES)
	    	    checkFile = YES;
	    }
	    else if (selectedTypeIndex == 3)
	    {
    	    if (([converter isMPEG4:path] && [standardDefaults boolForKey:@"KWForceDivX"] == NO) || selfEncoded == YES)
	    	    checkFile = YES;
    	    else
	    	    checkFile = NO;
	    }
	    
	    NSFileManager *defaultManager = [NSFileManager defaultManager];
	    
	    //Go on if the file is the right type
	    if (checkFile == YES)
	    {
    	    NSString *filePath = path;
            NSDictionary *attributes = [defaultManager attributesOfItemAtPath:filePath error:nil];
    	    NSString *fileType = NSFileTypeForHFSTypeCode([attributes[NSFileHFSTypeCode] longValue]);
    
    	    //Remux MPEG2 files that are encoded by another app
    	    if (selfEncoded == NO && selectedTypeIndex == 2 && [standardDefaults boolForKey:@"KWRemuxMPEG2Streams"] == YES && ![[path pathExtension] isEqualTo:@"m2v"] && ![fileType isEqualTo:@"'MPG2'"])
    	    {
                NSString *fileName = [[[path lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"mpg"];
	    	    NSString *outputFile = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
                
                [temporaryFiles addObject:outputFile];
                converter = [[KWConverter alloc] init];
                KWProgressManager *progressManager = [KWProgressManager sharedManager];
                [progressManager setStatus:[NSLocalizedString(@"Remuxing: ", nil) stringByAppendingString:[defaultManager displayNameAtPath:outputFile]]];

                if ([converter remuxMPEG2File:path outPath:outputFile] == YES)
                    filePath = outputFile;
                else
                    filePath = @"";
                
                [progressManager setStatus:NSLocalizedString(@"Scanning for files and folders", nil)];
    	    }
    	    
    	    //If we have seperate m2v and mp3/ac2 files mux them, if set in the preferences
    	    if (([[path pathExtension] isEqualTo:@"m2v"] || [fileType isEqualTo:@"'MPG2'"]) && [[tableViewPopup title] isEqualTo:NSLocalizedString(@"DVD-Video", nil)] && [standardDefaults boolForKey:@"KWMuxSeperateStreams"] == YES)
    	    {
                NSString *fileName = [[[path lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"mpg"];
                NSString *outputFile = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
                
                [temporaryFiles addObject:outputFile];
            
                converter = [[KWConverter alloc] init];
        
                if ([converter canCombineStreams:path])
                {
                    KWProgressManager *progressManager = [KWProgressManager sharedManager];
                    [progressManager setStatus:[NSLocalizedString(@"Creating: ", nil) stringByAppendingString:[[[defaultManager displayNameAtPath:path] stringByDeletingPathExtension] stringByAppendingPathExtension:@"mpg"]]];

                    if ([converter combineStreams:path atOutputPath:outputFile] == YES)
                        filePath = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"mpg"];
                    else
                        filePath = @"";
            
                    [progressManager setStatus:NSLocalizedString(@"Scanning for files and folders", nil)];
                }
    	    }
	    
    	    //If none of the above rules are aplied add the file to the list
    	    if (![filePath isEqualTo:@""])
    	    {
	    	    NSDictionary *attributes = [defaultManager attributesOfItemAtPath:filePath error:nil];
    
	    	    NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
	    	    [rowData setObject:[defaultManager displayNameAtPath:filePath] forKey:@"Name"];
	    	    [rowData setObject:filePath forKey:@"Path"];
	    	    
	    	    if (selectedTypeIndex == 2)
	    	    {
    	    	    [rowData setObject:[NSNumber numberWithBool:isWide] forKey:@"WideScreen"];
    	    	    [rowData setObject:chapters forKey:@"Chapters"];
	    	    }
	    	    
	    	    float displaySize = [[attributes objectForKey:NSFileSize] floatValue];
	    	    
    	    	    if (selectedTypeIndex < 2)
    	    	    {
	    	    	    displaySize = (displaySize + 862288) / 2352 * 2048;
    	    	    }
	    	    
	    	    [rowData setObject:[KWCommonMethods makeSizeFromFloat:displaySize] forKey:@"Size"];
	    	    [rowData setObject:[[[NSWorkspace sharedWorkspace] iconForFile:filePath] copy] forKey:@"Icon"];
    	    
	    	    //If we're dealing with a Video_TS folder remve all rows
	    	    if ([tableData count] > 0 && [[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"video_ts"] && selectedTypeIndex == 3)
	    	    {
    	    	    [tableData removeAllObjects];
    	    	    currentDropRow = -1;
	    	    }
    	    
	    	    //Insert the item at current row
	    	    if (currentDropRow > -1)
	    	    {
    	    	    [tableData insertObject:rowData atIndex:currentDropRow];
    	    	    currentDropRow = currentDropRow + 1;
	    	    }
	    	    else
	    	    {
    	    	    [tableData addObject:rowData];
    	    
    	    	    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"Name" ascending:YES];
    	    	    [tableData sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	    	    }
          
                [[NSOperationQueue mainQueue] addOperationWithBlock:^
                {
                    //Reload our table view
                    [tableView reloadData];
                    //Set the total size in the main thread
                    [self setTotal];
                }];
    	    }
	    }
	    else 
	    {
    	    //Add the file to be encoded
    	    NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
    	    [rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
    	    [rowData setObject:path forKey:@"Path"];
    	    [incompatibleFiles addObject:rowData];
	    }
    }
}

///////////////////////////
// Disc creation actions //
///////////////////////////

#pragma mark -
#pragma mark •• Disc creation actions

//Set type temporary to video for burning
- (void)burn:(id)sender
{
    currentType = 2;
    [super burn:sender];
    [self tableViewPopup:self];
}

//Create a track for burning
- (id)myTrackWithBurner:(KWBurner *)burner theme:(NSDictionary *)theme errorString:(NSString **)error
{
    if (selectedTypeIndex == 2)
    {
        NSString *discName = [self discName];
        NSString *outputFolder = [NSTemporaryDirectory() stringByAppendingPathComponent:discName];
    
        [temporaryFiles addObject:outputFolder];

        NSInteger success = [self authorizeFolderAtPathIfNeededAtPath:outputFolder theme:theme errorString:&*error];

	    if (success == 0)
	    {
            KWProgressManager *progressManager = [KWProgressManager sharedManager];
            [progressManager setMaximumValue:0.0];
            [progressManager setStatus:NSLocalizedString(@"Preparing...", nil)];
    	    
    	    return [[KWTrackProducer alloc] getTrackForFolder:outputFolder ofType:3 withDiscName:discName];
	    }
	    else
	    {
    	    return [NSNumber numberWithInt:success];
	    }
    }
    else if (selectedTypeIndex == 0)
    {
	    return [[KWTrackProducer alloc] getTrackForVCDMPEGFiles:[self files] withDiscName:[self discName] ofType:4];
    }
    else if (selectedTypeIndex == 1)
    {
	    return [[KWTrackProducer alloc] getTrackForVCDMPEGFiles:[self files] withDiscName:[self discName] ofType:5];
    }

    if (selectedTypeIndex == 3)
    {
	    DRFolder *rootFolder = [DRFolder virtualFolderWithName:[self discName]];
	    
	    NSInteger i;
	    DRFSObject *fsObj;
	    for (i=0;i<[tableData count];i++)
	    {
    	    fsObj = [DRFile fileWithPath:[[tableData objectAtIndex:i] valueForKey:@"Path"]];
    	    [rootFolder addChild:fsObj];
	    }
	    
	    NSString *volumeName = [nameTextField stringValue];
	    
	    [rootFolder setExplicitFilesystemMask: (DRFilesystemInclusionMaskJoliet)];
	    [rootFolder setSpecificName:volumeName forFilesystem:DRJoliet];
	    [rootFolder setSpecificName:volumeName forFilesystem:DRISO9660LevelTwo];
    
	    if ([volumeName length] > 16)
	    {
    	    NSRange    jolietVolumeRange = NSMakeRange(0, 16);
    	    volumeName = [volumeName substringWithRange:jolietVolumeRange];
    	    [rootFolder setSpecificName:volumeName forFilesystem:DRJoliet];
	    }
    	    
	    return rootFolder;
    }

    return nil;
}

- (NSInteger)authorizeFolderAtPathIfNeededAtPath:(NSString *)path theme:(NSDictionary *)theme errorString:(NSString **)error
{
    NSInteger success;
    NSDictionary *currentData = [tableData objectAtIndex:0];
    
    if ([tableData count] > 0 && [[[currentData objectForKey:@"Name"] lowercaseString] isEqualTo:@"video_ts"])
    {
	    success = [KWCommonMethods createDVDFolderAtPath:path ofType:1 fromTableData:tableData errorString:&*error];
    }
    else
    {
	    NSInteger totalSize = [[self totalSize] floatValue];
     
        KWProgressManager *progressManager = [KWProgressManager sharedManager];
        [progressManager setMaximumValue:totalSize];
        [progressManager setTask:NSLocalizedString(@"Authoring DVD...", nil)];
        [progressManager setStatus:NSLocalizedString(@"Processing: ", nil)];
    
	    dvdAuthorizer = [[KWDVDAuthorizer alloc] init];
	    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	    if ([standardDefaults boolForKey:@"KWUseTheme"] == YES)
	    {
            success = [dvdAuthorizer createDVDMenuFiles:path withTheme:theme withFileArray:tableData withMaxProgressSize:totalSize / 2 withName:[self discName] errorString:&*error];
	    }
	    else
	    {
    	    success = [dvdAuthorizer createStandardDVDFolderAtPath:path withFileArray:tableData withMaxProgressSize:totalSize / 2 errorString:&*error];
	    }
    }

    return success;
}

///////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    
    if (selectedTypeIndex == 2 && [tableView selectedRow] > -1)
    {
	    if (![[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"video_ts"])
	    [defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWDVD",@"Type", nil]];
    }
    else
    {
	    [defaultCenter postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type", nil]];
    }
}

//Set the current tableview and tabledata to the selected popup item
- (void)getTableView
{
    NSInteger selrow = [tableViewPopup indexOfSelectedItem];
    currentType = 2;
    currentFileSystem = @"";
    convertExtension = @"mpg";
    useRegion = YES;
    isDVD = NO;
    canBeReorderd = YES;

    if (selrow == 0)
    {
	    tableData = vcdTableData;
	    currentType = 4;
	    currentFileSystem = @"-vcd";
	    convertKind = 1;
    }
    else if (selrow == 1)
    {
	    tableData = svcdTableData;
	    currentType = 4;
	    currentFileSystem = @"-svcd";
	    convertKind = 2;
    }
    else if (selrow == 2)
    {
	    tableData = dvdTableData;
	    isDVD = YES;
	    convertKind = 3;
	    optionsPopup = dvdOptionsPopup;
	    optionsMappings = dvdOptionsMappings;
    }
    else if (selrow == 3)
    {
	    tableData = divxTableData;
	    convertExtension = @"avi";
	    useRegion = NO;
	    canBeReorderd = NO;
	    convertKind = 4;
	    optionsPopup = divxOptionsPopup;
	    optionsMappings = divxOptionsMappings;
    }

    [tableView reloadData];
}

//Popup clicked
- (IBAction)tableViewPopup:(id)sender
{
    selectedTypeIndex = [tableViewPopup indexOfSelectedItem];
    
    [accessOptions setEnabled:(selectedTypeIndex == 2 || selectedTypeIndex == 3)];
    
    [self getTableView];
    
    [self setTotal];
    
    //Save the popup if needed
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWRememberPopups"] == YES)
    {
	    [[NSUserDefaults standardUserDefaults] setObject:[tableViewPopup objectValue] forKey:@"KWDefaultVideoType"];
    }
}

- (IBAction)changeRegion:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setInteger:[sender indexOfSelectedItem] forKey:KWDefaultRegion];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (void)updateRegionPopUp
{
    NSInteger region = [[NSUserDefaults standardUserDefaults] integerForKey:KWDefaultRegion];
    [videoRegionPopUp selectItemAtIndex:region];
}

- (NSNumber *)totalSize
{
    if (selectedTypeIndex > 1)
	    return [super totalSize];
    else
	    return [NSNumber numberWithFloat:[self totalSVCDSize] / 2048];
}

- (NSArray *)files
{
    NSMutableArray *files = [NSMutableArray array];

    NSInteger i;
    for (i=0;i<[tableData count];i++)
    {
	    [files addObject:[[tableData objectAtIndex:i] objectForKey:@"Path"]];
    }
    
    return files;
}

//Check if the disc can be combined
- (BOOL)isCombinable
{
    return ([tableData count] > 0 && [tableViewPopup indexOfSelectedItem] > 2);
}

- (IBAction)changeDiskName:(id)sender
{
    NSString *name = [nameTextField stringValue];
    [self setDiscName:name];
}

- (void)volumeLabelSelected:(NSNotification *)notif
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type", nil]];
}

- (float)totalSVCDSize
{
    NSInteger numberOfFiles = [tableData count];

    if (numberOfFiles == 0)
	    return 0;
    
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    float size = 1058400;
    
    NSInteger i;
    for (i = 0; i < [tableData count]; i ++)
    {
	    NSString *path = tableData[i][@"Path"];
	    NSDictionary *attributes = [defaultManager attributesOfItemAtPath:path error:nil];
	    float fileSize = [attributes[NSFileSize] floatValue] + 862288;
	    size = size + fileSize;
    }

    return size / 2352 * 2048 + 307200;
}

@end

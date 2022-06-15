//
//  KWAudioController.m
//  Burn
//
//  Created by Maarten Foukhar on 13-09-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWAudioController.h"
#import <MultiTag/MultiTag.h>
#import "KWWindowController.h"
#import "KWCommonMethods.h"
#import "KWTrackProducer.h"
#import <AVFoundation/AVFoundation.h>

@interface KWAudioController() <AVAudioPlayerDelegate>

@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@end

@implementation KWAudioController

- (id)init
{
    self = [super init];
    
    //Set the current type to audio
    currentType = 1;
    
    //No regions for audio discs
    useRegion = NO;
    
    //Set current filesystemtype to @"" >> not needed for audio
    currentFileSystem = @"";
    
    //Set the dvd folder name (different for audio and video)
    dvdFolderName = @"AUDIO_TS";

    //Setup our arrays for the options menus
    audioOptionsMappings = [[NSArray alloc] initWithObjects:    @"KWUseCDText",    //0
	    	    	    	    	    	    	    	    nil];
    	    	    	    	    	    	    	    
    mp3OptionsMappings = [[NSArray alloc] initWithObjects:	    @"KWCreateArtistFolders",    //0
	    	    	    	    	    	    	    	    @"KWCreateAlbumFolders",    //1
	    	    	    	    	    	    	    	    nil];

    //Here are our tableviews data stored
    audioTableData = [[NSMutableArray alloc] init];
    mp3TableData = [[NSMutableArray alloc] init];
    dvdTableData = [[NSMutableArray alloc] init];
    
    trackDictionary = [[NSMutableDictionary alloc] init];
    
    //Our tracks to burn
    
    display = 0;
    pause = NO;
    
    //Map track options to cue strings
    NSArray *cueStrings = [NSArray arrayWithObjects:    	    @"TITLE",
                                                                @"PERFORMER",
                                                                @"COMPOSER",
                                                                @"SONGWRITER",
                                                                @"ARRANGER",
                                                                @"MESSAGE",
                                                                @"REM GENRE",
                                                                @"REM PRIVATE",
                                                                nil];
    
    NSArray *trackStrings = [NSArray arrayWithObjects:    	    DRCDTextTitleKey,
                                                                DRCDTextPerformerKey,
                                                                DRCDTextComposerKey,
                                                                DRCDTextSongwriterKey,
                                                                DRCDTextArrangerKey,
                                                                DRCDTextSpecialMessageKey,
                                                                DRCDTextGenreKey,
                                                                DRCDTextClosedKey,
                                                                nil];

    cueMappings = [[NSDictionary alloc] initWithObjects:cueStrings forKeys:trackStrings];
    
    return self;
}

- (void)dealloc
{
    //Stop listening to notifications from the default notification center
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    //Stop the music
    [self stop:self];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [popupIcon setImage:[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericCDROMIcon)]];

    //Double clicking will start a song
    [tableView setDoubleAction:@selector(play:)];
    [tableView setTarget:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieEnded:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    //Set save popup title
    selectedTypeIndex = [[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultAudioType"] intValue];
    [tableViewPopup selectItemAtIndex:selectedTypeIndex];
    [self tableViewPopup:self];

    //Set the Inspector window to empty
    [[NSNotificationCenter defaultCenter] postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type", nil]];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

//Delete tracks from tracks array (Audio-CD only)
- (IBAction)deleteFiles:(id)sender
{    
    NSInteger selrow = [tableViewPopup indexOfSelectedItem];
    
    if (selrow == 0)
    {
        [self stop:sender];
        
        NSIndexSet *indexSet = [tableView selectedRowIndexes];
        
	    NSMutableArray *trackDictionaries = [NSMutableArray arrayWithArray:[cdtext trackDictionaries]];
        NSMutableIndexSet *removeIndexSet = [indexSet mutableCopy];
        [removeIndexSet shiftIndexesStartingAtIndex:0 by:1];
        [trackDictionaries removeObjectsAtIndexes:removeIndexSet];
        [cdtext setTrackDictionaries:trackDictionaries];
        
        for (NSDictionary *dictionary in [audioTableData objectsAtIndexes:indexSet])
        {
            NSString *trackID = dictionary[@"TrackID"];
            trackDictionary[trackID] = nil;
        }
    }
    
    [super deleteFiles:sender];
}

//Add the file to the tableview
- (void)addFile:(id)file isSelfEncoded:(BOOL)selfEncoded
{
    NSString *path;
    if ([file isKindOfClass:[NSString class]])
	    path = file;
    else
	    path = [file objectForKey:@"Path"];

    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSDictionary *attributes = [defaultManager attributesOfItemAtPath:path error:nil];
    NSString *fileType = NSFileTypeForHFSTypeCode([attributes[NSFileHFSTypeCode] longValue]);

    if (selectedTypeIndex == 1 && ![[[path pathExtension] lowercaseString] isEqualTo:@"mp3"] && ![fileType isEqualTo:@"'MPG3'"] && ![fileType isEqualTo:@"'Mp3 '"] && ![fileType isEqualTo:@"'MP3 '"])
    {
	    NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
	    [rowData setObject:[defaultManager displayNameAtPath:path] forKey:@"Name"];
	    [rowData setObject:path forKey:@"Path"];
	    [incompatibleFiles addObject:rowData];
    }
    else if (selectedTypeIndex == 2 && ![[[path pathExtension] lowercaseString] isEqualTo:@"wav"] && ![fileType isEqualTo:@"'WAVE'"] && ![fileType isEqualTo:@"'.WAV'"] && ![[[path pathExtension] lowercaseString] isEqualTo:@"flac"])
    {
        NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
        [rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
        [rowData setObject:path forKey:@"Path"];
        [incompatibleFiles addObject:rowData];
    }
    else
    {
	    NSMutableDictionary *rowData = [NSMutableDictionary dictionary];

	    [self stop:self];

	    float time = [self getMovieDuration:path];
    
	    [rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
	    [rowData setObject:path forKey:@"Path"];
	    
	    id sizeObject;
	    if (selectedTypeIndex == 0)
        {
    	    sizeObject = [KWCommonMethods formatTime:time];
        }
	    else
        {
    	    sizeObject = [KWCommonMethods makeSizeFromFloat:[attributes[NSFileSize] floatValue]];
        }   
	    
	    [rowData setObject:sizeObject forKey:@"Size"];
	    [rowData setObject:[[NSNumber numberWithInt:time] stringValue] forKey:@"RealTime"];
	    [rowData setObject:[[NSWorkspace sharedWorkspace] iconForFile:path] forKey:@"Icon"];
     
        if ([tableData count] > 0 && [[[[tableData objectAtIndex:0] objectForKey:@"Name"] lowercaseString] isEqualTo:@"audio_ts"] && selectedTypeIndex == 2)
        {
            [previousButton setEnabled:YES];
            [playButton setEnabled:YES];
            [nextButton setEnabled:YES];
            [stopButton setEnabled:YES];
        
            [tableData removeAllObjects];
            currentDropRow = -1;
        }
	    
	    if (selectedTypeIndex == 1)
	    {
    	    currentDropRow = -1;
	    
    	    MultiTag *soundTag = [[MultiTag alloc] initWithFile:path];
    	    [rowData setObject:[soundTag getTagArtist] forKey:@"Artist"];
    	    [rowData setObject:[soundTag getTagAlbum] forKey:@"Album"];
	    }

	    if (selectedTypeIndex == 0)
	    {
    	    DRTrack    *track = [[KWTrackProducer alloc] getAudioTrackForPath:path];
    	    NSNumber *pregap = [[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultPregap"];
    	    unsigned preGapLengthInFrames = (unsigned)([pregap floatValue] * 75.0);
    	    
    	    NSMutableDictionary *trackProperties = [NSMutableDictionary dictionaryWithDictionary:[track properties]];
    	    [trackProperties setObject:[NSNumber numberWithUnsignedInt:preGapLengthInFrames] forKey:DRPreGapLengthKey];
    	    [track setProperties:trackProperties];
            NSString *trackKey = [[NSUUID UUID] UUIDString];
            trackDictionary[trackKey] = track;
            rowData[@"TrackID"] = trackKey;
    	    
    	    if ([[[path pathExtension] lowercaseString] isEqualTo:@"mp3"] || [[[path pathExtension] lowercaseString] isEqualTo:@"m4a"])
    	    {
	    	    MultiTag *soundTag = [[MultiTag alloc] initWithFile:path];
	    	    
	    	    NSString *album = [soundTag getTagAlbum];

	    	    if (!cdtext)
	    	    {
    	    	    cdtext = [DRCDTextBlock cdTextBlockWithLanguage:@"" encoding:DRCDTextEncodingISOLatin1Modified];
    
    	    	    [cdtext setObject:[soundTag getTagArtist] forKey:DRCDTextPerformerKey ofTrack:0];
	    	    
    	    	    NSArray *genres = [soundTag getTagGenreNames];
    	    	    if ([genres count] > 0)
    	    	    {
	    	    	    [cdtext setObject:[NSNumber numberWithInt:0] forKey:DRCDTextGenreCodeKey ofTrack:0];
	    	    	    [cdtext setObject:[genres objectAtIndex:0] forKey:DRCDTextGenreKey ofTrack:0];
    	    	    }
    	    	    
    	    	    [cdtext setObject:album forKey:DRCDTextTitleKey ofTrack:0];
              
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^
                    {
    	    	        [nameTextField setStringValue:album];
                    }];
                }
	    	    else
	    	    {
    	    	    if (![[cdtext objectForKey:DRCDTextPerformerKey ofTrack:0] isEqualTo:[soundTag getTagArtist]])
	    	    	    [cdtext setObject:@"" forKey:DRCDTextPerformerKey ofTrack:0];
	    	    
    	    	    NSArray *genres = [soundTag getTagGenreNames];
    	    	    if ([genres count] > 0)
    	    	    {
	    	    	    if (![[cdtext objectForKey:DRCDTextGenreKey ofTrack:0] isEqualTo:[genres objectAtIndex:0]])
    	    	    	    [cdtext setObject:@"" forKey:DRCDTextGenreKey ofTrack:0];
    	    	    }
    	    	    
    	    	    if (![[cdtext objectForKey:DRCDTextTitleKey ofTrack:0] isEqualTo:album])
    	    	    {
	    	    	    [cdtext setObject:NSLocalizedString(@"Untitled", nil) forKey:DRCDTextTitleKey ofTrack:0];
               
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^
                        {
                            [nameTextField setStringValue:NSLocalizedString(@"Untitled", nil)];
                        }];
    	    	    }
	    	    }
    	    
	    	    NSInteger lastTrack = [tableData count] + 1;

	    	    [cdtext setObject:[soundTag getTagTitle] forKey:DRCDTextTitleKey ofTrack:lastTrack];
	    	    [cdtext setObject:[soundTag getTagArtist] forKey:DRCDTextPerformerKey ofTrack:lastTrack];
	    	    [cdtext setObject:[soundTag getTagComposer] forKey:DRCDTextComposerKey ofTrack:lastTrack];
	    	    [cdtext setObject:[soundTag getTagComments] forKey:DRCDTextSpecialMessageKey ofTrack:lastTrack];
	    	    
    	    }
    	    else
    	    {
	    	    if (!cdtext)
	    	    {
    	    	    cdtext = [DRCDTextBlock cdTextBlockWithLanguage:@"" encoding:DRCDTextEncodingISOLatin1Modified];
    	    	    [cdtext setObject:NSLocalizedString(@"Untitled", nil) forKey:DRCDTextTitleKey ofTrack:0];
	    	    }
          
                NSInteger lastTrack = [tableData count] + 1;
                [cdtext setObject:@"" forKey:DRCDTextTitleKey ofTrack:lastTrack];
    	    }
	    }
    	    
	    if (currentDropRow > -1)
	    {
    	    [tableData insertObject:[rowData copy] atIndex:currentDropRow];
    	    currentDropRow = currentDropRow + 1;
	    }
	    else
	    {
    	    [tableData addObject:[rowData copy]];
	    }
  
        [self sortIfNeeded];
        
        // Perform on the main thread
        [[NSOperationQueue mainQueue] addOperationWithBlock:^
        {
            [self->tableView reloadData];
            [self setTotal];
        }];
    }
}

- (IBAction)changeDiscName:(id)sender
{
    NSString *name = [nameTextField stringValue];
    [self setDiscName:name];

    NSInteger selrow = [tableViewPopup indexOfSelectedItem];

    if (selrow == 0)
    {
        [cdtext setObject:name forKey:DRCDTextTitleKey ofTrack:0];
    }
}

///////////////////////////
// Disc creation actions //
///////////////////////////

#pragma mark -
#pragma mark •• Disc creation actions

//Create a track for burning
- (id)myTrackWithBurner:(KWBurner *)burner errorString:(NSString **)error
{
    //Stop the music before burning
    [self stop:self];
   
    if (selectedTypeIndex == 2)
    {
        NSString *discName = [self discName];
        NSString *outputFolder = [NSTemporaryDirectory() stringByAppendingPathComponent:discName];
        
        if (outputFolder)
        {
            [temporaryFiles addObject:outputFolder];
    
            NSInteger succes = [self authorizeFolderAtPathIfNeededAtPath:outputFolder errorString:&*error];
    
            if (succes == 0)
            {
                return [[KWTrackProducer alloc] getTrackForFolder:outputFolder ofType:7 withDiscName:discName];
            }
            else
                return @(succes);
        }
        else
        {
            return @(2);
        }
    }
	    
    if (selectedTypeIndex == 1)
    {
	    DRFolder *discRoot = [DRFolder virtualFolderWithName:[self discName]];
    
	    NSInteger i;
	    for (i=0;i<[tableData count];i++)
	    {
    	    DRFolder *myFolder = discRoot;
    	    
    	    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCreateArtistFolders"] boolValue] || [[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCreateAlbumFolders"] boolValue])
    	    {
	    	    NSString *path = [[tableData objectAtIndex:i] valueForKey:@"Path"];
	    	    MultiTag *soundTag = [[MultiTag alloc] initWithFile:path];
    	    
	    	    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCreateArtistFolders"] boolValue] && ![[soundTag getTagArtist] isEqualTo:@""])
	    	    {
    	    	    DRFolder *artistFolder = [self checkArray:[myFolder children] forFolderWithName:[soundTag getTagArtist]];
    	    	    
    	    	    if (!artistFolder)
                    {
	    	    	    artistFolder = [DRFolder virtualFolderWithName:[soundTag getTagArtist]];
    	    	        [myFolder addChild:artistFolder];
                    }
	    	    
    	    	    myFolder = artistFolder;
	    	    }
	    	    
	    	    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"KWCreateAlbumFolders"] boolValue] && ![[soundTag getTagAlbum] isEqualTo:@""])
	    	    {
    	    	    DRFolder *albumFolder = [self checkArray:[myFolder children] forFolderWithName:[soundTag getTagAlbum]];
    	    	    
    	    	    if (!albumFolder)
                    {
	    	    	    albumFolder = [DRFolder virtualFolderWithName:[soundTag getTagAlbum]];
    	    	        [myFolder addChild:albumFolder];
    	    	    }
                    
    	    	    myFolder = albumFolder;
	    	    }
    	    
    	    }
    	    
    	    [myFolder addChild:[DRFile fileWithPath:[[tableData objectAtIndex:i] valueForKey:@"Path"]]];
	    }
	    	    
	    [discRoot setExplicitFilesystemMask: (DRFilesystemInclusionMaskJoliet)];

	    return discRoot;
    }
    else
    {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWUseCDText"] == YES && cdtext)
        {
            NSMutableDictionary *burnProperties = [NSMutableDictionary dictionary];
        
            [burnProperties setObject:cdtext forKey:DRCDTextKey];
        
            id mcn = [cdtext objectForKey:DRCDTextMCNISRCKey ofTrack:0];
            if (mcn)
            {
                [burnProperties setObject:mcn forKey:DRMediaCatalogNumberKey];
            }
        
            [burner setExtraBurnProperties:burnProperties];
        }
        
        NSMutableArray *tracks = [[NSMutableArray alloc] init];
        for (NSDictionary *dictionary in audioTableData)
        {
            [tracks addObject:trackDictionary[dictionary[@"TrackID"]]];
        }
	    
	    return tracks;
    }

    return nil;
}

- (NSInteger)authorizeFolderAtPathIfNeededAtPath:(NSString *)path errorString:(NSString **)error;
{
    NSInteger succes;
    NSDictionary *currentData = [tableData objectAtIndex:0];
    
    if ([tableData count] > 0 && [[[currentData objectForKey:@"Name"] lowercaseString] isEqualTo:@"audio_ts"])
    {
        succes = [KWCommonMethods createDVDFolderAtPath:path ofType:0 fromTableData:tableData errorString:&*error];
    }
    else
    {
        float maximumSize = [[self totalSize] floatValue];
        
        KWProgressManager *progressManager = [KWProgressManager sharedManager];
        [progressManager setMaximumValue:maximumSize];
    
        NSMutableArray *files = [NSMutableArray array];

        NSInteger i;
        for (i=0;i<[tableData count];i++)
        {
            [files addObject:[[tableData objectAtIndex:i] objectForKey:@"Path"]];
        }
        
        [progressManager setTask:NSLocalizedString(@"Authoring DVD...",nil)];
        [progressManager setStatus:NSLocalizedString(@"Generating DVD folder",nil)];
    
        DVDAuthorizer = [[KWDVDAuthorizer alloc] init];
        succes = [DVDAuthorizer createStandardDVDAudioFolderAtPath:path withFiles:files errorString:&*error];
    }
    
    return succes;
}

///////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger selrow = [tableViewPopup indexOfSelectedItem];

    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    
    if (selrow == 0)
    {
	    if ([tableView selectedRow] == -1)
    	    [defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioDisc",@"Type", nil]];
	    else
    	    [defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudio",@"Type", nil]];
    }
    else if (selrow == 1)
    {
	    if ([tableView selectedRow] == -1)
    	    [defaultCenter postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type", nil]];
	    else
    	    [defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioMP3",@"Type", nil]];
    }
}

//Set the current tableview and tabledata to the selected popup item
- (void)getTableView
{
    NSInteger selrow = [tableViewPopup indexOfSelectedItem];
    
    if (allowedFileTypes)
    {
	    allowedFileTypes = nil;
    }

    if (selrow == 0)
    {
	    tableData = audioTableData;

	    allowedFileTypes = [KWCommonMethods quicktimeTypes];
    }
    else
    {
        if (selrow == 1)
        {
            tableData = mp3TableData;
        }
        else
        {
            tableData = dvdTableData;
        }

	    allowedFileTypes = [KWCommonMethods mediaTypes];
    }

    [tableView reloadData];
}

//Popup clicked
- (IBAction)tableViewPopup:(id)sender
{
    selectedTypeIndex = [tableViewPopup indexOfSelectedItem];
    canBeReorderd = YES;
    isDVD = NO;
    currentFileSystem = @"";

    //Stop playing
    [self stop:self];

    [self getTableView];
    [[[tableView tableColumnWithIdentifier:@"Size"] headerCell] setStringValue:NSLocalizedString(@"Size", nil)];

    //Set the icon, tabview and textfield
    if (selectedTypeIndex == 0)
    {
	    currentFileSystem = @"-audio-cd";
    
	    optionsPopup = audioOptionsPopup;
	    optionsMappings = audioOptionsMappings;
    
	    [[[tableView tableColumnWithIdentifier:@"Size"] headerCell] setStringValue:NSLocalizedString(@"Time", nil)];
	    
	    [accessOptions setEnabled:YES];
    }
    else if (selectedTypeIndex == 1)
    {
	    convertExtension = @"mp3";
	    convertKind = 5;
	    canBeReorderd = NO;
    
	    optionsPopup = mp3OptionsPopup;
	    optionsMappings = mp3OptionsMappings;
    
	    [accessOptions setEnabled:YES];
    }
    else if (selectedTypeIndex == 2)
    {
        convertExtension = @"wav";
        convertKind = 6;
        isDVD = YES;
        
        [accessOptions setEnabled:NO];
    }
    
    //get the tableview and set the total time
    [self setDisplay:self];
    
    //Save the popup if needed
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    if ([standardDefaults boolForKey:@"KWRememberPopups"] == YES)
    {
	    [standardDefaults setObject:[tableViewPopup objectValue] forKey:@"KWDefaultAudioType"];
    }
    
    if (tableView == [mainWindow firstResponder])
    {
        NSNotification *notication = [[NSNotification alloc] initWithName:NSTableViewSelectionDidChangeNotification object:tableView userInfo:@{}];
	    [self tableViewSelectionDidChange:notication];
    }
    else
    {
	    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    
	    if (selectedTypeIndex == 0)
        {
    	    [defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioDisc", @"Type", nil]];
        }
	    else if (selectedTypeIndex == 1)
        {
    	    [defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioMP3Disc", @"Type", nil]];
        }
        else
        {
            [defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty", @"Type", nil]];
        }
    }
}

- (void)sortIfNeeded
{
    if (selectedTypeIndex == 1)
    {
	    NSMutableArray *sortDescriptors = [NSMutableArray array];
	    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
	    if ([[defaults objectForKey:@"KWCreateAlbumFolders"] boolValue])
    	    [sortDescriptors addObject:[[NSSortDescriptor alloc] initWithKey:@"Album" ascending:YES]];
	    
	    if ([[defaults objectForKey:@"KWCreateArtistFolders"] boolValue])
    	    [sortDescriptors addObject:[[NSSortDescriptor alloc] initWithKey:@"Artist" ascending:YES]];	    
    	    	    
	    [sortDescriptors addObject:[[NSSortDescriptor alloc] initWithKey:@"Name" ascending:YES]];
	    
	    [tableData sortUsingDescriptors:sortDescriptors];
    }
}

////////////////////
// Player actions //
////////////////////

#pragma mark -
#pragma mark •• Player actions

- (IBAction)play:(id)sender
{
    //Check if there are some rows, we really need those
    if ([tableData count] > 0)
    {
        //If image is pause.png the movie has already started so we should pause it, but if the message is
        //send by the tableview the user wants a other song
        if ((![playButton isPlaying]) || sender == tableView)
        {
            //If the user click pause before we should resume, else we should start the selected,
            //double-clicked or first song
            if (pause == NO || sender == tableView)
            {
                AVAudioPlayer *audioPlayer = [self audioPlayer];
                if (audioPlayer != nil)
                {
                   [audioPlayer stop];
                }

                NSInteger selrow = [tableView selectedRow];

                //Check if a row is selected if not play first song
                if (selrow > -1)
                    playingSong = selrow;
                else
                    playingSong = 0;

                NSURL *url = [[NSURL alloc] initFileURLWithPath:tableData[playingSong][@"Path"]];
                audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
                [audioPlayer setDelegate:self];
                [self setAudioPlayer:audioPlayer];
                
                [audioPlayer prepareToPlay];
                [audioPlayer play];

                if (display == 0)
                    [self setDisplay:self];

                displayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateDisplay:) userInfo:nil repeats: YES];
                [playButton setPlaying:YES];
            }
            else
            //Resume
            {
                [[self audioPlayer] play];
                displayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateDisplay:) userInfo:nil repeats: YES];
                [playButton setPlaying:YES];
            }
        }
        else
        //Pause
        {
            [[self audioPlayer] stop];
            [displayTimer invalidate];
            pause = YES;
            [playButton setPlaying:NO];
        }
    }
}

- (IBAction)stop:(id)sender
{
    //Check if there is an audio player, so we have something to stop
    AVAudioPlayer *audioPlayer = [self audioPlayer];
    if (audioPlayer != nil)
    {
        [audioPlayer stop];
        audioPlayer = nil;
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^
        {
            if ([playButton isPlaying])
            {
                [displayTimer invalidate];
            }

            display = 2;
            pause = NO;
            [playButton setPlaying:NO];
            playingSong = 0;
            
            [self setDisplay:self];
        }];
    }
}

- (IBAction)back:(id)sender
{
    AVAudioPlayer *audioPlayer = [self audioPlayer];
    if (audioPlayer != nil)
    {
        //Only fire if the player is already playing
        if ([playButton isPlaying])
        {
            //If we're not at number 1 go back
            if (playingSong - 1 > - 1)
            {
                //Stop previous movie
                if (audioPlayer != nil)
                {
                    [audioPlayer stop];
                }
                
                playingSong --;
                NSURL *url = [[NSURL alloc] initFileURLWithPath:tableData[playingSong][@"Path"]];
                audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
                [audioPlayer setDelegate:self];
                [audioPlayer play];
                [self setAudioPlayer:audioPlayer];
            }
            else if (playingSong == 0)
            {
                [audioPlayer setCurrentTime:0];
            }
        }
        else
        {
            if (playingSong - 1 > - 1)
            {
                playingSong --;
                NSURL *url = [[NSURL alloc] initFileURLWithPath:tableData[playingSong][@"Path"]];
                audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
                [audioPlayer setDelegate:self];
                [audioPlayer play];
                [self setAudioPlayer:audioPlayer];
                
                [self setDisplay:self];
            }
            else
            {
                [audioPlayer setCurrentTime:0];
            }
        }
    }
}

- (IBAction)forward:(id)sender
{
    AVAudioPlayer *audioPlayer = [self audioPlayer];
    if (audioPlayer != nil)
    {
        //Only fire if the player is already playing
        if ([playButton isPlaying])
        {
            //If the're more tracks go to next
            if (playingSong + 1 < [tableData count])
            {
                //Stop previous movie
                if (audioPlayer != nil)
                {
                    [audioPlayer stop];
                }
                
                playingSong ++;
                NSURL *url = [[NSURL alloc] initFileURLWithPath:tableData[playingSong][@"Path"]];
                audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
                [audioPlayer setDelegate:self];
                [audioPlayer play];
                [self setAudioPlayer:audioPlayer];
            }
        }
        else
        {
            if (playingSong + 1 < [tableData count])
            {
                playingSong ++;
                NSURL *url = [[NSURL alloc] initFileURLWithPath:tableData[playingSong][@"Path"]];
                audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
                [audioPlayer setDelegate:self];
                [audioPlayer play];
                [self setAudioPlayer:audioPlayer];
                
                [self setDisplay:self];
            }
        }
    }
}

//When the movie has stopped there will be a notification, we go to the next song if there is any
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if (playingSong + 1 < [tableData count])
    {
        AVAudioPlayer *audioPlayer = [self audioPlayer];
        //Stop previous movie
        if (audioPlayer != nil)
        {
            [audioPlayer stop];
        }
        
        playingSong ++;
        NSURL *url = [[NSURL alloc] initFileURLWithPath:tableData[playingSong][@"Path"]];
        audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
        [audioPlayer setDelegate:self];
        [audioPlayer play];
        [self setAudioPlayer:audioPlayer];
    }
    else
    {
        [self stop:self];
    }
}

//When the user clicks on the time display change the mode
- (IBAction)setDisplay:(id)sender
{
    AVAudioPlayer *audioPlayer = [self audioPlayer];
    if (audioPlayer != nil)
    {
        if (display < 2)
            display = display + 1;
        else
            display = 0;

        [self setDisplayText];
    }
    else
    {
        [self setTotal];
    }
}

//Keep the seconds running on the display
- (void)updateDisplay:(NSTimer *)theTimer
{
    AVAudioPlayer *audioPlayer = [self audioPlayer];
    if (audioPlayer != nil)
    {
	    [self setDisplayText];
    }
}

- (void)setDisplayText
{
    AVAudioPlayer *audioPlayer = [self audioPlayer];
    if (audioPlayer != nil)
    {
        if (display == 1 || display == 2)
        {
            NSString *displayText;
            NSString *timeString;

            NSInteger time = [audioPlayer currentTime];

            if (display == 2)
                time = [audioPlayer duration] - time;

            timeString = [KWCommonMethods formatTime:time];

            NSInteger selrow = [tableViewPopup indexOfSelectedItem];
            if (selrow == 1)
            {
                NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:[[tableData objectAtIndex:playingSong] objectForKey:@"Path"]];
                displayText = [NSString stringWithFormat:@"%@ %@", displayName, timeString];
            }
            else
            {
                displayText = [NSString stringWithFormat:NSLocalizedString(@"Track %ld %@", nil), (long) playingSong + 1, timeString];
            }

            [totalText setStringValue:displayText];
            
            // TODO: somehow auto layout doesn't work for this NSTextField, so do what we normally would do on macOS 10.11 < in KWAutoLayoutTextField
            [totalText sizeToFit];
            [totalText setPreferredMaxLayoutWidth:[totalText frame].size.width];
        }
        else if (display == 2)
        {
            display = 0;
            [self setTotal];
        }
    }
}

///////////////////////
// TableView actions //
///////////////////////

#pragma mark -
#pragma mark •• TableView actions

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op
{
    NSInteger selrow = [tableViewPopup indexOfSelectedItem];

    if (selrow == 0)
    {
        NSPasteboard *pboard = [info draggingPasteboard];

        if ([[pboard types] containsObject:@"NSGeneralPboardType"])
        {
            NSMutableArray *trackDictionaries = [NSMutableArray arrayWithArray:[cdtext trackDictionaries]];
            NSDictionary *discDictionary = [NSDictionary dictionaryWithDictionary:[trackDictionaries objectAtIndex:0]];
            [trackDictionaries removeObjectAtIndex:0];
        
            NSArray *draggedRows = [pboard propertyListForType:@"KWDraggedRows"];
            NSMutableArray *draggedObjects = [NSMutableArray array];
    
            NSInteger i;
            for (i = 0; i < [draggedRows count]; i ++)
            {
                NSInteger currentRow = [[draggedRows objectAtIndex:i] intValue];
                [draggedObjects addObject:[trackDictionaries objectAtIndex:currentRow]];
            }
    
            NSInteger numberOfRows = [trackDictionaries count];
            [trackDictionaries removeObjectsInArray:draggedObjects];
        
            for (i = 0; i < [draggedObjects count]; i ++)
            {
                id object = [draggedObjects objectAtIndex:i];
                NSInteger destinationRow = row + i;
        
                if (row > numberOfRows)
                {
                    [trackDictionaries addObject:object];
        
                    destinationRow = [tableData count] - 1;
                }
                else
                {
                    if ([[draggedRows objectAtIndex:i] intValue] < destinationRow)
                        destinationRow = destinationRow - [draggedRows count];
            
                    [trackDictionaries insertObject:object atIndex:destinationRow];
                }
            }

            [trackDictionaries insertObject:discDictionary atIndex:0];
            [cdtext setTrackDictionaries:trackDictionaries];
        }
    }
    
   return [super tableView:tv acceptDrop:info row:row dropOperation:op];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

//Set total size or time
- (void)setTotal
{
    if ([tableViewPopup indexOfSelectedItem] == 0)
    {
	    [totalText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Total time: %@", nil), [self totalTime]]];
    
        // TODO: somehow auto layout doesn't work for this NSTextField, so do what we normally would do on macOS 10.11 < in KWAutoLayoutTextField
        [totalText sizeToFit];
        [totalText setPreferredMaxLayoutWidth:[totalText frame].size.width];
    }
    else
    {
	    [super setTotal];
    }
}

- (NSNumber *)totalSize
{
    if (selectedTypeIndex > 0)
    {
	    return [super totalSize];
    }
    else
    {
	    NSInteger size = 0;
	    for (NSInteger i = 0; i < [audioTableData count]; i ++)
	    {
    	    DRTrack *currentTrack = trackDictionary[audioTableData[i][@"TrackID"]];
    	    NSDictionary *properties = [currentTrack properties];
    	    size = size + [[properties objectForKey:DRTrackLengthKey] intValue];
    	    size = size + [[properties objectForKey:DRPreGapLengthKey] intValue];
	    }
	    
	    return [NSNumber numberWithInt:size];
    }
}

//Calculate and return total time as string
- (NSString *)totalTime
{
    return [KWCommonMethods formatTime:[[self totalSize] floatValue] / 75];
}

- (NSInteger)getMovieDuration:(NSString *)path
{
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:nil];
    return [player duration];
}

//Check if the disc can be combined
- (BOOL)isCombinable
{
    return ([tableData count] > 0 && [tableViewPopup indexOfSelectedItem] == 1);
}

//Check if the disc is a Audio CD disc
- (BOOL)isAudioCD
{
    return ([tableViewPopup indexOfSelectedItem] == 0 && [tableData count] > 0);
}

- (void)volumeLabelSelected:(NSNotification *)notif
{
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

    if ([tableViewPopup indexOfSelectedItem] == 0)
	    [defaultCenter postNotificationName:@"KWChangeInspector" object:tableView userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWAudioDisc",@"Type", nil]];
    else
	    [defaultCenter postNotificationName:@"KWChangeInspector" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"KWEmpty",@"Type", nil]];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    //Remove to save cue / bin from an Audio-CD (note: might not work perfect yet)
    if (aSelector == @selector(saveImage:) && [tableViewPopup indexOfSelectedItem] == 0)
	    return NO;

    return [super respondsToSelector:aSelector];
}

- (NSString *)cueStringWithBinFile:(NSString *)binFile
{
    NSString *cueFile = [NSString stringWithFormat:@"FILE \"%@\" BINARY", binFile];
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    
    if ([standardDefaults objectForKey:@"KWUseCDText"])
    {
	    NSArray *keys = [cueMappings allKeys];
    
	    NSInteger i;
	    for (i=0;i<[keys count];i++)
	    {
    	    NSString *key = [keys objectAtIndex:i];
    	    NSString *cueString = [cueMappings objectForKey:key];
    	    id object = [cdtext objectForKey:key ofTrack:0];
	    
    	    if (object && ![[NSString stringWithFormat:@"%@", object] isEqualTo:@""] && (![cueString isEqualTo:@"MESSAGE"] || [(NSString *)object length] > 1))
    	    {
	    	    if (i > 7)
    	    	    cueFile = [NSString stringWithFormat:@"%@\n%@ %@", cueFile, cueString, object];
	    	    else 
    	    	    cueFile = [NSString stringWithFormat:@"%@\n%@ \"%@\"", cueFile, cueString, object];
    	    }
	    }
    
	    id ident = [cdtext objectForKey:DRCDTextDiscIdentKey ofTrack:0];
    
	    if (ident)
    	    cueFile = [NSString stringWithFormat:@"%@\nDISC_ID %@", cueFile, ident];
	    
	    id mcn = [cdtext objectForKey:DRCDTextMCNISRCKey ofTrack:0];
    
	    if (mcn)
    	    cueFile = [NSString stringWithFormat:@"%@\nUPC_EAN %@", cueFile, mcn];
    }
	    
    NSInteger x;
    NSInteger size = 0;
    for (x = 0; x < [audioTableData count]; x ++)
    {
	    NSInteger trackNumber = x + 1;
	    cueFile = [NSString stringWithFormat:@"%@\n  TRACK %2li AUDIO", cueFile, trackNumber];
	    
	    if ([standardDefaults objectForKey:@"KWUseCDText"])
	    {
    	    NSArray *keys = [cueMappings allKeys];
	    
    	    NSInteger i;
    	    for (i=0;i<[keys count];i++)
    	    {
	    	    NSString *key = [keys objectAtIndex:i];
	    	    NSString *cueString = [cueMappings objectForKey:key];
	    	    id object = [cdtext objectForKey:key ofTrack:trackNumber];
	    
	    	    if (object && ![[NSString stringWithFormat:@"%@", object] isEqualTo:@""] && (![cueString isEqualTo:@"MESSAGE"] || [(NSString *)object length] > 1))
	    	    {
    	    	    if (i > 7)
	    	    	    cueFile = [NSString stringWithFormat:@"%@\n    %@ %@", cueFile, cueString, object];
    	    	    else 
	    	    	    cueFile = [NSString stringWithFormat:@"%@\n    %@ \"%@\"", cueFile, cueString, object];
	    	    }
    	    }
	    
    	    id isrc = [cdtext objectForKey:DRTrackISRCKey ofTrack:trackNumber];
    
    	    if (isrc)
	    	    cueFile = [NSString stringWithFormat:@"%@\n    ISRC %@", cueFile, isrc];
	    
    	    id mcn = [cdtext objectForKey:DRCDTextMCNISRCKey ofTrack:trackNumber];
    
    	    if (mcn)
	    	    cueFile = [NSString stringWithFormat:@"%@\n    CATALOG %@", cueFile, mcn];
    	    
    	    id preemphasis = [cdtext objectForKey:DRAudioPreEmphasisKey ofTrack:trackNumber];
    
    	    if (preemphasis)
	    	    cueFile = [NSString stringWithFormat:@"%@\n    FLAGS PRE", cueFile];
	    }
	    
	    DRTrack *currentTrack = trackDictionary[audioTableData[x][@"TrackID"]];
	    NSDictionary *trackProperties = [currentTrack properties];
	    NSInteger pregap = [[trackProperties objectForKey:DRPreGapLengthKey] intValue];
    	    
	    if (pregap > 0)
	    {
    	    NSString *time = [[DRMSF msfWithFrames:size] description];
    	    cueFile = [NSString stringWithFormat:@"%@\n    INDEX 00 %@", cueFile, time];
    	    size = size + pregap;
	    }
	    
	    NSInteger trackSize = [[trackProperties objectForKey:DRTrackLengthKey] intValue];
	    NSString *time = [[DRMSF msfWithFrames:size] description];
	    cueFile = [NSString stringWithFormat:@"%@\n    INDEX 01 %@", cueFile, time];
	    size = size + trackSize;
    }
    
    return cueFile;
}

//////////////////////
// External actions //
//////////////////////

#pragma mark -
#pragma mark •• External actions

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
- (DRCDTextBlock *)myTextBlock
{
    return cdtext;
}
#endif

- (NSMutableArray *)myTracks
{
    NSMutableArray *tracks = [[NSMutableArray alloc] init];
    for (NSDictionary *dictionary in audioTableData)
    {
        [tracks addObject:trackDictionary[dictionary[@"TrackID"]]];
    }

    return tracks;
}

@end

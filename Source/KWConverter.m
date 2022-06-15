#import "KWConverter.h"
#import "KWProgressManager.h"

@implementation KWConverter

/////////////////////
// Default actions //
/////////////////////

#pragma mark -
#pragma mark •• Default actions

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        status = 0;
        userCanceled = NO;
        
        convertedFiles = [[NSMutableArray alloc] init];

        [[KWProgressManager sharedManager] setCancelHandler:^
        {
            [self cancelEncoding];
        }];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/////////////////////
// Encode actions //
/////////////////////

#pragma mark -
#pragma mark •• Encode actions

- (NSInteger)batchConvert:(NSArray *)files withOptions:(NSDictionary *)options errorString:(NSString **)error
{
    //Set the options
    convertDestination = [options objectForKey:@"KWConvertDestination"];
    convertExtension = [options objectForKey:@"KWConvertExtension"];
    convertRegion = [[options objectForKey:@"KWConvertRegion"] intValue];
    convertKind = [[options objectForKey:@"KWConvertKind"] intValue];

    NSInteger i;
    for (i=0;i<[files count];i++)
    {
	    NSString *currentPath = [files objectAtIndex:i];
    
	    if (userCanceled == NO)
	    {
    	    number = i;
	        
            NSString *task = [NSString stringWithFormat:NSLocalizedString(@"Encoding file %i of %i to %@", nil), i + 1, [files count], options[@"KWConvertExtension"]];
            [[KWProgressManager sharedManager] setTask:task];
	    
    	    //Test the file on how to encode it
    	    NSInteger output = [self testFile:currentPath];
    	    
    	    copyAudio = [self containsAC3:currentPath];
    	    
    	    if (output != 0)
	    	    output = [self encodeFileAtPath:currentPath];
    	    else
	    	    output = 3;
	    
    	    if (output == 0)
    	    {
	    	    NSDictionary *output = [NSDictionary dictionaryWithObjectsAndKeys:encodedOutputFile, @"Path", [KWCommonMethods quicktimeChaptersFromFile:currentPath], @"Chapters", nil];
    	    
	    	    [convertedFiles addObject:output];
    	    }
    	    else if (output == 1)
    	    {
	    	    NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:currentPath];
	    	    
	    	    [self setErrorStringWithString:[NSString stringWithFormat:NSLocalizedString(@"%@ (Unknown error)", nil), displayName]];
    	    }
    	    else if (output == 2)
    	    {
	    	    if (errorString)
	    	    {
    	    	    *error = errorString;
    	    	    
    	    	    return 1;
	    	    }
	    	    else
	    	    {
    	    	    return 2;
	    	    }
    	    }
	    }
	    else
	    {
    	    if (errorString)
    	    {
	    	    *error = errorString;
    	    	    
	    	    return 1;
    	    }
    	    else
    	    {
	    	    return 2;
    	    }
	    }
    }
    
    if (errorString)
    {
	    *error = errorString;
    	    	    
	    return 1;
    }
    
    return 0;
}

//Encode the file
- (NSInteger)encodeFileAtPath:(NSString *)path
{
    NSString *statusString = [NSLocalizedString(@"Encoding: ", nil) stringByAppendingString:[[NSFileManager defaultManager] displayNameAtPath:path]];
    [[KWProgressManager sharedManager] setStatus:statusString];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Encoder options for ffmpeg
    NSString *aspect;
    NSString *ffmpegFormat = @"";
    NSString *outFileWithExtension = [KWCommonMethods uniquePathNameFromPath:[NSString stringWithFormat:@"%@/%@.%@", convertDestination, [[path lastPathComponent] stringByDeletingPathExtension], convertExtension]];
    
    NSArray *quicktimeOptions = [NSArray array];
    NSArray *wavOptions = [NSArray array];
    NSArray *inputOptions = [NSArray array];
    
    NSSize outputSize;
    
    // To keep the aspect ratio ffmpeg needs to pad the movie
    NSArray *padOptions = [NSArray array];
    NSSize aspectSize = NSMakeSize(4, 3);
    //NSInteger dvdAspectMode = [[defaults objectForKey:@"KWDVDAspectMode"] intValue];
    NSInteger dvdAspectMode = [[defaults objectForKey:@"KWDVDForce43"] intValue];
    NSInteger calculateSize;
    BOOL topBars;
    
    if (convertRegion == 0)
	    ffmpegFormat = @"pal";
    else
	    ffmpegFormat = @"ntsc";
    
    if (convertKind == 1 || convertKind == 2)
    {
	    aspect = @"4:3";
	    aspectSize = NSMakeSize(4, 3);
	    topBars = (inputAspect >= (float)4 / (float)3);
    }
    
    if (convertKind == 1)
    {
	    ffmpegFormat = [NSString stringWithFormat:@"%@-vcd", ffmpegFormat];
    
	    if (inputAspect < (float)4 / (float)3)
    	    calculateSize = 352;
	    else if (convertRegion == 0)
    	    calculateSize = 288;
	    else
    	    calculateSize = 240;
    	    
	    if (convertRegion == 0)
    	    outputSize = NSMakeSize(352, 288);
	    else
    	    outputSize = NSMakeSize(352, 240);
    }
    
    if (convertKind == 2)
    {
	    ffmpegFormat = [NSString stringWithFormat:@"%@-svcd", ffmpegFormat];
    
	    if (convertRegion == 1 && inputAspect < (float)4 / (float)3)
    	    calculateSize = 576;
	    else
    	    calculateSize = 480;
    	    
	    if (convertRegion == 0)
    	    outputSize = NSMakeSize(480, 576);
	    else
    	    outputSize = NSMakeSize(480, 480);
    }
    
    if (convertKind == 3)
    {
	    ffmpegFormat = [NSString stringWithFormat:@"%@-dvd", ffmpegFormat];
    
	    if ((inputAspect <= (float)4 / (float)3 && dvdAspectMode != 2) || dvdAspectMode == 1)
	    {
    	    aspectSize = NSMakeSize(4, 3);
    	    calculateSize = 720;
    	    topBars = (inputAspect > (float)4 / (float)3);
	    }
	    else
	    {
    	    aspectSize = NSMakeSize(16, 9);
	    
    	    if (convertRegion == 1)
	    	    calculateSize = 576;
    	    else
	    	    calculateSize = 480;
	    	    
    	    topBars = (inputAspect > (float)16 / (float)9);
	    }
	    
	    if (convertRegion == 0)
    	    outputSize = NSMakeSize(720, 576);
	    else
    	    outputSize = NSMakeSize(720, 480);
    }
    
    // TODO: clean this mess up :(
    if ((convertKind == 1 || convertKind == 2 || convertKind == 3) && ((inputAspect != 4.0f / 3.0f) || ((inputAspect == 4.0f / 3.0f) && dvdAspectMode == 2 && convertKind == 3)) && ((inputAspect != 16.0f / 9.0f) || (((inputAspect == 16.0f / 9.0f) && convertKind == 1) || convertKind == 2 || dvdAspectMode == 1)))
    {
	    NSInteger padSize = [self getPadSize:calculateSize withAspect:aspectSize withTopBars:topBars];
	    
	    if (topBars)
    	    padOptions = [NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%li:%li,pad=%li:%li:0:%li:black", (NSInteger)outputSize.width, (NSInteger)outputSize.height - (padSize * 2), (NSInteger)outputSize.width, (NSInteger)outputSize.height, padSize], nil];
    	    //padOptions = [NSArray arrayWithObjects:@"-padtop", padSize, @"-padbottom", padSize, nil];
	    else
    	    padOptions = [NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%li:%li,pad=%li:%li:%li:0:black", (NSInteger)outputSize.width - (padSize * 2), (NSInteger)outputSize.height, (NSInteger)outputSize.width, (NSInteger)outputSize.height, padSize], nil];
    	    //padOptions = [NSArray arrayWithObjects:@"-padleft", padSize, @"-padright", padSize, nil];
    	    
    }
    
    aspect = [NSString stringWithFormat:@"%.0f:%.0f", aspectSize.width, aspectSize.height];

    ffmpeg = [[NSTask alloc] init];
    
    // Test
//     inputOptions = [NSArray arrayWithObjects:@"-t", @"1", @"-i", path, nil];
    inputOptions = [NSArray arrayWithObjects:@"-i", path, nil];

    NSPipe *pipe=[[NSPipe alloc] init];
    NSFileHandle *handle;
    NSData *data;
    
    [ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];
    
    NSMutableArray *args;
    
    //QuickTime movie containers don't seem to like threads so only use it for the output file
    NSString *pathExtension = [path pathExtension];
    if ([pathExtension isEqualTo:@"mov"] || [pathExtension isEqualTo:@"m4v"] || [pathExtension isEqualTo:@"mp4"])
	    args = [NSMutableArray array];
    else
	    args = [NSMutableArray arrayWithObjects:@"-threads", [[defaults objectForKey:@"KWEncodingThreads"] stringValue], nil];
    
    [args addObjectsFromArray:quicktimeOptions];
    [args addObjectsFromArray:wavOptions];
    [args addObjectsFromArray:inputOptions];
    
    if ([pathExtension isEqualTo:@"mov"] || [pathExtension isEqualTo:@"m4v"] || [pathExtension isEqualTo:@"mp4"])
	    [args addObjectsFromArray:[NSArray arrayWithObjects:@"-threads", [[defaults objectForKey:@"KWEncodingThreads"] stringValue], nil]];

    if (convertKind == 1 || convertKind == 2)
    {
	    [args addObjectsFromArray:[NSArray arrayWithObjects:@"-target",ffmpegFormat,@"-ac",@"2",@"-aspect",aspect, nil]];
    }
    else if (convertKind == 4)
    {
	    [args addObjectsFromArray:[NSArray arrayWithObjects:@"-vtag", @"DIVX", @"-acodec", nil]];
	    	    
	    if ([[defaults objectForKey:@"KWDefaultDivXSoundType"] intValue] == 0)
	    {
    	    [args addObject:@"libmp3lame"];
    	    [args addObject:@"-ac"];
    	    [args addObject:@"2"];
	    }
	    else
	    {
    	    [args addObject:@"ac3"];
	    }
    	    	    
	    if ([defaults boolForKey:@"KWCustomDivXVideoBitrate"])
	    {
    	    [args addObject:@"-b:v"];
    	    [args addObject:[NSString stringWithFormat:@"%i", [[defaults objectForKey:@"KWDefaultDivXVideoBitrate"] intValue] * 1000]];
	    }
    	    	    
	    if ([defaults boolForKey:@"KWCustomDivXSoundBitrate"])
	    {
    	    [args addObject:@"-b:a"];
    	    [args addObject:[NSString stringWithFormat:@"%i", [[defaults objectForKey:@"KWDefaultDivxSoundBitrate"] intValue] * 1000]];
	    }
    	    	    
	    if ([defaults boolForKey:@"KWCustomDivXSize"])
	    {
    	    [args addObject:@"-s"];
    	    [args addObject:[NSString stringWithFormat:@"%@x%@", [defaults objectForKey:@"KWDefaultDivXWidth"], [defaults objectForKey:@"KWDefaultDivXHeight"]]];
	    }
	    else if (inputFormat > 0)
	    {
    	    if (convertRegion == 1)
    	    {
	    	    [args addObject:@"-s"];
	    	    [args addObject:@"1024x576"];
    	    }
    	    else
    	    {
	    	    [args addObject:@"-s"];
	    	    [args addObject:@"1024x480"];
    	    }
	    }
    	    	    
	    if ([defaults boolForKey:@"KWCustomFPS"])
	    {
    	    [args addObject:@"-r"];
    	    [args addObject:[NSString stringWithFormat:@"%.2f", [[defaults objectForKey:@"KWDefaultFPS"] floatValue]]];
	    }
    }
    else if (convertKind == 3)
    {
	    [args addObjectsFromArray:[NSArray arrayWithObjects:@"-target", ffmpegFormat,@"-ac",@"2", @"-aspect",aspect,@"-acodec", nil]];
	    
	    if (copyAudio == NO)
	    {
    	    if ([[defaults objectForKey:@"KWDefaultDVDSoundType"] intValue] == 0)
	    	    [args addObject:@"mp2"];
    	    else
	    	    [args addObject:@"ac3"];
	    	    
    	    if ([defaults boolForKey:@"KWCustomDVDSoundBitrate"])
    	    {
	    	    [args addObject:@"-b:a"];
	    	    [args addObject:[NSString stringWithFormat:@"%i", [[defaults objectForKey:@"KWDefaultDVDSoundBitrate"] intValue] * 1000]];
    	    }
    	    else if ([[defaults objectForKey:@"KWDefaultDVDSoundType"] intValue] == 0)
    	    {
	    	    [args addObject:@"-b:a"];
	    	    [args addObject:@"224000"];
    	    }
	    }
	    else
	    {
    	    [args addObject:@"copy"];
	    }
    	    	    
	    if ([defaults boolForKey:@"KWCustomDVDVideoBitrate"])
	    {
    	    [args addObject:@"-b:v"];
    	    [args addObject:[NSString stringWithFormat:@"%i", [[defaults objectForKey:@"KWDefaultDVDVideoBitrate"] intValue] * 1000]];
	    }
     
//        [args addObject:@"-qscale:v"];
//        [args addObject:@"1"];
//        [args addObject:@"-trellis"];
//        [args addObject:@"1"];
//        
//        [args addObject:@"-g"];
//        [args addObject:@"12"];
//        
//        [args addObject:@"-bf"];
//        [args addObject:@"2"];
//        
//        [args addObject:@"-lmin"];
//        [args addObject:@"0.75"];
//        
//        [args addObject:@"-mblmin"];
//        [args addObject:@"150"];
//        
//        [args addObject:@"-qmin"];
//        [args addObject:@"1"];
//        
//        [args addObject:@"-qmax"];
//        [args addObject:@"31"];
//        
//        [args addObject:@"-maxrate"];
//        [args addObject:@"8000000"];
        
        //-g 12 -bf 2 -lmin 0.75 -mblmin 50 -qmin 1 -qmax 31 -maxrate 8000k
    }
    else if (convertKind == 5)
    {
	    [args addObject:@"-b:a"];
	    [args addObject:[NSString stringWithFormat:@"%i", [[defaults objectForKey:@"KWDefaultMP3Bitrate"] intValue] * 1000]];
	    [args addObject:@"-ac"];
	    [args addObject:[[defaults objectForKey:@"KWDefaultMP3Mode"] stringValue]];
	    [args addObject:@"-ar"];
	    [args addObject:@"44100"];
    }
    else if (convertKind == 6)
    {
        if ([self isTwentyFourBitsAudio:path])
        {
            [args addObject:@"-acodec"];
            [args addObject:@"pcm_s24le"];
        }
        
        [args addObject:@"-map_metadata"];
        [args addObject:@"-1"];
    }

    //Fix for DV to mpeg2 conversion
    if (inputFormat == 1)
    {
	    if (convertKind == 2)
	    {
    	    //SVCD
    	    //[args addObjectsFromArray:[NSArray arrayWithObjects:@"-cropleft", @"22", @"-cropright", @"22", nil]];
            [args addObjectsFromArray:[NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%li:%li,crop=%li:%li:%li:%li", (NSInteger)outputSize.width + 12, (long)outputSize.height, (NSInteger)outputSize.width, (NSInteger)outputSize.height, (NSInteger)6, (NSInteger)0], nil]];
    	    
	    }
	    else if (convertKind == 3)
	    {
    	    //DVD
    	    //[args addObjectsFromArray:[NSArray arrayWithObjects:@"-cropleft", @"24", @"-cropright", @"24", nil]];
            [args addObjectsFromArray:[NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%li:%li,crop=%li:%li:%li:%li", (NSInteger)outputSize.width + 16, (long)outputSize.height, (NSInteger)outputSize.width, (NSInteger)outputSize.height, (NSInteger)8, (NSInteger)0], nil]];
	    }
    }
	    
    [args addObjectsFromArray:padOptions];
	    
    if ([defaults boolForKey:@"KWSaveBorders"] == YES)
    {
	    NSNumber *borderSize = [[NSUserDefaults standardUserDefaults] objectForKey:@"KWSaveBorderSize"];
	    NSInteger heightBorder = [borderSize intValue];
	    NSInteger widthBorder = [self convertToEven:[[NSNumber numberWithFloat:inputWidth / (inputHeight / [borderSize floatValue])] stringValue]];
	    
	    if ([padOptions count] > 0 && [[padOptions objectAtIndex:0] isEqualTo:@"-padtop"])
	    {
    	    //[args addObjectsFromArray:[NSArray arrayWithObjects:@"-padleft", widthBorder, @"-padright", widthBorder, nil]];
            [args addObjectsFromArray:[NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%li:%li,pad=%li:%li:%li:0:black", (NSInteger)outputSize.width - (widthBorder * 2), (long)outputSize.height, (long)outputSize.width, (long)outputSize.height, (long)widthBorder], nil]];
	    }
	    else
	    {
    	    //[args addObjectsFromArray:[NSArray arrayWithObjects:@"-padtop", heightBorder, @"-padbottom", heightBorder, nil]];
            [args addObjectsFromArray:[NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%li:%li,pad=%li:%li:0:%li:black", (long)outputSize.width, (NSInteger)outputSize.height - (heightBorder * 2), (long)outputSize.width, (long)outputSize.height, (long)heightBorder], nil]];
    	    
    	    if ([padOptions count] == 0)
                [args addObjectsFromArray:[NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%li:%li,pad=%li:%li:%li:0:black", (NSInteger)outputSize.width - (widthBorder * 2), (long)outputSize.height, (long)outputSize.width, (long)outputSize.height, (long)widthBorder], nil]];
	    	    //[args addObjectsFromArray:[NSArray arrayWithObjects:@"-padleft", widthBorder, @"-padright", widthBorder, nil]];
	    	    
	    }
    }
    
    [args addObject:@"-max_muxing_queue_size"];
    [args addObject:@"99999"];

    [args addObject:outFileWithExtension];

    // TODO: update ffmpeg so we can force the aspect ratio, aspect seems to be ignored for some input files
//    [args addObject:@"-vf"];
//    [args addObject:[NSString stringWithFormat:@"setdar=%@", aspect]];
    
    [ffmpeg setArguments:args];
    //ffmpeg uses stderr to show the progress
    [ffmpeg setStandardError:pipe];
    handle=[pipe fileHandleForReading];
    
    [KWCommonMethods logCommandIfNeeded:ffmpeg];
    [ffmpeg launch];

    status = 2;

    NSString *string = nil;

    //Here we go
    while([data = [handle availableData] length]) 
    {
	    //The string containing ffmpeg's output
	    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
	    KWLog(@"%@", string);
	    
	    //Format the time sting ffmpeg outputs and format it to percent
	    if ([string rangeOfString:@"time="].length > 0)
	    {
    	    NSString *currentTimeString = [[[[string componentsSeparatedByString:@"time="] objectAtIndex:1] componentsSeparatedByString:@" "] objectAtIndex:0];
            CGFloat currentTime = [self ffmpegCurrentTimeToSeconds:currentTimeString];
    	    float percent = currentTime / inputTotalTime * 100;
	    
    	    if (inputTotalTime > 0)
    	    {
	    	    if (percent < 101)
	    	    {
                    KWProgressManager *progressManager = [KWProgressManager sharedManager];
                    [progressManager setStatusByAddingPercent:[NSString stringWithFormat: @" (%.0f%@)", percent, @"%"]];
                    [progressManager setValue:percent + (double)number * 100];
	    	    }
    	    }
    	    else
    	    {
                [[KWProgressManager sharedManager] setStatusByAddingPercent:@" (?%)"];
    	    }
	    }

	    data = nil;
    }

    //After there's no output wait for ffmpeg to stop
    [ffmpeg waitUntilExit];

    //Check if the encoding succeeded, if not remove the mpg file ,NOT POSSIBLE :-(
    NSInteger taskStatus = [ffmpeg terminationStatus];
    
    //Return if ffmpeg failed or not
    if (taskStatus == 0)
    {
	    status = 0;
	    encodedOutputFile = outFileWithExtension;
    
	    return 0;
    }
    else if (userCanceled == YES)
    {
	    status = 0;
	    
	    [KWCommonMethods removeItemAtPath:outFileWithExtension];
	    
	    return 2;
    }
    else
    {
	    status = 0;
	    
	    [KWCommonMethods removeItemAtPath:outFileWithExtension];
	    
	    return 1;
    }
}

//Stop encoding (stop ffmpeg)
- (void)cancelEncoding
{
    userCanceled = YES;
    
    if (status == 2 || status == 3)
    {
	    [ffmpeg terminate];
    }
}

/////////////////////
// Test actions //
/////////////////////

#pragma mark -
#pragma mark •• Test actions

//Test if ffmpeg can encode, sound and/or video, and if it does have any sound
- (NSInteger)testFile:(NSString *)path
{
    NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:path];
    NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tempkf.mpg"];
    
    BOOL audioWorks = YES;
    BOOL videoWorks = YES;
    BOOL keepGoing = YES;

    while (keepGoing == YES)
    {
	    NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-t",@"0.1",@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-target",@"pal-vcd", nil];
    	    
	    if (videoWorks == NO)
    	    [arguments addObject:@"-vn"];
	    else if (audioWorks == NO)
    	    [arguments addObject:@"-an"];
	    	    
	    [arguments addObjectsFromArray:[NSArray arrayWithObjects:@"-ac",@"2",@"-r",@"25",@"-y", tempFile, nil]];
	    
	    NSString *string;
	    [KWCommonMethods launchNSTaskAtPath:[KWCommonMethods ffmpegPath] withArguments:arguments outputError:YES outputString:YES output:&string];
	    
	    keepGoing = NO;
	    
	    NSInteger code = 0;
	    NSString *error = @"%@ (Unknown error)";
	    
	    if ([string rangeOfString:@"Video: Apple Intermediate Codec"].length > 0)
	    {
    	    if ([self setTimeAndAspectFromOutputString:string fromFile:path])
	    	    return 2;
    	    else
	    	    return 0;
	    }
    	    
	    if ([string rangeOfString:@"error reading header: -1"].length > 0 && [string rangeOfString:@"iDVD"].length > 0)
    	    code = 2;
    
	    // Check if ffmpeg reconizes the file
	    if ([string rangeOfString:@"Unknown format"].length > 0 && [string rangeOfString:@"Unknown format is not supported as input pixel format"].length == 0)
	    {
    	    error = [NSString stringWithFormat:NSLocalizedString(@"%@ (Unknown format)", nil), displayName];
    	    [self setErrorStringWithString:error];
    	    
    	    return 0;
	    }
	    
	    //Check if ffmpeg reconizes the codecs
	    if ([string rangeOfString:@"could not find codec parameters"].length > 0)
    	    error = [NSString stringWithFormat:NSLocalizedString(@"%@ (Couldn't get attributes)", nil), displayName];
    	    
	    //No audio
	    if ([string rangeOfString:@"error: movie contains no audio tracks!"].length > 0 && convertKind < 5)
    	    error = [NSString stringWithFormat:NSLocalizedString(@"%@ (No audio)", nil), displayName];
    
	    //Check if the movie is a (internet/local)reference file
	    if ([self isReferenceMovie:string])
    	    code = 2;
    	    
	    if (code == 0 || !error)
	    {
    	    if ([string rangeOfString:@"edit list not starting at 0, a/v desync might occur, patch welcome"].length > 0)
	    	    videoWorks = NO;
    	    
    	    if ([string rangeOfString:@"Unknown format is not supported as input pixel format"].length > 0)
	    	    videoWorks = NO;
	    	    
    	    if ([string rangeOfString:@"Resampling with input channels greater than 2 unsupported."].length > 0)
	    	    audioWorks = NO;
    	    
    	    NSString *input = [[[[string componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Input #0"] objectAtIndex:1];
    	    if ([input rangeOfString:@"mp2"].length > 0 && [input rangeOfString:@"mov,"].length > 0)
	    	    audioWorks = NO;
    	    
    	    BOOL hasVideoCheck = ([string rangeOfString:@"Video:"].length > 0);
    	    BOOL hasAudioCheck = ([string rangeOfString:@"Audio:"].length > 0);
    	    BOOL videoWorksCheck = [self streamWorksOfKind:@"Video" inOutput:string];
    	    BOOL audioWorksCheck = [self streamWorksOfKind:@"Audio" inOutput:string];
    	    
    	    if (hasVideoCheck && hasAudioCheck)
    	    {
	    	    if (audioWorksCheck && videoWorksCheck && videoWorks && audioWorks)
	    	    {
    	    	    code = 1;
	    	    }
	    	    else if (!audioWorksCheck || !videoWorksCheck)
	    	    {
    	    	    if (videoWorks && audioWorks)
	    	    	    keepGoing = YES;
	    	    
    	    	    if (!audioWorksCheck)
	    	    	    audioWorks = NO;
    	    	    else if (!videoWorksCheck)
	    	    	    videoWorks = NO;
	    	    }
    	    }
    	    else
    	    {
	    	    if (!hasVideoCheck && !hasAudioCheck)
	    	    {
    	    	    error = [NSString stringWithFormat:NSLocalizedString(@"%@ (No audio/video)", nil), displayName];
	    	    }
	    	    else if (!hasVideoCheck && hasAudioCheck)
	    	    {
    	    	    if (convertKind < 5)
    	    	    {
	    	    	    error = [NSString stringWithFormat:NSLocalizedString(@"%@ (No video)", nil), displayName];
    	    	    }
    	    	    else
    	    	    {
	    	    	    code = 8;
	    	    	    if (audioWorksCheck)
    	    	    	    code = 7;
    	    	    }
	    	    }
	    	    else if (hasVideoCheck && !hasAudioCheck)
	    	    {
    	    	    if (convertKind > 4)
    	    	    {
	    	    	    error = [NSString stringWithFormat:NSLocalizedString(@"%@ (No audio)", nil), displayName];
    	    	    }
    	    	    else
    	    	    {
	    	    	    code = 6;
	    	    	    if (videoWorksCheck)
    	    	    	    code = 5;
    	    	    }
	    	    }
    	    }
	    }
	    
	    if (!keepGoing)
	    {
    	    if (code == 0 || !error)
    	    {
	    	    if (videoWorks && !audioWorks)
	    	    {
    	    	    if ([[[path pathExtension] lowercaseString] isEqualTo:@"mpg"] || [[[path pathExtension] lowercaseString] isEqualTo:@"mpeg"] || [[[path pathExtension] lowercaseString] isEqualTo:@"m2v"])
	    	    	    error = [NSString stringWithFormat:NSLocalizedString(@"%@ (Unsupported audio)", nil), displayName];
    	    	    else
	    	    	    code = 4;
	    	    }
	    	    else if (!videoWorks && audioWorks)
	    	    {
    	    	    code = 3;
	    	    }
	    	    else if (!videoWorks && !audioWorks)
	    	    {
    	    	    code = 2;
	    	    }
    	    }
    	    
    	    if (code > 0)
    	    {
	    	    if ([self setTimeAndAspectFromOutputString:string fromFile:path])
    	    	    return code;
	    	    else
    	    	    return 0;
    	    }
    	    else
    	    {
	    	    [self setErrorStringWithString:error];
	    	    
	    	    return 0;
    	    }
	    }
    }
    
    [KWCommonMethods removeItemAtPath:tempFile];
    
    return 0;
}

- (BOOL)streamWorksOfKind:(NSString *)kind inOutput:(NSString *)output
{
    NSString *one = [[[[[[output componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Stream #0:0"] objectAtIndex:1] componentsSeparatedByString:@": "] objectAtIndex:1];
    NSString *two = @"";
    
    if ([output rangeOfString:@"Stream #0:1"].length > 0)
	    two = [[[[[[output componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Stream #0:1"] objectAtIndex:1] componentsSeparatedByString:@": "] objectAtIndex:1];

    //Is stream 0.0 audio or video
    if ([output rangeOfString:@"for input stream #0.0"].length > 0 || [output rangeOfString:@"Error while decoding stream #0:0"].length > 0)
    {
	    if ([one isEqualTo:kind])
	    {
    	    return NO;
	    }
    }
    	    
    //Is stream 0.1 audio or video
    if ([output rangeOfString:@"for input stream #0:1"].length > 0| [output rangeOfString:@"Error while decoding stream #0:1"].length > 0)
    {
	    if ([two isEqualTo:kind])
	    {
    	    return NO;
	    }
    }
    
    return YES;
}

- (BOOL)isReferenceMovie:(NSString *)output
{
    //Found in reference or streaming QuickTime movies
    return ([output rangeOfString:@"unsupported slice header"].length > 0 || [output rangeOfString:@"bitrate: 5 kb/s"].length > 0);
}

- (BOOL)setTimeAndAspectFromOutputString:(NSString *)output fromFile:(NSString *)file
{    
    NSString *inputString = [[output componentsSeparatedByString:@"Input #0"] objectAtIndex:1];

    inputWidth = 0;
    inputHeight = 0;
    inputFps = 0;
    inputTotalTime = 0;
    inputAspect = 0;
    inputFormat = 0;

    //Calculate the aspect ratio width / height    
    if ([[[inputString componentsSeparatedByString:@"Output"] objectAtIndex:0] rangeOfString:@"Video:"].length > 0)
    {
        // TODO: make this stuff a lot safer!!!!!!
	    //NSString *resolution;
        NSString *videoInfo = [[[inputString componentsSeparatedByString:@"Output"][0] componentsSeparatedByString:@"Video:"][1] componentsSeparatedByString:@"\n"][0];
        NSArray *videoComponents = [videoInfo componentsSeparatedByString:@","];
        NSString *resolutionString;
        NSString *fpsString;

        for (NSString *videoComponent in videoComponents)
        {
            NSString *strippedVideoComponent = [[videoComponent componentsSeparatedByString:@"("][0] componentsSeparatedByString:@"["][0];
            NSCharacterSet *resolutionCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789x "];
            
            if ([strippedVideoComponent rangeOfCharacterFromSet:[resolutionCharacterSet invertedSet]].location == NSNotFound && [strippedVideoComponent containsString:@"x"])
            {
                resolutionString = strippedVideoComponent;
                continue;
            }
            
            NSCharacterSet *fpsCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789.fps "];
            if ([strippedVideoComponent rangeOfCharacterFromSet:[fpsCharacterSet invertedSet]].location == NSNotFound && [strippedVideoComponent containsString:@" fps"])
            {
                fpsString = strippedVideoComponent;
                continue;
            }
        }

//        NSArray *resolutionPreArray = [[videoInfo componentsSeparatedByString:@"[SAR"][0] componentsSeparatedByString:@","];
//        NSString *resolutionInfo = resolutionPreArray[[resolutionPreArray count] - 1];
//        NSArray *fpsPreArray = [[videoInfo componentsSeparatedByString:@" fps"][0] componentsSeparatedByString:@","];
//        NSString *fpsInfo = fpsPreArray[[fpsPreArray count] - 1];
//        NSArray *fpsArray = [[[[[inputString componentsSeparatedByString:@"Output"] objectAtIndex:0] componentsSeparatedByString:@" tbc"] objectAtIndex:0] componentsSeparatedByString:@","];
//
//        NSArray *beforeX = [[resolutionArray objectAtIndex:0] componentsSeparatedByString:@" "];
//        NSArray *afterX = [[resolutionArray objectAtIndex:1] componentsSeparatedByString:@" "];
	    
        NSArray *resolutionComponents = [resolutionString componentsSeparatedByString:@"x"];
	    inputWidth = [resolutionComponents[0] intValue];
	    inputHeight = [resolutionComponents[1] intValue];
	    inputFps = [fpsString floatValue];
    
	    if (inputFps == 25 && [inputString rangeOfString:@"Video: dvvideo"].length > 0)
	    {
    	    inputWidth = 720;
    	    inputHeight = 576;
	    }
	    
	    inputAspect = (float)inputWidth / (float)inputHeight;
	    
	    
	    if (inputWidth == 352 && (inputHeight == 288 || inputHeight == 240))
        {
    	    inputAspect = (float)4 / (float)3;
        }

	    //Check if the iMovie project is 4:3 or 16:9
	    if ([inputString rangeOfString:@"Video: dvvideo"].length > 0)
	    {
    	    if ([file rangeOfString:@".iMovieProject"].length > 0)
    	    {
	    	    NSString *projectName = [[[[[file stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingPathExtension] lastPathComponent];
	    	    NSString *projectLocation = [[[file stringByDeletingLastPathComponent] stringByDeletingLastPathComponent]stringByDeletingLastPathComponent];
	    	    NSString *projectSettings = [[projectLocation stringByAppendingPathComponent:projectName] stringByAppendingPathExtension:@"iMovieProj"];
    	    
	    	    if ([[NSFileManager defaultManager] fileExistsAtPath:projectSettings])
	    	    {
    	    	    if ([[KWCommonMethods stringWithContentsOfFile:projectSettings] rangeOfString:@"WIDE"].length > 0)
    	    	    {
	    	    	    inputWidth = 1024;
	    	    	    inputAspect = (float)16 / (float)9;
    	    	    }
    	    	    else
    	    	    {
	    	    	    inputAspect = (float)4 / (float)3;
    	    	    }
	    	    }
    	    }
    	    else 
    	    {
	    	    if ([inputString rangeOfString:@"[PAR 59:54 DAR 295:216]"].length > 0 || [inputString rangeOfString:@"[PAR 10:11 DAR 15:11]"].length)
    	    	    inputAspect = (float)4 / (float)3;
	    	    else if ([inputString rangeOfString:@"[PAR 118:81 DAR 295:162]"].length > 0 || [inputString rangeOfString:@"[PAR 40:33 DAR 20:11]"].length)
    	    	    inputAspect = (float)16 / (float)9;
    	    }
	    
    	    inputFormat = 1;
	    }

	    if ([inputString rangeOfString:@"DAR 16:9"].length > 0)
	    {
    	    inputAspect = (float)16 / (float)9;
    	    
    	    if ([inputString rangeOfString:@"mpeg2video"].length > 0)
    	    {
	    	    inputWidth = 1024;
	    	    inputFormat = 2;
    	    }
	    }
	    else
	    {
			// Try to get the aspect ratio from the DAR
			NSArray *inputComponents = [inputString componentsSeparatedByString:@"Output"];
			if ([inputComponents count] > 0)
			{
				NSString *input = inputComponents[0];
				NSArray *darComponents = [input componentsSeparatedByString:@"DAR "];
				if ([darComponents count] > 1)
				{
					NSArray *darSubComponents = [darComponents[1] componentsSeparatedByString:@"]"];
					if ([darSubComponents count] > 0)
					{
						NSArray *darNumberComponents = [darSubComponents[0] componentsSeparatedByString:@":"];
						if ([darNumberComponents count] > 0)
						{
							CGFloat inputAspectWidth = [darNumberComponents[0] doubleValue];
							CGFloat inputAspectHeight = [darNumberComponents[1] doubleValue];
							if (inputAspectWidth > 0 && inputAspectHeight > 0)
							{
								inputAspect = inputAspectWidth / inputAspectHeight;
							}
						}
					}
				}
			}
	    }
    
	    //iMovie projects with HDV 1080i are 16:9, ffmpeg guesses 4:3
	    if ([inputString rangeOfString:@"Video: Apple Intermediate Codec"].length > 0)
	    {
    	    //if ([file rangeOfString:@".iMovieProject"].length > 0)
    	    //{
	    	    inputAspect = (float)16 / (float)9;
	    	    inputWidth = 1024;
	    	    inputHeight = 576;
    	    //}
	    }
    }
    
    if ([inputString rangeOfString:@"Duration:"].length > 0)    
    {
	    inputTotalTime = 0;
    
	    if ([inputString rangeOfString:@"Duration: N/A,"].length == 0)
	    {
    	    NSString *time = [[[[inputString componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:0];
    	    double hour = [[[time componentsSeparatedByString:@":"] objectAtIndex:0] doubleValue];
    	    double minute = [[[time componentsSeparatedByString:@":"] objectAtIndex:1] doubleValue];
    	    double second = [[[time componentsSeparatedByString:@":"] objectAtIndex:2] doubleValue];
    	    
    	    inputTotalTime  = (hour * 60 * 60) + (minute * 60) + second;
	    }
    }
    
    BOOL hasOutput = YES;
    
    if (inputWidth == 0 && inputHeight == 0 && inputFps == 0 && convertKind < 5)
	    hasOutput = NO;
	    
    if (hasOutput)
    {
	    return YES;
    }
    else
    {
	    [self setErrorStringWithString:[NSString stringWithFormat:NSLocalizedString(@"%@ (Couldn't get attributes)", nil), [[NSFileManager defaultManager] displayNameAtPath:file]]];
	    return NO;
    }
}

///////////////////////
// Compilant actions //
///////////////////////

#pragma mark -
#pragma mark •• Compilant actions

+ (NSString *)ffmpegOutputForPath:(NSString *)path
{
    NSString *string;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *arguments = [NSArray arrayWithObjects:@"-threads", [[defaults objectForKey:@"KWEncodingThreads"] stringValue], @"-i", path, nil];
    [KWCommonMethods launchNSTaskAtPath:[KWCommonMethods ffmpegPath] withArguments:arguments outputError:YES outputString:YES output:&string];
    
    if ([string rangeOfString:@"Unknown format"].length > 0 && [string rangeOfString:@"Input #0"].length > 0)
    {
	    return nil;
    }
    else
    {
	    return [[string componentsSeparatedByString:@"Input #0"] objectAtIndex:1];
    }
}

//Check if the file is a valid VCD file (return YES if it is valid)
- (BOOL)isVCD:(NSString *)path
{
    NSString *string = [KWConverter ffmpegOutputForPath:path];
    
    if (string != nil)
    {
        BOOL isRightVideoFormat = [string rangeOfString:@"mpeg1video"].length > 0;
        BOOL isRightResolution = [string rangeOfString:@"352x288"].length > 0 || [string rangeOfString:@"352x240"].length > 0;
        BOOL isRightFrameRate = [string rangeOfString:@"25.00 tb(r)"].length > 0 || [string rangeOfString:@"29.97 tb(r)"].length > 0 || [string rangeOfString:@"25 tbr"].length > 0 || [string rangeOfString:@"29.97 tbr"].length > 0;
        return isRightVideoFormat && isRightResolution && isRightFrameRate;
    }

    return NO;
}

//Check if the file is a valid SVCD file (return YES if it is valid)
- (BOOL)isSVCD:(NSString *)path
{
    NSString *string = [KWConverter ffmpegOutputForPath:path];
    
    if (string != nil)
    {
        BOOL isRightVideoFormat = [string rangeOfString:@"mpeg2video"].length > 0;
        BOOL isRightResolution = [string rangeOfString:@"480x576"].length > 0 || [string rangeOfString:@"480x480"].length > 0;
        BOOL isRightFrameRate = [string rangeOfString:@"25.00 tb(r)"].length > 0 || [string rangeOfString:@"29.97 tb(r)"].length > 0 || [string rangeOfString:@"25 tbr"].length > 0 || [string rangeOfString:@"29.97 tbr"].length > 0;
        return isRightVideoFormat && isRightResolution && isRightFrameRate;
    }

    return NO;
}

//Check if the file is a valid DVD file (return YES if it is valid)
- (BOOL)isDVD:(NSString *)path isWideAspect:(BOOL *)wideAspect
{
    if ([[path pathExtension] isEqualTo:@"m2v"])
    {
        return NO;
    }
    
    NSString *string = [KWConverter ffmpegOutputForPath:path];
    
    if (string != nil)
    {
        BOOL isRightVideoFormat = [string rangeOfString:@"mpeg2video"].length > 0;
        BOOL isRightResolution = [string rangeOfString:@"720x576"].length > 0 || [string rangeOfString:@"720x480"].length > 0;
        BOOL isRightFrameRate = [string rangeOfString:@"25.00 tb(r)"].length > 0 || [string rangeOfString:@"29.97 tb(r)"].length > 0 || [string rangeOfString:@"25 tbr"].length > 0 || [string rangeOfString:@"29.97 tbr"].length > 0;
        return isRightVideoFormat && isRightResolution && isRightFrameRate;
    }

    return NO;
}

//Check if the file is a valid MPEG4 file (return YES if it is valid)
- (BOOL)isMPEG4:(NSString *)path
{
    NSString *string = [KWConverter ffmpegOutputForPath:path];
    
    if (string)
	    return ([[[path pathExtension] lowercaseString] isEqualTo:@"avi"] && ([string rangeOfString:@"Video: mpeg4"].length > 0 || ([[NSUserDefaults standardUserDefaults] boolForKey:@"KWAllowMSMPEG4"] == YES && [string rangeOfString:@"Video: msmpeg4"].length > 0)));

    return NO;
}

// TODO: combine test methods, if possible
- (NSInteger)isTwentyFourBitsAudio:(NSString *)path
{
    NSString *string = [KWConverter ffmpegOutputForPath:path];
    
    if (string)
        return ([string rangeOfString:@"(24 bit)"].length > 0);

    return NO;
}

//Check for ac3 audio
- (BOOL)containsAC3:(NSString *)path
{
    NSString *string = [KWConverter ffmpegOutputForPath:path];
    
    if (string)
	    return ([string rangeOfString:@"Audio: ac3"].length > 0);

    return NO;
}

///////////////////////
// Framework actions //
///////////////////////

#pragma mark -
#pragma mark •• Framework actions

- (NSArray *)succesArray
{
    return convertedFiles;
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (NSInteger)convertToEven:(NSString *)numberAsString
{
    NSString *convertedNumber = [[NSNumber numberWithInt:[numberAsString intValue]] stringValue];

    unichar ch = [convertedNumber characterAtIndex:[convertedNumber length] -1];
    NSString *lastCharacter = [NSString stringWithFormat:@"%C", ch];

    if ([lastCharacter isEqualTo:@"1"] || [lastCharacter isEqualTo:@"3"] || [lastCharacter isEqualTo:@"5"] || [lastCharacter isEqualTo:@"7"] || [lastCharacter isEqualTo:@"9"])
	    return [[NSNumber numberWithInt:[convertedNumber intValue] + 1] intValue];
    else
	    return [convertedNumber intValue];
}

- (NSInteger)getPadSize:(float)size withAspect:(NSSize)aspect withTopBars:(BOOL)topBars
{
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

    float heightBorder = 0;
    float widthBorder = 0;

    if ([standardDefaults boolForKey:@"KWSaveBorders"] == YES)
    {
	    heightBorder = [[standardDefaults objectForKey:@"KWSaveBorderSize"] floatValue];
	    widthBorder = aspect.width / (aspect.height / size);
    }
    
    if (topBars)
    {
	    return [self convertToEven:[[NSNumber numberWithFloat:(size - (size * (aspect.width / aspect.height)) / inputAspect) / 2 + heightBorder] stringValue]];
    }   
    else
    {
	    return [self convertToEven:[[NSNumber numberWithFloat:(((size * (aspect.width / aspect.height)) / inputAspect) - size) / 2 + widthBorder] stringValue]];
    }
}

- (BOOL)remuxMPEG2File:(NSString *)path outPath:(NSString *)outFile
{
    status = 2;
    NSArray *arguments = [NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-y",@"-acodec",@"copy",@"-vcodec",@"copy",@"-target",@"dvd",outFile, nil];
    //Not used yet
    NSString *errorsString;
    BOOL result = [KWCommonMethods launchNSTaskAtPath:[KWCommonMethods ffmpegPath] withArguments:arguments outputError:YES outputString:YES output:&errorsString];
    status = 0;
    
    if (result)
    {
	    return YES;
    }
    else
    {
	    [KWCommonMethods removeItemAtPath:outFile];
	    return NO;
    }
}

- (BOOL)canCombineStreams:(NSString *)path
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSString *pathWithOutExtension = [path stringByDeletingPathExtension];

    return ([defaultManager fileExistsAtPath:[pathWithOutExtension stringByAppendingPathExtension:@"mp2"]] || [defaultManager fileExistsAtPath:[pathWithOutExtension stringByAppendingPathExtension:@"ac3"]]);
}

- (BOOL)combineStreams:(NSString *)path atOutputPath:(NSString *)outputPath
{
    NSString *audioFile;
    
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSString *pathWithOutExtension = [path stringByDeletingPathExtension];
    NSString *mp2File = [pathWithOutExtension stringByAppendingPathExtension:@"mp2"];
    NSString *ac3File = [pathWithOutExtension stringByAppendingPathExtension:@"ac3"];

    if ([defaultManager fileExistsAtPath:mp2File])
	    audioFile = mp2File;
    else if ([defaultManager fileExistsAtPath:ac3File])
	    audioFile = ac3File;

    if (audioFile)
    {
	    status = 2;
	    NSArray *arguments = [NSArray arrayWithObjects:@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",path,@"-threads",[[NSNumber numberWithInt:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWEncodingThreads"] intValue]] stringValue],@"-i",audioFile,@"-y",@"-acodec",@"copy",@"-vcodec",@"copy",@"-target",@"dvd",outputPath, nil];
	    //Not used yet
	    NSString *errorsString;
	    BOOL result = [KWCommonMethods launchNSTaskAtPath:[KWCommonMethods ffmpegPath] withArguments:arguments outputError:YES outputString:YES output:&errorsString];
	    status = 0;

	    if (result)
	    {
    	    return YES;
	    }
	    else
	    {
    	    [KWCommonMethods removeItemAtPath:outputPath];
    	    return NO;
	    }
    }
    else
    {
	    return NO;
    }
}

- (CGFloat)ffmpegCurrentTimeToSeconds:(NSString *)currentTime
{
    NSArray *parts = [currentTime componentsSeparatedByString:@":"];
    if ([parts count] == 3)
    {
        CGFloat hour = [parts[0] doubleValue];
        CGFloat minutes = [parts[1] doubleValue];
        CGFloat seconds = [parts[2] doubleValue];
        return hour * 60 * 60 + minutes * 60 + seconds;
    }
    
    return 0.0;
}

- (NSInteger)totalTimeInSeconds:(NSString *)path
{
    NSString *string = [KWConverter ffmpegOutputForPath:path];
    NSString *durationsString = [[[[string componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@"."] objectAtIndex:0];

    NSInteger hours = [[[durationsString componentsSeparatedByString:@":"] objectAtIndex:0] intValue];
    NSInteger minutes = [[[durationsString componentsSeparatedByString:@":"] objectAtIndex:1] intValue];
    NSInteger seconds = [[[durationsString componentsSeparatedByString:@":"] objectAtIndex:2] intValue];

    return seconds + (minutes * 60) + (hours * 60 * 60);
}

+ (NSString *)totalTimeString:(NSString *)path
{
    NSString *string = [KWConverter ffmpegOutputForPath:path];
    NSString *durationsString = [[[[string componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:0];
    return durationsString;
}

- (NSString *)mediaTimeString:(NSString *)path
{
    NSString *string = [KWConverter ffmpegOutputForPath:path];
    return [[[[[[[string componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:0] componentsSeparatedByString:@":"] objectAtIndex:1] stringByAppendingString:[@":" stringByAppendingString:[[[[[[string componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:0] componentsSeparatedByString:@":"] objectAtIndex:2]]];
}

- (NSImage *)getImageAtPath:(NSString *)path atTime:(NSInteger)time isWideScreen:(BOOL)wide
{
    // TODO: Change after ffmpeg is updated, used version produces grey images
    //NSArray *arguments = [NSArray arrayWithObjects:@"-ss",[[NSNumber numberWithInt:0] stringValue],@"-i",path,@"-vframes",@"1" ,@"-f",@"image2",@"-", nil];
    NSArray *arguments = @[@"-i", path, @"-ss", [[NSNumber numberWithInt:time] stringValue], @"-vframes", @"1", @"-f", @"image2", @"-"];
    NSData *data;
    NSImage *image;
    BOOL result = [KWCommonMethods launchNSTaskAtPath:[KWCommonMethods ffmpegPath] withArguments:arguments outputError:NO outputString:NO output:&data];
    
    if (result && data)
    {
	    image = [[NSImage alloc] initWithData:data];

	    if (wide)
        {
    	    [image setSize:NSMakeSize(720,404)];
        }
    	    
	    return image;
    }
    else if (result && !data && time > 1)
    {
	    return [self getImageAtPath:path atTime:1 isWideScreen:wide];
    }
	    
    return nil;
}

- (void)setErrorStringWithString:(NSString *)string
{
    if (errorString)
	    errorString = [NSString stringWithFormat:@"%@\n%@", errorString, string];
    else
	    errorString = [string copy];
}

@end

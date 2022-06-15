//
//  KWSVCDImager.m
//  KWSVCDImager
//
//  Created by Maarten Foukhar on 14-3-07.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWSVCDImager.h"
#import "KWProgressManager.h"

@implementation KWSVCDImager

- (id) init
{
    self = [super init];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopVcdimager) name:@"KWStopVcdimager" object:nil];
    userCanceled = NO;
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSInteger)createSVCDImage:(NSString *)path withFiles:(NSArray *)files withLabel:(NSString *)label createVCD:(BOOL)VCD hideExtension:(BOOL)hide errorString:(NSString **)error
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSString *cueFile = [path stringByAppendingPathExtension:@"cue"];
    NSString *binFile = [path stringByAppendingPathExtension:@"bin"];
    totalSize = 0;
    
	    for (NSString *path in files)
	    {
            NSDictionary *attributes = [defaultManager attributesOfItemAtPath:path error:nil];
    	    totalSize += [attributes[NSFileSize] floatValue] / 2048;
	    }
    
    
    if ([defaultManager fileExistsAtPath:cueFile])
    {
	    [KWCommonMethods removeItemAtPath:cueFile];
	    [KWCommonMethods removeItemAtPath:binFile];
    }
    
    NSString *status;
    if ([files count] > 1)
	    status = NSLocalizedString(@"Writing tracks", nil);
    else
	    status = NSLocalizedString(@"Writing track", nil);
    
    KWProgressManager *progressManager = [KWProgressManager sharedManager];
    [progressManager setMaximumValue:totalSize];
    [progressManager setStatus:status];

    NSMutableArray *arguments = [NSMutableArray array];

    [arguments addObject:@"-t"];
    
    if (VCD)
	    [arguments addObject:@"vcd2"];
    else
	    [arguments addObject:@"svcd"];
	    
    [arguments addObject:@"--update-scan-offsets"];
    [arguments addObject:@"-l"];
    [arguments addObject:label];
    [arguments addObject:[@"--cue-file=" stringByAppendingString:cueFile]];
    [arguments addObject:[@"--bin-file=" stringByAppendingString:binFile]];
    [arguments addObjectsFromArray:files];

    vcdimager = [[NSTask alloc] init];
    [vcdimager setLaunchPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"vcdimager" ofType:@""]];
    [vcdimager setArguments:arguments];
    NSPipe *pipe=[[NSPipe alloc] init];
    NSPipe *errorPipe=[[NSPipe alloc] init];
    [vcdimager setCurrentDirectoryPath:[path stringByDeletingLastPathComponent]];
    [vcdimager setStandardOutput:pipe];
    [vcdimager setStandardError:errorPipe];
    NSFileHandle *handle=[pipe fileHandleForReading];
    NSFileHandle *errorHandle=[errorPipe fileHandleForReading];
    [KWCommonMethods logCommandIfNeeded:vcdimager];
    [vcdimager launch];
    
    [[KWProgressManager sharedManager] setCancelHandler:^
    {
        [self stopVcdimager];
    }];

    [self performSelectorOnMainThread:@selector(startTimer:) withObject:binFile waitUntilDone:NO];

    NSData *data;
    NSString *string;

    while([data=[handle availableData] length])
    {
        if ([defaultManager fileExistsAtPath:cueFile])
        {
            [defaultManager setAttributes:@{NSFileExtensionHidden: @(hide)} ofItemAtPath:cueFile error:nil];
        }
        
        if ([defaultManager fileExistsAtPath:binFile])
        {
            [defaultManager setAttributes:@{NSFileExtensionHidden: @(hide)} ofItemAtPath:binFile error:nil];
        }

        string=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
        KWLog(@"%@", string);
    }
    
    [vcdimager waitUntilExit];
    
    NSString *errorString = [[NSString alloc] initWithData:[errorHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
    
    [timer invalidate];

    [[KWProgressManager sharedManager] setCancelHandler:nil];

    NSInteger taskStatus = [vcdimager terminationStatus];
       
    if (taskStatus == 0)
    {
	    return 0;
    }
    else
    {
	    *error = [NSString stringWithFormat:@"KWConsole:\nTask: vcdimager\n%@", errorString];
	    
	    [KWCommonMethods removeItemAtPath:cueFile];
	    [KWCommonMethods removeItemAtPath:binFile];
	    
	    if (userCanceled)
    	    return 2;
	    else
    	    return 1;
    }
}

- (void)startTimer:(NSArray *)object
{
    timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(imageProgress:) userInfo:object repeats:YES];
}

- (void)imageProgress:(NSTimer *)theTimer
{
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[theTimer userInfo] error:nil];
    float currentSize = [attributes[NSFileSize] floatValue] / 2048;
    float percent = currentSize / totalSize * 100;
    
    KWProgressManager *progressManager = [KWProgressManager sharedManager];
    
    if (percent < 101)
    {
        [progressManager setStatusByAddingPercent:[NSString stringWithFormat:@" (%.0f%@)", percent, @"%"]];
    }
    
    [progressManager setValue:currentSize];
}

- (void)stopVcdimager
{
    userCanceled = YES;
    [vcdimager terminate];
}

@end

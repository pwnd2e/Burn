//
//  KWAudioTrackCalculator.m
//  Burn
//
//  Created by Maarten Foukhar on 16/08/2019.
//

#import <DiscRecording/DiscRecording.h>

#import "KWAudioTrackCalculator.h"
#import "KWCommonMethods.h"
#import "KWConverter.h"

@interface DRCallbackDevice : DRDevice
- (void)initWithConsumer:(id)consumer;
@end

@interface KWAudioTrackCalculator()

@property (nonatomic) NSInteger trackSize;
@property (copy) void(^completion)(NSInteger trackSize);

@end

@implementation KWAudioTrackCalculator
{
    FILE *_file;
    DRCallbackDevice *device;
}

- (DRDevice *)device
{
    if (device == nil)
    {
        device = [[DRCallbackDevice alloc] init];
        [device initWithConsumer:self];
    }
    
    return device;
}

- (void)getAudioTrackSizeForPath:(NSString *)path completion:(void (^)(NSInteger trackSize))completion
{
    [self setCompletion:completion];

    DRCallbackDevice *device = [[DRCallbackDevice alloc] init];
    [device initWithConsumer:self];
    DRBurn *burn = [[DRBurn alloc] initWithDevice:device];
    
    [burn writeLayout:[self getAudioTrackForPath:path]];
}

- (DRTrack *)getAudioTrackForPath:(NSString *)path
{
    DRTrack *track = [[DRTrack alloc] initWithProducer:self];
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    [properties setObject:@([self audioTrackSizeAtPath:path]) forKey:DRTrackLengthKey];
    [properties setObject:[NSNumber numberWithInt:2048] forKey:DRBlockSizeKey];
    [properties setObject:[NSNumber numberWithInt:0] forKey:DRBlockTypeKey];
    [properties setObject:[NSNumber numberWithInt:0] forKey:DRDataFormKey];
    [properties setObject:[NSNumber numberWithInt:0] forKey:DRSessionFormatKey];
    [properties setObject:[NSNumber numberWithInt:0] forKey:DRTrackModeKey];
    [properties setObject:path forKey:@"KWAudioPath"];
    [properties setObject:[NSNumber numberWithBool:YES] forKey:@"KWFirstTrack"];
    
    [track setProperties:properties];

    return track;
}

- (NSUInteger)audioTrackSizeAtPath:(NSString *)path
{
    NSTask *ffmpeg = [[NSTask alloc] init];
    NSPipe *outPipe = [[NSPipe alloc] init];
    NSFileHandle *outHandle = [outPipe fileHandleForReading];
    [ffmpeg setLaunchPath:[KWCommonMethods ffmpegPath]];

    NSArray *arguments = [NSArray arrayWithObjects:@"-i", path, @"-f", @"s16le", @"-ac", @"2", @"-ar", @"44100"," @"-", nil];

    [ffmpeg setArguments:arguments];
    [ffmpeg setStandardOutput:outPipe];

    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"])
        [ffmpeg setStandardError:[NSFileHandle fileHandleWithNullDevice]];

    [KWCommonMethods logCommandIfNeeded:ffmpeg];
    [ffmpeg launch];
    NSUInteger size = 0;

    NSData *data;

    while([data=[outHandle availableData] length])
    {
        size = size + [data length];
    }

    [ffmpeg waitUntilExit];

    return size / 2352;
}

- (void)createAudioTrack:(NSString *)path
{
    NSTask *trackCreator = [[NSTask alloc] init];

    NSPipe *calcPipe = [[NSPipe alloc] init];
    NSPipe *trackPipe = [[NSPipe alloc] init];

    NSFileHandle *calcHandle = [calcPipe fileHandleForReading];
    NSFileHandle *writeHandle = [trackPipe fileHandleForWriting];
    NSFileHandle *readHandle = [trackPipe fileHandleForReading];

    [trackCreator setLaunchPath:[KWCommonMethods ffmpegPath]];
    
    NSArray *arguments = [NSArray arrayWithObjects:@"-i", path, @"-f", @"s16le", @"-ac", @"2", @"-ar", @"44100", @"-", nil];
    [trackCreator setArguments:arguments];
    [trackCreator setStandardOutput:calcPipe];
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"KWDebug"])
    {
        [trackCreator setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    }
    
    [KWCommonMethods logCommandIfNeeded:trackCreator];

    _file = fdopen([readHandle fileDescriptor], "r");
    
    [[[NSOperationQueue alloc] init] addOperationWithBlock:^
    {
        [trackCreator launch];


        float size = 0;
    
        NSData *data;
        NSMutableData *testData = [[NSMutableData alloc] init];
        while([data = [calcHandle availableData] length])
        {
            [writeHandle writeData:data];
            [testData appendData:data];
            size = size + [data length];
        }
        
        NSLog(@"End size 002: %f", size);
        NSLog(@"Real end size: %li", (long)[self trackSize]);
        
        [testData writeToFile:[@"~/Desktop/lala-real.img" stringByExpandingTildeInPath] atomically:YES];
        
        [trackCreator waitUntilExit];
        
        if ([self completion] != nil)
        {
            [self completion]([self trackSize]);
        }
        
//        NSLog(@"trackCreator - done -");
//        [writeHandle closeFile];
//        [readHandle closeFile];
//        [calcHandle closeFile];
//        NSLog(@"trackCreator closed");
    }];
}

#pragma mark - Image Methods

- (BOOL)writeBlocks:(char *)wBlocks blockCount:(uint32_t)bCount blockSize:(uint32_t)bSize atAddress:(uint64_t)address
{
    return NO;
}

- (BOOL)prepareBurn:(DRBurn *)burnObject
{
    return NO;
}

- (BOOL)prepareTrack:(id)track trackIndex:(id)index
{
//    NSInteger trackNumber = [self trackNumber];
//    [self setTrackNumber:trackNumber + 1];
    return NO;
}

- (BOOL)prepareSession:(id)session sessionIndex:(id)index
{
    return NO;
}

- (BOOL)cleanupSessionAfterBurn:(id)session sessionIndex:(id)index
{
    return NO;
}

- (BOOL)cleanupAfterBurn:(DRBurn *)burnObject
{
    return NO;
}

- (BOOL)cleanupTrackAfterBurn:(DRTrack *)track trackIndex:(id)index
{
    return NO;
}

@end

@interface KWAudioTrackCalculator (DiscRecording)

- (BOOL) prepareTrack:(DRTrack *)track forBurn:(DRBurn *)burn toMedia:(NSDictionary *)mediaInfo;
- (uint32_t)producePreGapForTrack:(DRTrack *)track intoBuffer:(char *)buffer length:(uint32_t)bufferLength atAddress:(uint64_t)address blockSize:(uint32_t)blockSize ioFlags:(uint32_t *)flags;
- (uint32_t)produceDataForTrack:(DRTrack *)track intoBuffer:(char *)buffer length:(uint32_t)bufferLength atAddress:(uint64_t)address blockSize:(uint32_t)blockSize ioFlags:(uint32_t *)flags;

@end


@implementation KWAudioTrackCalculator (DiscRecording)

- (BOOL)prepareTrack:(DRTrack *)track forBurn:(DRBurn *)burn toMedia:(NSDictionary *)mediaInfo
{
    [self createAudioTrack:[[track properties] objectForKey:@"KWAudioPath"]];

    return YES;
}

- (uint32_t)producePreGapForTrack:(DRTrack *)track intoBuffer:(char *)buffer length:(uint32_t)bufferLength atAddress:(uint64_t)address blockSize:(uint32_t)blockSize ioFlags:(uint32_t *)flags
{
    memset(buffer, 0, bufferLength);
    
    return bufferLength;
}

- (uint32_t)produceDataForTrack:(DRTrack *)track intoBuffer:(char *)buffer length:(uint32_t)bufferLength atAddress:(uint64_t)address blockSize:(uint32_t)blockSize ioFlags:(uint32_t *)flags
{
    NSLog(@"address: %llu, %u", address, bufferLength);

    if (_file)
    {
        uint32_t i;
        for (i = 0; i < bufferLength; i+= blockSize)
        {
            fread(buffer, 1, blockSize, _file);
            buffer += blockSize;
            [self setTrackSize:address + i + blockSize];
        }
    }

    return bufferLength;
}

- (void)cleanupTrackAfterBurn:(DRTrack *)track;
{
    fclose(_file);
}

@end


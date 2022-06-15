#import "KWDVDInspector.h"
#import "KWVideoController.h"
#import "KWConverter.h"
#import "KWCommonMethods.h"
#import <AVKit/AVKit.h>

@interface KWDVDInspector()

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, weak) IBOutlet AVPlayerView *playerView;
@property (nonatomic, weak) IBOutlet NSButton *addButton;


@end

@implementation KWDVDInspector

- (id)init
{
    self = [super init];

    tableData = [[NSMutableArray alloc] init];

    return self;
}

- (void)updateView:(id)object
{
    currentTableView = object;
    currentObject = [[(KWVideoController *)[object dataSource] myDataSource] objectAtIndex:[object selectedRow]];

    [nameField setStringValue:[currentObject objectForKey:@"Name"]];
    [timeField setStringValue:[currentObject objectForKey:@"Size"]];
    [iconView setImage:[currentObject objectForKey:@"Icon"]];

    [tableData removeAllObjects];
    
    if ([currentObject objectForKey:@"Chapters"])
	    [tableData addObjectsFromArray:[currentObject objectForKey:@"Chapters"]];

    [tableView reloadData];
    
    NSString *path = [currentObject objectForKey:@"Path"];
    
    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
    CMTime duration = [asset duration];
    
    [timeSlider setMaxValue:CMTimeGetSeconds(duration)];
    [timeSlider setDoubleValue:0];
    [[self addButton] setEnabled:[self dictionaryForSeconds:0] == nil];
    
    CMTime interval = CMTimeMake(1, 1);
    CMTime currentTime = kCMTimeZero;
    NSMutableArray *times = [NSMutableArray array];
    
    while (CMTIME_COMPARE_INLINE(currentTime, <, duration))
    {
        currentTime = CMTimeAdd(currentTime, interval);
        [times addObject:[NSValue valueWithCMTime:currentTime]];
    }
    
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
    [player addBoundaryTimeObserverForTimes:times queue:dispatch_get_main_queue() usingBlock:^
    {
        CMTime time = [[[self playerView] player] currentTime];
        int seconds = CMTimeGetSeconds(time);
        NSString *formatedTime = [KWCommonMethods formatTime:seconds];
        [currentTimeField setStringValue:formatedTime];
        [[self addButton] setEnabled:[self dictionaryForSeconds:(NSInteger)seconds] == nil];
    }];
    [[self playerView] setPlayer:player];
}

- (IBAction)add:(id)sender
{
    [titleField setStringValue:@""];
    [NSApp beginSheet:chapterSheet modalForWindow:[myView window] modalDelegate:self didEndSelector:@selector(endChapterSheet) contextInfo:nil];
}

- (void)endChapterSheet
{
    [chapterSheet orderOut:self];
}

- (IBAction)addSheet:(id)sender
{
    NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
    
    AVPlayer *player = [[self playerView] player];
    
    CMTime currentTime = [player currentTime];
    CGFloat currentSeconds = CMTimeGetSeconds(currentTime);

    [rowData setObject:[KWCommonMethods formatTime:(NSInteger)currentSeconds] forKey:@"Time"];
    [rowData setObject:[titleField stringValue] forKey:@"Title"];
    [rowData setObject:[NSNumber numberWithDouble:currentSeconds] forKey:@"RealTime"];
    
    NSImage *previewImage = [self previewImage];
    if (previewImage != nil)
    {
        [rowData setObject:[previewImage TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0] forKey:@"Image"];
    }
    
    NSDictionary *foundDictionary = [self dictionaryForSeconds:(NSInteger)currentSeconds];
    if (foundDictionary)
    {
        [tableData replaceObjectAtIndex:[tableData indexOfObject:foundDictionary] withObject:rowData];
    }
    else
    {
        [tableData addObject:rowData];
    }

    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"Time" ascending:YES];
    [tableData sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    
    NSMutableDictionary *tempDict = [NSMutableDictionary dictionaryWithDictionary:currentObject];
    NSMutableArray *controller = [(KWVideoController *)[currentTableView dataSource] myDataSource];
    
    [tempDict setObject:[NSArray arrayWithArray:tableData] forKey:@"Chapters"];
    [controller replaceObjectAtIndex:[currentTableView selectedRow] withObject:[tempDict copy]];
    
    currentObject = [controller objectAtIndex:[currentTableView selectedRow]];

    [tableView reloadData];
    
    [[self addButton] setEnabled:NO];
}

- (IBAction)cancelSheet:(id)sender
{
    [[chapterSheet sheetParent] endSheet:chapterSheet];
}

- (IBAction)remove:(id)sender
{
    NSIndexSet *selectedRowIndexes = [tableView selectedRowIndexes];
    [tableData removeObjectsAtIndexes:selectedRowIndexes];
    
    NSMutableDictionary *tempDict = [NSMutableDictionary dictionaryWithDictionary:currentObject];
    NSMutableArray *controller = [(KWVideoController *)[currentTableView dataSource] myDataSource];

    [tempDict setObject:[NSArray arrayWithArray:tableData] forKey:@"Chapters"];

    [controller replaceObjectAtIndex:[currentTableView selectedRow] withObject:[tempDict copy]];

    [tableView deselectAll:nil];
    [tableView reloadData];
}

- (IBAction)timeSlider:(id)sender
{
    AVPlayer *player = [[self playerView] player];
    CGFloat seekTime = [timeSlider doubleValue];
    [currentTimeField setStringValue:[KWCommonMethods formatTime:(NSInteger)seekTime]];
    [player seekToTime:CMTimeMake(seekTime, 1)];
    
    [[self addButton] setEnabled:[self dictionaryForSeconds:(NSInteger)seekTime] == nil];
}

///////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{    return NO; }

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
    return [tableData count];
}

- (id) tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
    row:(NSInteger)row
{
    NSDictionary *rowData = [tableData objectAtIndex:row];
    return [rowData objectForKey:[tableColumn identifier]];
}

- (void)tableView:(NSTableView *)tableView
    setObjectValue:(id)anObject
    forTableColumn:(NSTableColumn *)tableColumn
    row:(NSInteger)row
{
    NSMutableDictionary *rowData = [tableData objectAtIndex:row];
    [rowData setObject:anObject forKey:[tableColumn identifier]];
}

- (id)myView
{
    return myView;
}

#pragma mark - Convenient Methods

- (NSDictionary *)dictionaryForSeconds:(CGFloat)seconds
{
    for (NSDictionary *dictionary in tableData)
    {
        NSInteger timeSeconds = [dictionary[@"RealTime"] integerValue];
        if ((NSInteger)seconds == timeSeconds)
        {
            return dictionary;
        }
    }
    
    return nil;
}

- (NSImage *)previewImage
{
    CMTime actualTime;
    NSError *error;

    AVPlayer *player = [[self playerView] player];
    CMTime time = [player currentTime];
    
    AVPlayerItem *item = [player currentItem];
    AVAsset *asset = [item asset];
    
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    [generator setAppliesPreferredTrackTransform:YES];
    [generator setRequestedTimeToleranceBefore:kCMTimeZero];
    [generator setRequestedTimeToleranceAfter:kCMTimeZero];
    CGImageRef cgImage = [generator copyCGImageAtTime:time actualTime:&actualTime error:&error];
    
    if (error == nil)
    {
        int width = CGImageGetWidth(cgImage);
        int height = CGImageGetHeight(cgImage);
        NSImage *image = [[NSImage alloc] initWithCGImage:cgImage size:NSMakeSize(width, height)];
        CGImageRelease(cgImage);
        return image;
    }
    
    return nil;
}

@end

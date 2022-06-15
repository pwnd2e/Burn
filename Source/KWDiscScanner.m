#import "KWDiscScanner.h"
#import "KWCommonMethods.h"

@implementation KWDiscScanner

//We need to have table datasource
- (id)init
{
    self = [super init];

    tableData = [[NSMutableArray alloc] init];
    
    [[NSBundle mainBundle] loadNibNamed:@"KWDiscScanner" owner:self topLevelObjects:nil];
    
    [tableView setDoubleAction:@selector(chooseScan:)];
    
    NSWorkspace *sharedWorkspace = [NSWorkspace sharedWorkspace];
    [[sharedWorkspace notificationCenter] addObserver:self selector:@selector(beginScanning) name:NSWorkspaceDidMountNotification object:nil];
    [[sharedWorkspace notificationCenter] addObserver:self selector:@selector(beginScanning) name:NSWorkspaceDidUnmountNotification object:nil];
   
    return self;
}

//Delocate datasource
- (void)dealloc
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)beginSetupSheetForWindow:(NSWindow *)window modelessDelegate:(id)modelessDelegate didEndSelector:(SEL)didEndSelector contextInfo:(void *)contextInfo
{
    [self beginScanning];
    [NSApp beginSheet:[self window] modalForWindow:window modalDelegate:modelessDelegate didEndSelector:didEndSelector contextInfo:contextInfo];
}

//Check for removable disks, also check their bsd name and if they're read only
- (void)scanDisks
{
    NSString *rootName = @"";
    NSArray *mountedRemovableMedia = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];
    
    NSInteger i;
    for( i=0; i<[mountedRemovableMedia count]; i++ )
    {
	    NSString *path = [mountedRemovableMedia objectAtIndex:i];
	    
	    NSString *string;
	    NSArray *arguments = [NSArray arrayWithObjects:@"info", path, nil];
	    BOOL success = [KWCommonMethods launchNSTaskAtPath:@"/usr/sbin/diskutil" withArguments:arguments outputError:NO outputString:YES output:&string];
	    NSDictionary *information = nil;
	    
	    if (success)
    	    information = [KWCommonMethods getDictionaryFromString:string];
	    
	    if (information)
	    {
    	    rootName = [@"/dev/rdisk" stringByAppendingString:[[[information objectForKey:@"Device Node"] componentsSeparatedByString:@"/dev/disk"] objectAtIndex:1]];
	    
    	    if ([[information objectForKey:@"Read Only"] boolValue] == YES || [[information objectForKey:@"Read-Only Media"] boolValue] == YES )
    	    { 
	    	    NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
	    
	    	    NSInteger size = [KWCommonMethods getSizeFromMountedVolume:path] * 512;

	    	    [rowData setObject:[path lastPathComponent] forKey:@"Name"];
	    	    [rowData setObject:[[[NSWorkspace sharedWorkspace] iconForFile:path] copy] forKey:@"Icon"];
	    	    [rowData setObject:[KWCommonMethods makeSizeFromFloat:size] forKey:@"Device"];
	    	    [rowData setObject:path forKey:@"Mounted Path"];
    	    
	    	    [tableData addObject:rowData];
          
                [[NSOperationQueue mainQueue] addOperationWithBlock:^
                {
                    [tableView reloadData];
                }];
    	    }
	    }
     
        [[NSOperationQueue mainQueue] addOperationWithBlock:^
        {
            [cancelScan setEnabled:YES];
            [progressScan setHidden:YES];
        
            if (![rootName isEqualTo:@""])
            {
                [progressTextScan setHidden:YES];
                [chooseScan setEnabled:YES];
            }
            else
            {
                [progressTextScan setStringValue:NSLocalizedString(@"No discs, try inserting a cd/dvd.", nil)];
                [chooseScan setEnabled:NO];
            }
        }];
    }
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^
    {
        if ([mountedRemovableMedia count] == 0)
        {
            [progressTextScan setStringValue:NSLocalizedString(@"No discs, try inserting a cd/dvd.", nil)];
            [chooseScan setEnabled:NO];
            [cancelScan setEnabled:YES];
            [progressScan setHidden:YES];
        }
        
        [progressScan stopAnimation:self];
    }];
}

//Throw the scanning in a thread, so the app stays responding
-(void)beginScanning
{
    [cancelScan setEnabled:NO];
    [chooseScan setEnabled:NO];
    [progressScan setHidden:NO];
    [progressTextScan setHidden:NO];
    [progressTextScan setStringValue:NSLocalizedString(@"Scanning for disks...", nil)];
    [progressScan startAnimation:self];
    [tableData removeAllObjects];
    [tableView reloadData];
    
    [self scanDisks];
}

///////////////////////
// Interface actions //
///////////////////////

#pragma mark -
#pragma mark •• Interface actions

- (IBAction)chooseScan:(id)sender
{
    NSWindow *window = [self window];
    [[window sheetParent] endSheet:window returnCode:NSModalResponseOK];
}

- (IBAction)cancelScan:(id)sender
{
    NSWindow *window = [self window];
    [[window sheetParent] endSheet:window returnCode:NSModalResponseCancel];
}

////////////////////
// Output actions //
////////////////////

#pragma mark -
#pragma mark •• Output actions

//Return disk to use
- (NSString *)disk
{
    if ([tableView selectedRow] == -1)
	    return nil;
    else
	    return [[tableData objectAtIndex:[tableView selectedRow]] objectForKey:@"Mounted Path"];
}

- (NSString *)name
{
    if ([tableView selectedRow] == -1)
	    return nil;
    else
	    return [[[tableData objectAtIndex:[tableView selectedRow]] objectForKey:@"Name"] lastPathComponent];
}

- (NSImage *)image
{
    if ([tableView selectedRow] == -1)
	    return nil;
    else
	    return [[tableData objectAtIndex:[tableView selectedRow]] objectForKey:@"Icon"];
}

///////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{    
    return NO;
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
    return [tableData count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSDictionary *rowData = [tableData objectAtIndex:row];
    return [rowData objectForKey:[tableColumn identifier]];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSMutableDictionary *rowData = [tableData objectAtIndex:row];
    [rowData setObject:anObject forKey:[tableColumn identifier]];
}

@end

#import "KWDataInspector.h"
#import <DiscRecording/DiscRecording.h>

#import "HFSPlusController.h"
#import "ISOController.h"
#import "JolietController.h"
#import "UDFController.h"
#import "KWCommonMethods.h"
#import "KWDRFolder.h"

@implementation KWDataInspector

- (id)init
{
    if( self = [super init] )
    {
	    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(leaveTab) name:@"KWLeaveTab" object:nil];

	    shouldChangeTab = YES;
    }
    
    return self;
}

- (void)dealloc 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

- (void)updateView:(NSArray *)objects
{
    id firstObject = [objects objectAtIndex:0];

    if ([objects count] == 1)
    {
	    [nameField setStringValue:[KWCommonMethods fsObjectFileName:firstObject]];
	    
	    NSImage *iconImage;
    
	    if ([firstObject isKindOfClass:[KWDRFolder class]])
	    {
    	    NSString *folderSize = [(KWDRFolder *)firstObject folderSize];
	    
    	    if (folderSize)
	    	    [sizeField setStringValue:folderSize];
    	    else
	    	    [sizeField setStringValue:@"--"];
	    }
	    else
	    {
    	    NSString *sourcePath = [firstObject sourcePath];
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:sourcePath error:nil];
    	    float size = [attributes[NSFileSize] floatValue];
    	    [sizeField setStringValue:[KWCommonMethods makeSizeFromFloat:size]];
    	    
	    }
	    
	    iconImage = [KWCommonMethods getIcon:firstObject];
        
	    [iconImage setSize:NSMakeSize(32.0,32.0)];
	    [iconView setImage:iconImage];
    }
    else
    {
	    [iconView setImage:[NSImage imageNamed:@"Multiple"]];
	    [nameField setStringValue:@"Multiple Selection"];
	    [sizeField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%ld files", nil),(long)[objects count]]];
    }

    [hfsController inspect:objects];
    [isoController inspect:objects];
    [jolietController inspect:objects];
    [udfController inspect:objects];
    
    if (shouldChangeTab)
    {
	    if ([firstObject effectiveFilesystemMask] & DRFilesystemInclusionMaskHFSPlus)
	    {
    	    [tabs selectTabViewItemWithIdentifier:@"HFS+"];
	    }
	    else if ([firstObject effectiveFilesystemMask] & DRFilesystemInclusionMaskISO9660)
	    {
    	    [tabs selectTabViewItemWithIdentifier:@"ISO"];
	    }
	    else if ([firstObject effectiveFilesystemMask] & DRFilesystemInclusionMaskJoliet)
	    {
    	    [tabs selectTabViewItemWithIdentifier:@"Joliet"];
	    }
	    else if ([firstObject effectiveFilesystemMask] & DRFilesystemInclusionMaskUDF)
	    {
            [tabs selectTabViewItemWithIdentifier:@"UDF"];
	    }
    }

    shouldChangeTab = YES;
}

- (id)myView
{
    return myView;
}

- (void)leaveTab
{
    shouldChangeTab = NO;
}

@end

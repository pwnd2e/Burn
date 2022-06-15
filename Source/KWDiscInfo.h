/* KWDiscInfo */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

/**
 *  A panel showing info about the current disc
 */
@interface KWDiscInfo : NSWindowController

/**
 *  Show a panel
 *
 *  @param device The device (and its disc) used to setup the panel with
 */
- (void)showDiskInfoForDevice:(DRDevice *)device;

@end

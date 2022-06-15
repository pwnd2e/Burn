/* KWRecorderInfo */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

/**
 *  A panel showing info about the current recorder
 */
@interface KWRecorderInfo : NSWindowController

/**
 *  Show the recorder info panel
 *
 *  @param device The recorder device
 */
- (void)showRecorderInfoForDevice:(DRDevice *)device;

@end

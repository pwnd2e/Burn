/* KWEjecter */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

/**
 *  Handles ejecting discs
 */
@interface KWEjecter : NSWindowController

/**
 *  Start eject sheet
 *
 *  @param attachWindow The parent window
 *  @param device The device to select in the pop up
 */
- (void)startEjectSheetForWindow:(NSWindow *)atachWindow forDevice:(DRDevice *)device;

@end

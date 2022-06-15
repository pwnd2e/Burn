/* KWEraser */

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import "KWCommonMethods.h"

/**
 *  A class that handles showing an erase sheet and erasing discs
 */
@interface KWEraser : NSWindowController

/**
 *  Begin erase sheet for window
 *
 *  @param modalWindow A modal window
 *  @param completion Called after erasing or cancelation
 */
- (void)beginEraseSheetForWindow:(NSWindow *)modalWindow completion:(void (^)(NSDictionary *response))completion;

@end

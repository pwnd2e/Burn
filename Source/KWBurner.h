/* KWBurner */

#import <Cocoa/Cocoa.h>

/**
 *  A window controller that handles burning (and creating disc images, burning to the hard disk)
 */
@interface KWBurner : NSWindowController

/**
 *  Show a burn setup sheet
 *
 *  @param window The modal window
 *  @param completion Send when the sheet closes with a return code
 */
- (void)beginBurnSetupSheetForWindow:(NSWindow *)window completion:(void (^)(NSModalResponse returnCode))completion;

/**
 *  Ignore mode enabled or not
 */
@property (nonatomic, getter = isIgnoreModeEnabled) BOOL ignoreModeEnabled;

/**
 *  Burn properties
 */
@property (nonatomic, copy) NSDictionary *properties;

/**
 *  Burn extra properties
 */
@property (nonatomic, copy) NSDictionary *extraBurnProperties;

/**
 *  The burn type
 */
@property (nonatomic) NSInteger type;

/**
 *  Combine sessions enabled or not
 */
@property (nonatomic, getter = isCombineSessionsEnabled) BOOL combineSessionsEnabled;

/**
 *  Combine data sessions enabled or not
 */
@property (nonatomic, getter = isCombinedDataSessionEnabled) BOOL combinedDataSessionEnabled;

/**
 *  Combine audio sessions enabled or not
 */
@property (nonatomic, getter = isCombinedAudioSessionEnabled) BOOL combinedAudioSessionEnabled;

/**
 *  Combine video sessions enabled or not
 */
@property (nonatomic, getter = isCombinedVideoSessionEnabled) BOOL combinedVideoSessionEnabled;

/**
 *  Combinable types
 */
@property (nonatomic, strong) NSArray *combinableTypes; // TODO: Is this used or usefull to expose?

/**
 *  Get types
 *
 *  @return An array of types
 */
- (NSArray *)types;

/**
 *  If the current disc is a CD
 *
 * @return YES or NO
 */
- (BOOL)isCD;

@end

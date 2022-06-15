//
//  KWDVDAuthorizer.h
//  KWDVDAuthorizer
//
//  Created by Maarten Foukhar on 16-3-07.
//  Copyright 2007 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/**
 *  Creates an authorised DVD-Video folder either with or without a menu
 */
@interface KWDVDAuthorizer : NSObject

/**
 *  Create a standard DVD-Video folder
 *
 *  @param path The path to create the folder at
 *  @param fileArray An array of video files
 *  @param maxProgressSize The maximum progress size
 *  @param error An error string
 */
- (NSInteger)createStandardDVDFolderAtPath:(NSString *)path withFileArray:(NSArray *)fileArray withMaxProgressSize:(CGFloat)maxProgressSize errorString:(NSString **)error;

/**
 *  Create a menu based DVD-Video folder
 *
 *  @param path The path to create the folder at
 *  @param theme The theme to use
 *  @param fileArray An array of video files
 *  @param maxProgressSize The maximum progress size
 *  @param error An error string
 */
- (NSInteger)createDVDMenuFiles:(NSString *)path withTheme:(NSDictionary *)theme withFileArray:(NSArray *)fileArray withMaxProgressSize:(CGFloat)maxProgressSize withName:(NSString *)name errorString:(NSString **)error;

/**
 *  Create a standard DVD-Audio folder
 *
 *  @param path A path to create the folder
 *  @param files Wave files
 *  @param error An error string
 */
- (NSInteger)createStandardDVDAudioFolderAtPath:(NSString *)path withFiles:(NSArray *)files errorString:(NSString **)error;

/**
 *  Get a preview image from a theme
 *
 *  @param theme The theme
 *  @param type The screen type
 */
 // TODO: clearify type (enum, etcetera)
- (NSImage *)getPreviewImageFromTheme:(NSDictionary *)theme ofType:(NSInteger)type;

@end

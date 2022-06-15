//
//  KWDiscCreator.h
//  Burn
//
//  Created by Maarten Foukhar on 15-11-08.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/**
 *  A class that creates disc images and burned discs
 */
@interface KWDiscCreator : NSObject 

/**
 *  Save image
 *
 *  @param name The image file name to use
 *  @param type The image file type
 *  @param fileSystem The file system to use
 */
- (void)saveImageWithName:(NSString *)name withType:(NSInteger)type withFileSystem:(NSString *)fileSystem;

/**
 *  Burn a disc
 *
 *  @param name The image file name to use
 *  @param type The image file type
 */
- (void)burnDiscWithName:(NSString *)name withType:(NSInteger)type;

@end

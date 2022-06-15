//
//  KWTrackProducer.h
//  Burn
//
//  Created by Maarten Foukhar on 26-11-08.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

/**
 *  Produces different kind of tracks to burn, creates raw data on the fly
 */
@interface KWTrackProducer : NSObject

/**
 *  Get tracks for a cue file
 *
 *  @param path The cue file path
 */
- (NSArray *)getTracksOfCueFile:(NSString *)path;

/**
 *  Get tracks for an image file
 *
 *  @param path The image file path
 *  @param size The size
 */
- (DRTrack *)getTrackForImage:(NSString *)path withSize:(NSInteger)size;

/**
 *  Get tracks for an folder
 *
 *  @param path The folder path
 *  @param imageType The image type
 *  @param name A disc name
 */
- (DRTrack *)getTrackForFolder:(NSString *)path ofType:(NSInteger)imageType withDiscName:(NSString *)name;

/**
 *  Get tracks for VCD mpeg files
 *
 *  @param files An array of files
 *  @param name A disc name
 *  @param imageType The image type
 */
- (NSArray *)getTrackForVCDMPEGFiles:(NSArray *)files withDiscName:(NSString *)name ofType:(NSInteger)imageType;

/**
 *  Get track of an Audio CD (TOC)
 *
 *  @param path A path of the binary file
 *  @param toc The TOC information
 */
- (NSArray *)getTracksOfAudioCD:(NSString *)path withToc:(NSDictionary *)toc;

/**
 *  Get an audio track for a given path
 *
 *  @param path A file path
 */
- (DRTrack *)getAudioTrackForPath:(NSString *)path;

@end

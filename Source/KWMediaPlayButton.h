//
//  KWMediaPlayButton.h
//  Burn
//
//  Created by Maarten Foukhar on 03/07/2019.
//

#import <Cocoa/Cocoa.h>

@interface KWMediaPlayButton : NSButton

@property (nonatomic, getter = isPlaying) BOOL playing;

@end

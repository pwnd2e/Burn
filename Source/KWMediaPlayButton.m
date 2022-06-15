//
//  KWMediaPlayButton.m
//  Burn
//
//  Created by Maarten Foukhar on 03/07/2019.
//

#import "KWMediaPlayButton.h"
#import "KWCommonMethods.h"

@implementation KWMediaPlayButton

- (void)layout
{
    [super layout];
    
    [self setImage:[NSImage imageNamed:isAppearanceIsDark([self effectiveAppearance]) ? ([self isPlaying] ? @"Pause (dark)" : @"Play (dark)") : ([self isPlaying] ? @"Pause" : @"Play")]];
}

- (void)setPlaying:(BOOL)playing
{
    _playing = playing;
    
    [self setNeedsLayout:YES];
}

@end

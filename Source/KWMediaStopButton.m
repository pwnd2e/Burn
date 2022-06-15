//
//  KWMediaStopButton.m
//  Burn
//
//  Created by Maarten Foukhar on 03/07/2019.
//

#import "KWMediaStopButton.h"
#import "KWCommonMethods.h"

@implementation KWMediaStopButton

- (void)layout
{
    [super layout];
    
    [self setImage:[NSImage imageNamed:isAppearanceIsDark([self effectiveAppearance]) ? @"Stop (dark)" : @"Stop"]];
}

@end

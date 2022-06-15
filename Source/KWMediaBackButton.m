//
//  KWMediaBackButton.m
//  Burn
//
//  Created by Maarten Foukhar on 03/07/2019.
//

#import "KWMediaBackButton.h"
#import "KWCommonMethods.h"

@implementation KWMediaBackButton

- (void)layout
{
    [super layout];
    
    [self setImage:[NSImage imageNamed:isAppearanceIsDark([self effectiveAppearance]) ? @"Back (dark)" : @"Back"]];
}

@end

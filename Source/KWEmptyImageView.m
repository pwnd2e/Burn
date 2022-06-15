//
//  KWEmptyImageView.m
//  Burn
//
//  Created by Maarten Foukhar on 03/07/2019.
//

#import "KWEmptyImageView.h"
#import "KWCommonMethods.h"

@implementation KWEmptyImageView

- (void)layout
{
    [super layout];
    
    [self setImage:[NSImage imageNamed:isAppearanceIsDark([self effectiveAppearance]) ? @"Empty (dark)" : @"Empty"]];
}

@end

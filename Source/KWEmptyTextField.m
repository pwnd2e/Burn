//
//  KWEmptyTextField.m
//  Burn
//
//  Created by Maarten Foukhar on 03/07/2019.
//

#import "KWEmptyTextField.h"
#import "KWCommonMethods.h"

@implementation KWEmptyTextField

- (void)layout
{
    [super layout];
    
    [self setTextColor:isAppearanceIsDark([self effectiveAppearance]) ? [NSColor controlColor] : [NSColor controlShadowColor]];
}

@end

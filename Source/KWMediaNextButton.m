//
//  KWMediaNextButton.m
//  Burn
//
//  Created by Maarten Foukhar on 03/07/2019.
//

#import "KWMediaNextButton.h"
#import "KWCommonMethods.h"

@implementation KWMediaNextButton

- (void)layout
{
    [super layout];
    
    [self setImage:[NSImage imageNamed:isAppearanceIsDark([self effectiveAppearance]) ? @"Forward (dark)" : @"Forward"]];
}

@end

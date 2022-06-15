#import "KWOptionsButton.h"
#import "KWCommonMethods.h"

@implementation KWOptionsButton

- (void)awakeFromNib
{
    [super awakeFromNib];

    // Setup the button
    [self setBezelStyle:10];
}

- (void)layout
{
    [super layout];
    
    [self setImage:[NSImage imageNamed:isAppearanceIsDark([self effectiveAppearance]) ? @"Gear with arrow (dark)" : @"Gear with arrow"]];
}

@end

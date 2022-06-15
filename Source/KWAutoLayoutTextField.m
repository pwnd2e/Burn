//
//  KWAutoLayoutTextField.m
//  Burn
//
//  Created by Maarten Foukhar on 07/07/2019.
//

#import "KWAutoLayoutTextField.h"

@interface KWAutoLayoutTextField()

@property (nonatomic, getter = didResize) BOOL resize;

@end

@implementation KWAutoLayoutTextField

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    if (@available(macOS 10.11, *))
    {
        [self setPreferredMaxLayoutWidth:0.0];
    }
}

- (void)layout
{
    [super layout];
    
    if (@available(macOS 10.11, *))
    {
    
    }
    else
    {
        if (![self didResize])
        {
            [self setResize:YES];
            [self sizeToFit];
            [self setPreferredMaxLayoutWidth:[self frame].size.width];
        }
    }
}

- (void)setStringValue:(NSString *)stringValue
{
    [super setStringValue:stringValue];
    
    if (@available(macOS 10.11, *))
    {
    
    }
    else
    {
        [self sizeToFit];
        [self setPreferredMaxLayoutWidth:[self frame].size.width];
    }
}

@end

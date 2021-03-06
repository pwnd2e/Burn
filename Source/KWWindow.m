#import "KWWindow.h"
#import "KWTabViewItem.h"

@implementation KWWindow

- (BOOL)respondsToSelector:(SEL)aSelector
{
    NSString *selectorString = NSStringFromSelector(aSelector);
    
    if ([self attachedSheet] && [selectorString rangeOfString:@"accessibility"].length == 0)
	    return NO;

    KWTabViewItem *tabViewItem = (KWTabViewItem *)[mainTabView selectedTabViewItem];
    id controller = [tabViewItem myController];
    
    if ([controller respondsToSelector:aSelector])
	    return YES;
	    
    return [super respondsToSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    KWTabViewItem *tabViewItem = (KWTabViewItem *)[mainTabView selectedTabViewItem];
    id controller = [tabViewItem myController];
    
    if ([controller respondsToSelector:selector])
	    return [controller methodSignatureForSelector:selector];
	    
    return [super methodSignatureForSelector: selector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    KWTabViewItem *tabViewItem = (KWTabViewItem *)[mainTabView selectedTabViewItem];
    id controller = [tabViewItem myController];
    SEL aSelector = [anInvocation selector];
    
    // TODO: just write things out, since it's safer for ARC and us :) (or find another to handle the respond chain or [NSApp sendAction:aSelector to:controller from:self];
    [controller performSelector:aSelector withObject:self];
}

@end

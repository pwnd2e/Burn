#import "KWProgressManager.h"
#import "KWCommonMethods.h"

@interface KWProgressManager()

@property (nonatomic, weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, weak) IBOutlet NSImageView *progressImageView;
@property (nonatomic, weak) IBOutlet NSTextField *statusTextField;
@property (nonatomic, weak) IBOutlet NSTextField *taskTextField;
@property (nonatomic, weak) IBOutlet NSButton *cancelButton;

@property(copy)void(^completion)(BOOL didCancel);

@property (nonatomic, strong) NSWindow *parentWindow;

@end

@implementation KWProgressManager

#pragma mark - Initial Methods

+ (KWProgressManager *)sharedManager
{
    static KWProgressManager *sharedManager = nil;
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^
    {
        sharedManager = [[KWProgressManager alloc] init];
    });
    
    return sharedManager;
}

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        [[NSBundle mainBundle] loadNibNamed:@"KWProgress" owner:self topLevelObjects:nil];
    }

    return self;
}

- (void)dealloc
{
    [[self progressIndicator] stopAnimation:self];
}

#pragma mark - Main Methods

- (void)beginSheetForWindow:(NSWindow *)window completionHandler:(void (^)(NSModalResponse returnCode))handler
{
    [self setParentWindow:window];

    [window beginSheet:[self window] completionHandler:^(NSModalResponse returnCode)
    {
        if (handler != nil)
        {
            handler(returnCode);
        }
        
        if (returnCode == NSModalResponseCancel && [self cancelHandler])
        {
            [self cancelHandler]();
        }
    }];
}

- (void)beginSheetForWindow:(nonnull NSWindow *)window
{
    [self beginSheetForWindow:window completionHandler:nil];
}

- (void)endSheet
{
    [self endSheetWithCompletion:nil];
}

- (void)endSheetWithCompletion:(void (^)(void))completion
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^
    {
        [NSApp setApplicationIconImage:[[NSImage imageNamed:@"Burn"] copy]];
        
        NSWindow *window = [self window];
        [[window sheetParent] endSheet:window];
        [window orderOut:nil];

        if (completion != nil)
        {
            completion();
        }
    }];
}

#pragma mark - Interface Methods

- (IBAction)cancelProgress:(id)sender
{
    [NSApp endSheet:[self window] returnCode:NSModalResponseCancel];
    [[self window] orderOut:nil];
}

#pragma mark - Property Methods

- (void)setTask:(NSString *)task
{
    _task = [task copy];

    [[self taskTextField] performSelectorOnMainThread:@selector(setStringValue:) withObject:_task waitUntilDone:YES];
}

- (void)setStatus:(NSString *)status
{
    _status = [status copy];

    [[self statusTextField] performSelectorOnMainThread:@selector(setStringValue:) withObject:_status waitUntilDone:YES];
}

- (void)setMaximumValue:(CGFloat)maximumValue
{
    _maximumValue = maximumValue;

    [[NSOperationQueue mainQueue] addOperationWithBlock:^
    {
        NSProgressIndicator *progressIndicator = [self progressIndicator];
    
        if (maximumValue > 0)
        {
            [progressIndicator setIndeterminate:NO];
            [progressIndicator setDoubleValue:0.0];
            [progressIndicator setMaxValue:self->_maximumValue];
        }
        else
        {
            [progressIndicator setIndeterminate:YES];
            [progressIndicator startAnimation:nil];
            
            NSImage *applicationImage = [[NSImage imageNamed:@"Burn"] copy];

            [applicationImage lockFocus];
            [[NSImage imageNamed:@"-1"] drawInRect:NSMakeRect(9.0, 10.0, 111.0, 16.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
            [applicationImage unlockFocus];
            
            [NSApp setApplicationIconImage:applicationImage];
        }
    }];
}

- (void)setValue:(CGFloat)value
{
    _value = value;

    [[NSOperationQueue mainQueue] addOperationWithBlock:^
    {
        NSProgressIndicator *progressIndicator = [self progressIndicator];
        NSImage *miniProgressIndicator;

        NSRect progressRect = NSMakeRect(9.0, 10.0, 111.0, 16.0);

        if (self->_value == -1)
        {
            [progressIndicator setIndeterminate:YES];
            [progressIndicator startAnimation:nil];
            
            miniProgressIndicator = [NSImage imageNamed:@"-1"];
            
            NSImage *applicationImage = [[NSImage imageNamed:@"Burn"] copy];
            
            [applicationImage lockFocus];
            [miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
            [applicationImage unlockFocus];
        
            [NSApp setApplicationIconImage:applicationImage];
        }
        else
        {
            [progressIndicator setIndeterminate:NO];
        }

        if (self->_value > [progressIndicator doubleValue])
        {
            [progressIndicator setDoubleValue:self->_value];
            
            double percent = self->_value / [progressIndicator maxValue] * 100;
        
            if (percent > 0 && percent < 10)
            {
                miniProgressIndicator = [NSImage imageNamed:@"0"];
                
                NSImage *applicationImage = [[NSImage imageNamed:@"Burn"] copy];
                
                [applicationImage lockFocus];
                [miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
                [applicationImage unlockFocus];

                [NSApp setApplicationIconImage:applicationImage];
            }
            else if (percent > 10 && percent < 20)
            {
                miniProgressIndicator = [NSImage imageNamed:@"10"];
                
                NSImage *applicationImage = [[NSImage imageNamed:@"Burn"] copy];
                
                [applicationImage lockFocus];
                [miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
                [applicationImage unlockFocus];
            
                [NSApp setApplicationIconImage:applicationImage];
            }
            else if (percent > 20 && percent < 30)
            {
                miniProgressIndicator = [NSImage imageNamed:@"20"];
                
                NSImage *applicationImage = [[NSImage imageNamed:@"Burn"] copy];
                
                [applicationImage lockFocus];
                [miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
                [applicationImage unlockFocus];
            
                [NSApp setApplicationIconImage:applicationImage];
            }
            else if (percent > 30 && percent < 40)
            {
                miniProgressIndicator = [NSImage imageNamed:@"30"];
                
                NSImage *applicationImage = [[NSImage imageNamed:@"Burn"] copy];
                
                [applicationImage lockFocus];
                [miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
                [applicationImage unlockFocus];
            
                [NSApp setApplicationIconImage:applicationImage];
            }
            else if (percent > 40 && percent < 50)
            {
                miniProgressIndicator = [NSImage imageNamed:@"40"];
                
                NSImage *applicationImage = [[NSImage imageNamed:@"Burn"] copy];
                
                [applicationImage lockFocus];
                [miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
                [applicationImage unlockFocus];
            
                [NSApp setApplicationIconImage:applicationImage];
            }
            else if (percent > 50 && percent < 60)
            {
                miniProgressIndicator = [NSImage imageNamed:@"50"];
                
                NSImage *applicationImage = [[NSImage imageNamed:@"Burn"] copy];
                
                [applicationImage lockFocus];
                [miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
                [applicationImage unlockFocus];
            
                [NSApp setApplicationIconImage:applicationImage];
            }
            else if (percent > 60 && percent < 70)
            {
                miniProgressIndicator = [NSImage imageNamed:@"60"];
                
                NSImage *applicationImage = [[NSImage imageNamed:@"Burn"] copy];
                
                [applicationImage lockFocus];
                [miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
                [applicationImage unlockFocus];
            
                [NSApp setApplicationIconImage:applicationImage];
            }
            else if (percent > 70 && percent < 80)
            {
                miniProgressIndicator = [NSImage imageNamed:@"70"];
                
                NSImage *applicationImage = [[NSImage imageNamed:@"Burn"] copy];
                
                [applicationImage lockFocus];
                [miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
                [applicationImage unlockFocus];
            
                [NSApp setApplicationIconImage:applicationImage];
            }
            else if (percent > 80 && percent < 90)
            {
                miniProgressIndicator = [NSImage imageNamed:@"80"];
                
                NSImage *applicationImage = [[NSImage imageNamed:@"Burn"] copy];
                
                [applicationImage lockFocus];
                [miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
                [applicationImage unlockFocus];
            
                [NSApp setApplicationIconImage:applicationImage];
            }
            else if (percent > 90 && percent < 99)
            {
                miniProgressIndicator = [NSImage imageNamed:@"90"];
                
                NSImage *applicationImage = [[NSImage imageNamed:@"Burn"] copy];
                
                [applicationImage lockFocus];
                [miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
                [applicationImage unlockFocus];

                [NSApp setApplicationIconImage:applicationImage];
            }
            else if (percent == 99 && percent > 99)
            {
                miniProgressIndicator = [NSImage imageNamed:@"100"];
                
                NSImage *applicationImage = [[NSImage imageNamed:@"Burn"] copy];
                
                [applicationImage lockFocus];
                [miniProgressIndicator drawInRect:progressRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
                [applicationImage unlockFocus];
            
                [NSApp setApplicationIconImage:applicationImage];
            }
        }
    }];
}

- (void)setIconImage:(NSImage *)iconImage
{
    _iconImage = [iconImage copy];
    [[self progressImageView] performSelectorOnMainThread:@selector(setImage:) withObject:_iconImage waitUntilDone:YES];
}

- (void)setAllowCanceling:(BOOL)allowCanceling
{
    _allowCanceling = allowCanceling;
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^
    {
        // TODO: use auto layout if possible
        NSWindow *window = [self window];
        NSRect frame = [window frame];
    
        if (self->_allowCanceling == NO)
        {
            NSRect newFrame = NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width, 124.0);
            [window setFrame:newFrame display:YES];
            [[self cancelButton] setHidden:YES];
        }
        else
        {
            NSRect newFrame = NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width, 163.0);
            [window setFrame:newFrame display:YES];
            [[self cancelButton] setHidden:NO];
        }
    }];
}

// TODO: think of a way to make this method more understandable, even I after seven years got completely confused :P
- (void)setStatusByAddingPercent:(NSString *)percent
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^
    {
        NSTextField *statusTextField = [self statusTextField];

        NSString *currentText = [statusTextField stringValue];
        NSString *newStatusText;

        if ([currentText length] > 60)
        {
            newStatusText = [[currentText substringToIndex:48] stringByAppendingString:@"..."];
        }
        else
        {
            newStatusText = currentText;
        }
        
        [statusTextField setStringValue:[[[newStatusText componentsSeparatedByString:@" ("] objectAtIndex:0] stringByAppendingString:percent]];
    }];
}

@end

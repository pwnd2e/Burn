//
//  KWDebugger.m
//  Burn
//
//  Created by Maarten Foukhar on 29/12/2019.
//

#import "KWDebugger.h"
#import "KWConstants.h"

@interface KWDebugger ()

@property (nonatomic, strong) NSMutableString *currentLogString;

@end

void KWLog(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    
    NSString *string = [[NSString alloc] initWithFormat:format arguments:args];
    [[[KWDebugger sharedDebugger] currentLogString] appendString:string];
    
    va_end(args);
    
    va_start(args, format);
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:KWDebug])
    {
        NSLogv(format, args);
    }
    
    va_end(args);
}

@implementation KWDebugger

+ (instancetype)sharedDebugger
{
    static KWDebugger *sharedDebugger = nil;
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^
    {
        sharedDebugger = [[KWDebugger alloc] init];
    });
    
    return sharedDebugger;
}

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        _currentLogString = [[NSMutableString alloc] init];
    }
    
    return self;
}

- (NSString *)logString
{
    return [[self currentLogString] copy];
}

- (void)clearLog
{
    [[self currentLogString] setString:@""];
}

@end

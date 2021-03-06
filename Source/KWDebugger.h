//
//  KWDebugger.h
//  Burn
//
//  Created by Maarten Foukhar on 29/12/2019.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT void KWLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2) NS_NO_TAIL_CALL;

@interface KWDebugger : NSObject

+ (instancetype)sharedDebugger;

/**
    Get the current log string (since the application opened
    @return A log string (generated by KWLog calls)
 */
- (NSString *)logString;

/**
    Clear the log
 */
- (void)clearLog;

@end

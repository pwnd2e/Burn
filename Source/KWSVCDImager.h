//
//  KWSVCDImager.h
//  KWSVCDImager
//
//  Created by Maarten Foukhar on 14-3-07.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KWCommonMethods.h"

@interface KWSVCDImager : NSObject 
{
    BOOL userCanceled;
    NSTask *vcdimager;
    NSTimer *timer;
    float totalSize;
}

- (NSInteger)createSVCDImage:(NSString *)path withFiles:(NSArray *)files withLabel:(NSString *)label createVCD:(BOOL)VCD hideExtension:(BOOL)hide errorString:(NSString **)error;
- (void)stopVcdimager;

@end

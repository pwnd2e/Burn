//
//  KWAudioTrackCalculator.h
//  Burn
//
//  Created by Maarten Foukhar on 16/08/2019.
//

#import <Foundation/Foundation.h>

@interface KWAudioTrackCalculator : NSObject

- (void)getAudioTrackSizeForPath:(NSString *)path completion:(void (^)(NSInteger trackSize))completion;
- (DRDevice *)device;

@end

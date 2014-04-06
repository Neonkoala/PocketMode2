//
//  PocketMode.h
//  
//
//  Created by Nick Dawson on 06/04/2014.
//
//

#import <Foundation/Foundation.h>

@interface PocketMode : NSObject

+ (id)sharedManager;

- (void)updateLux:(NSInteger)lux;

- (void)incomingPhoneCall:(id)call;
- (void)stopRinging;

@end

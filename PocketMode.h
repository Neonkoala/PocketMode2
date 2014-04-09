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

- (void)updatePreferences;

- (void)updateLux:(NSInteger)lux;

- (void)incomingFaceTimeCall:(id)chat;
- (void)incomingPhoneCall:(id)call;

- (void)stopAlertTone;
- (void)stopRinging;

@end

//
//  PocketMode.h
//  
//
//  Created by Nick Dawson on 06/04/2014.
//
//

#import <Foundation/Foundation.h>

@class BBBulletin;

@interface PocketMode : NSObject

+ (id)sharedManager;

- (void)updatePreferences;

- (void)updateLux:(NSInteger)lux;

- (void)incomingBulletin:(BBBulletin *)bulletin;
- (void)incomingFaceTimeCall:(id)chat;
- (void)incomingPhoneCall:(id)call;

- (void)stopAlertTone;
- (void)stopRinging;

@end

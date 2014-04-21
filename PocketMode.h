//
//  PocketMode.h
//  
//
//  Created by Nick Dawson on 06/04/2014.
//
//

#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

#import <Foundation/Foundation.h>

@class BBBulletin;

@interface PocketMode : NSObject

+ (id)sharedManager;

- (void)updatePreferences;

- (void)updateLux:(NSInteger)lux;

- (void)incomingBulletin:(BBBulletin *)bulletin;
- (void)incomingMail;
- (void)incomingFaceTimeCall:(id)chat;
- (void)incomingPhoneCall:(id)call;

- (void)stopAlertTone;
- (void)stopRinging;

@end

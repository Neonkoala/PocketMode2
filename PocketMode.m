//
//  PocketMode.m
//  
//
//  Created by Nick Dawson on 06/04/2014.
//
//

#import "PocketMode.h"

#import <BulletinBoard/BBBulletin.h>
#import <Celestial/Celestial.h>
#import <IOKit/hid/IOHIDEventSystemClient.h>
#import <UIKit/UIApplication2.h>

#import <objc/runtime.h>
#import <notify.h>

#pragma mark - C/C++ and Callbacks

#if defined __cplusplus
extern "C" {
#endif
    
    IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
    int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
    CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef, int);
    typedef struct __IOHIDServiceClient * IOHIDServiceClientRef;
    int IOHIDServiceClientSetProperty(IOHIDServiceClientRef, CFStringRef, CFNumberRef);
    
#if defined __cplusplus
};
#endif

static IOHIDEventSystemClientRef s_hidSysC; // event system client

void handleALSEvent(void* target, void* refcon, IOHIDEventQueueRef queue, IOHIDEventRef event) {
    if(IOHIDEventGetType(event) == kIOHIDEventTypeAmbientLightSensor) {
        NSInteger lux = IOHIDEventGetIntegerValue(event, (IOHIDEventField)kIOHIDEventFieldAmbientLightSensorLevel);
		
		DLog(@"PocketMode: lux now %ld", (long)lux);
        
        @autoreleasepool {
            [[PocketMode sharedManager] updateLux:lux];
        }
    }
}

void incomingMailNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    DLog(@"PocketMode: Incoming mail notification callback...");
    [[PocketMode sharedManager] incomingMail];
}

void preferenceNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    DLog(@"PocketMode: Preferences changed notification callback...");
    [[PocketMode sharedManager] updatePreferences];
}

#pragma mark - Class

typedef NS_ENUM(NSInteger, PMHandleType) {
    PMHandleTypeNone = 0,
    PMHandleTypeCall,
    PMHandleTypeMail,
    PMHandleTypeMessage,
    PMHandleTypeNotification
};

NSString * const PMMobileMailIdentifier = @"com.apple.mobilemail";
NSString * const PMSMSIdentifier = @"com.apple.MobileSMS";

NSString * const PMPreferencesPath = @"/var/mobile/Library/Preferences/be.dawson.pocketmodeprefs.plist";

NSString * const PMUserInfoIncrementsRemainingKey = @"IncrementsRemainingKey";
NSString * const PMUserInfoMaxVolumeKey = @"MaxVolumeKey";

NSString * const PMPreferenceGlobalEnabled = @"GlobalEnabled";

NSString * const PMPreferencePhoneCallEnabled = @"PhoneCallEnabled";
NSString * const PMPreferencePhoneCallGradualVolume = @"PhoneCallGradual";
NSString * const PMPreferencePhoneCallOverrideMute = @"PhoneCallOverrideMute";
NSString * const PMPreferencePhoneCallVolume = @"PhoneCallVolume";
NSString * const PMPreferencePhoneCallFacetimeEnabled = @"PhoneCallFacetimeEnabled";

NSString * const PMPreferenceMessagesEnabled = @"MessagesEnabled";
NSString * const PMPreferenceMessagesOverrideMute = @"MessagesOverrideMute";
NSString * const PMPreferenceMessagesVolume = @"MessagesVolume";

NSString * const PMPreferenceNotificationsEnabled = @"NotificationsEnabled";
NSString * const PMPreferenceNotificationsOverrideMute = @"NotificationsOverrideMute";
NSString * const PMPreferenceNotificationsVolume = @"NotificationsVolume";
NSString * const PMPreferenceNotificationsAppPrefix = @"NotificationsApp-";

NSString * const PMPreferenceLuxLevel = @"LuxLevel";

@interface PocketMode()

// State

@property (nonatomic, assign) BOOL alsConfigured;
@property (nonatomic, assign) BOOL globalEnabled;
@property (nonatomic, assign) BOOL overrideInProgress;
@property (nonatomic, assign) BOOL wasMuted;
@property (nonatomic, assign) float regularVolume;
@property (nonatomic, assign) NSInteger lux;
@property (nonatomic, assign) PMHandleType waitingHandleType;
@property (nonatomic, strong) NSDate *lastReadingDate;
@property (nonatomic, strong) NSTimer *gradualVolumeTimer;
@property (nonatomic, strong) NSTimer *soundMonitorTimer;

// Settings - General

@property (nonatomic, assign) NSInteger luxThreshold;

// Settings - Phone Calls

@property (nonatomic, assign) BOOL phoneCallEnabled;
@property (nonatomic, assign) BOOL phoneCallFacetimeEnabled;
@property (nonatomic, assign) BOOL phoneCallGradualVolume;
@property (nonatomic, assign) BOOL phoneCallOverrideMute;
@property (nonatomic, assign) float phoneCallMaxVolume;

// Settings - Messages

@property (nonatomic, assign) BOOL messagesEnabled;
@property (nonatomic, assign) BOOL messagesOverrideMute;
@property (nonatomic, assign) float messagesVolume;

// Settings - Push Notifications

@property (nonatomic, assign) BOOL notificationsEnabled;
@property (nonatomic, assign) BOOL notificationsMailEnabled;
@property (nonatomic, assign) BOOL notificationsOverrideMute;
@property (nonatomic, assign) float notificationsVolume;
@property (nonatomic, strong) NSArray *notificationsAppIdentifiers;

@end

@implementation PocketMode

+ (id)sharedManager {
    static PocketMode *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (id)init {
    self = [super init];
    if(self) {
        _alsConfigured = NO;
        _overrideInProgress = NO;
        _wasMuted = NO;
        _waitingHandleType = PMHandleTypeNone;
        
        [self loadPreferences];
    }
    return self;
}

#pragma mark - Preferences

- (void)loadPreferences {
    // Set defaults
    self.globalEnabled = YES;
    
    self.luxThreshold = 10;
    
    self.phoneCallEnabled = YES;
    self.phoneCallFacetimeEnabled = YES;
    self.phoneCallGradualVolume = YES;
    self.phoneCallOverrideMute = NO;
    self.phoneCallMaxVolume = 1.0;
    
    self.messagesEnabled = YES;
    self.messagesOverrideMute = NO;
    self.messagesVolume = 1.0;
    
    self.notificationsEnabled = NO;
    self.notificationsMailEnabled = NO;
    self.notificationsOverrideMute = NO;
    self.notificationsVolume = 1.0;
    
    float currentVolume;
    [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
    self.regularVolume = currentVolume;
    
    [self updatePreferences];
    
    // Start listening for future changes
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    if(center) {
        CFNotificationCenterAddObserver(center, NULL, preferenceNotificationCallback, CFSTR("be.dawson.pocketmode.prefsChanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(center, NULL, incomingMailNotificationCallback, CFSTR("be.dawson.pocketmode.incomingMail"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}

- (void)updatePreferences {
    // Load defaults from PList
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:PMPreferencesPath];
    
    DLog(@"PocketMode: Preferences changed: %@", preferences);
    
    if([preferences objectForKey:PMPreferenceGlobalEnabled]) {
        self.globalEnabled = [[preferences objectForKey:PMPreferenceGlobalEnabled] boolValue];
    }
    
    // Phone
    if([preferences objectForKey:PMPreferencePhoneCallEnabled]) {
        self.phoneCallEnabled = [[preferences objectForKey:PMPreferencePhoneCallEnabled] boolValue];
    }
    if([preferences objectForKey:PMPreferencePhoneCallGradualVolume]) {
        self.phoneCallGradualVolume = [[preferences objectForKey:PMPreferencePhoneCallGradualVolume] boolValue];
    }
    if([preferences objectForKey:PMPreferencePhoneCallOverrideMute]) {
        self.phoneCallOverrideMute = [[preferences objectForKey:PMPreferencePhoneCallOverrideMute] boolValue];
    }
    if([preferences objectForKey:PMPreferencePhoneCallVolume]) {
        self.phoneCallMaxVolume = [[preferences objectForKey:PMPreferencePhoneCallVolume] floatValue];
    }
    if([preferences objectForKey:PMPreferencePhoneCallFacetimeEnabled]) {
        self.phoneCallFacetimeEnabled = [[preferences objectForKey:PMPreferencePhoneCallFacetimeEnabled] boolValue];
    }
    
    // Messages
    if([preferences objectForKey:PMPreferenceMessagesEnabled]) {
        self.messagesEnabled = [[preferences objectForKey:PMPreferenceMessagesEnabled] boolValue];
    }
    if([preferences objectForKey:PMPreferenceMessagesOverrideMute]) {
        self.messagesOverrideMute = [[preferences objectForKey:PMPreferenceMessagesOverrideMute] boolValue];
    }
    if([preferences objectForKey:PMPreferenceMessagesVolume]) {
        self.messagesVolume = [[preferences objectForKey:PMPreferenceMessagesVolume] floatValue];
    }
    
    // Notifications
    if([preferences objectForKey:PMPreferenceNotificationsEnabled]) {
        self.notificationsEnabled = [[preferences objectForKey:PMPreferenceNotificationsEnabled] boolValue];
    }
    if([preferences objectForKey:PMPreferenceNotificationsOverrideMute]) {
        self.notificationsOverrideMute = [[preferences objectForKey:PMPreferenceNotificationsOverrideMute] boolValue];
    }
    if([preferences objectForKey:PMPreferenceNotificationsVolume]) {
        self.notificationsVolume = [[preferences objectForKey:PMPreferenceNotificationsVolume] floatValue];
    }
    
    NSString *mobileMailPreference = [PMPreferenceNotificationsAppPrefix stringByAppendingString:PMMobileMailIdentifier];
    if([preferences objectForKey:mobileMailPreference]) {
        self.notificationsMailEnabled = [[preferences objectForKey:mobileMailPreference] boolValue];
    }
    
    // Advanced
    if([preferences objectForKey:PMPreferenceLuxLevel]) {
        self.luxThreshold = [[preferences objectForKey:PMPreferenceLuxLevel] integerValue];
    }

    // Per app notifications
    NSMutableArray *enabledApps = [NSMutableArray array];
    
    [preferences enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if([key hasPrefix:PMPreferenceNotificationsAppPrefix]) {
            if([obj boolValue]) {
                [enabledApps addObject:[key substringFromIndex:[PMPreferenceNotificationsAppPrefix length]]];
            }
        }
    }];
    
    self.notificationsAppIdentifiers = enabledApps;
}

#pragma mark - ALS

- (void)configureALS {
    self.alsConfigured = YES;
    
    int pv1 = 0xff00;
    int pv2 = 4;
    CFNumberRef mVals[2];
    CFStringRef mKeys[2];
    
    mVals[0] = CFNumberCreate(CFAllocatorGetDefault(), kCFNumberSInt32Type, &pv1);
    mVals[1] = CFNumberCreate(CFAllocatorGetDefault(), kCFNumberSInt32Type, &pv2);
    mKeys[0] = CFStringCreateWithCString(0, "PrimaryUsagePage", 0);
    mKeys[1] = CFStringCreateWithCString(0, "PrimaryUsage", 0);
    
    CFDictionaryRef matchInfo = CFDictionaryCreate(CFAllocatorGetDefault(),(const void**)mKeys,(const void**)mVals, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    s_hidSysC = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    IOHIDEventSystemClientSetMatching(s_hidSysC,matchInfo);
    
    CFArrayRef matchingsrvs = IOHIDEventSystemClientCopyServices(s_hidSysC, 0);
    
    if(CFArrayGetCount(matchingsrvs) == 0) {
        self.alsConfigured = NO;
        
        NSLog(@"PocketMode: Failed to configure ALS");
        
        self.waitingHandleType = PMHandleTypeNone; // Reset
    } else {
        // Configure the service
        IOHIDServiceClientRef alssc = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(matchingsrvs, 0);
        
        int desiredInterval = 50000;
        CFNumberRef interval = CFNumberCreate(CFAllocatorGetDefault(), kCFNumberIntType, &desiredInterval);
        IOHIDServiceClientSetProperty(alssc,CFSTR("ReportInterval"),interval);
        
        // Set ALS callback
        IOHIDEventSystemClientScheduleWithRunLoop(s_hidSysC, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        IOHIDEventSystemClientRegisterEventCallback(s_hidSysC, handleALSEvent, NULL, NULL);
        
        DLog(@"PocketMode: Successfully configured ALS");
        
        CFRelease(interval);
    }
    
    CFRelease(matchingsrvs);
    CFRelease(matchInfo);
    CFRelease(mVals[0]);
    CFRelease(mVals[1]);
    CFRelease(mKeys[0]);
    CFRelease(mKeys[1]);
    
    DLog(@"PocketMode: Entering run loop...");
    
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.5, NO); // 0.5 seconds failover if ALS fails
    
    DLog(@"PocketMode: Run loop finished");
}

- (void)restoreALS {
    DLog(@"PocketMode: Restoring ALS config...");
    
    CFArrayRef matchingsrvs = IOHIDEventSystemClientCopyServices(s_hidSysC, 0);
    
    if(CFArrayGetCount(matchingsrvs) > 0) {
        // Configure the service
        IOHIDServiceClientRef alssc = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(matchingsrvs, 0);
    
        int desiredInterval = 0;
        CFNumberRef interval = CFNumberCreate(CFAllocatorGetDefault(), kCFNumberIntType, &desiredInterval);
        IOHIDServiceClientSetProperty(alssc,CFSTR("ReportInterval"),interval);
        CFRelease(interval);
    }
    
    IOHIDEventSystemClientUnscheduleWithRunLoop(s_hidSysC, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOHIDEventSystemClientUnregisterEventCallback(s_hidSysC);
    
    self.alsConfigured = NO;
    
    DLog(@"PocketMode: ALS restored!");
}

- (void)updateLux:(NSInteger)updatedLux {
    self.lux = updatedLux;
    self.lastReadingDate = [NSDate date];
    
    switch (self.waitingHandleType) {
        case PMHandleTypeCall:
            self.waitingHandleType = PMHandleTypeNone;
            [self handleCall];
            break;
            
        case PMHandleTypeMail:
            self.waitingHandleType = PMHandleTypeNone;
            [self handleMail];
            break;
            
        case PMHandleTypeMessage:
            self.waitingHandleType = PMHandleTypeNone;
            [self handleMessage];
            break;
            
        case PMHandleTypeNotification:
            self.waitingHandleType = PMHandleTypeNone;
            [self handleNotification];
            break;
            
        default:
            break;
    }
    
    CFRunLoopStop(CFRunLoopGetCurrent());
    
    if(self.overrideInProgress) {
        if(self.lux > self.luxThreshold) {
            [self.gradualVolumeTimer invalidate];
            [self restoreRingerState];
            [self restoreALS];
        }
    }
}

- (void)restoreRingerState {
    DLog(@"PocketMode: Restoring ringer state to %f", self.regularVolume);
    
    [self setRingerVolume:self.regularVolume];
    
    if(self.wasMuted) {
        DLog(@"PocketMode: Muting device");
        
        uint64_t state;
        int token;
        notify_register_check("com.apple.springboard.ringerstate", &token);
        notify_get_state(token, &state);
        
        if(state != 0) {
            notify_set_state(token, 0);
            notify_cancel(token);
            notify_post("com.apple.springboard.ringerstate");
        } else {
            notify_cancel(token);
        }
    }
    
    self.overrideInProgress = NO;
    
    // Hack to hide HUD
    [self performSelector:@selector(reenableRingerHUD) withObject:nil afterDelay:0.1];
}

#pragma mark - Ringer

- (void)reenableRingerHUD {
    if(!self.overrideInProgress) {
        [[UIApplication sharedApplication] setSystemVolumeHUDEnabled:YES forAudioCategory:@"Ringtone"];
    }
}

- (void)setRingerVolume:(float)volume {
    DLog(@"PocketMode: Setting ringer volume to %f", volume);
    [[AVSystemController sharedAVSystemController] setVolumeTo:volume forCategory:@"Ringtone"];
}

- (void)setRingerVolumeGradually:(float)volume {
    NSInteger increments = (self.phoneCallMaxVolume - self.regularVolume) / 0.1;
    
    DLog(@"PocketMode: Increasing volume in %ld increments", (long)increments);
    
    self.gradualVolumeTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(incrementVolume:) userInfo:@{PMUserInfoMaxVolumeKey: @(volume), PMUserInfoIncrementsRemainingKey: @(increments)} repeats:NO];
}

- (void)stopAlertTone {
    if(self.overrideInProgress) {
        DLog(@"PocketMode: Stop alert tone");
        [self restoreRingerState];
        [self restoreALS];
    }
}

- (void)stopRinging {
    if(self.overrideInProgress) {
        DLog(@"PocketMode: Stop ringing");
        [self.gradualVolumeTimer invalidate];
        [self restoreRingerState];
        [self restoreALS];
    }
}

#pragma mark - Timers

- (void)incrementVolume:(NSTimer *)timer {
    [[UIApplication sharedApplication] setSystemVolumeHUDEnabled:NO forAudioCategory:@"Ringtone"];
    
    float maxVolume = [timer.userInfo[PMUserInfoMaxVolumeKey] floatValue];
    float remainingIncrements = [timer.userInfo[PMUserInfoIncrementsRemainingKey] floatValue] - 1;
    
    float currentVolume;
    [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
    
    float targetVolume = currentVolume + 0.1;
    if(targetVolume > maxVolume) {
        targetVolume = maxVolume;
        remainingIncrements = 0;
    }
    
    DLog(@"PocketMode: Incrementing volume to %f", targetVolume);
    
    [self setRingerVolume:targetVolume];
    
    if(remainingIncrements) {
        DLog(@"PocketMode: Resetting incremental timer");
        self.gradualVolumeTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(incrementVolume:) userInfo:@{PMUserInfoMaxVolumeKey: @(maxVolume), PMUserInfoIncrementsRemainingKey: @(remainingIncrements)} repeats:NO];
    } else {
        DLog(@"PocketMode: Achieved maximum increments");
        self.gradualVolumeTimer = nil;
    }
}

- (void)checkSound:(NSTimer *)timer {
    DLog(@"PocketMode: Returning to normal after sound increase for alert...");
    
    [self stopAlertTone];
}

#pragma mark - Logic

- (void)handleCall {
    DLog(@"PocketMode: Handling call...");
    
    [[UIApplication sharedApplication] setSystemVolumeHUDEnabled:NO forAudioCategory:@"Ringtone"];
    
    if(self.lux <= self.luxThreshold) {
        DLog(@"PocketMode: It's dark and lonely in here...");
        
        self.overrideInProgress = YES;
        
        int token;
        uint64_t state;
        notify_register_check("com.apple.springboard.ringerstate", &token);
        notify_get_state(token, &state);
        
        if(state == 0) {
            self.wasMuted = YES;
        } else {
            self.wasMuted = NO;
        }
        
        if(self.phoneCallOverrideMute && self.wasMuted) {
            notify_set_state(token, 1);
        }
        
        notify_cancel(token);
        notify_post("com.apple.springboard.ringerstate");
        
        if(self.phoneCallMaxVolume > self.regularVolume) {
            if(self.phoneCallGradualVolume) {
                [self setRingerVolumeGradually:self.phoneCallMaxVolume];
            } else {
                [self setRingerVolume:self.phoneCallMaxVolume];
            }
        }
    }
}

- (void)handleMail {
    DLog(@"PocketMode: Handling new mail...");
    
    [[UIApplication sharedApplication] setSystemVolumeHUDEnabled:NO forAudioCategory:@"Ringtone"];
    
    if(self.lux <= self.luxThreshold) {
        DLog(@"PocketMode: It's dark and lonely in here...");
        
        self.overrideInProgress = YES;
        
        int token;
        uint64_t state;
        notify_register_check("com.apple.springboard.ringerstate", &token);
        notify_get_state(token, &state);
        
        if(state == 0) {
            self.wasMuted = YES;
        } else {
            self.wasMuted = NO;
        }
        
        if(self.notificationsOverrideMute && self.wasMuted) {
            notify_set_state(token, 1);
        }
        
        notify_cancel(token);
        notify_post("com.apple.springboard.ringerstate");
        
        if(self.notificationsVolume > self.regularVolume) {
            [self setRingerVolume:self.notificationsVolume];
        }
        
        self.soundMonitorTimer = [NSTimer scheduledTimerWithTimeInterval:7.0 target:self selector:@selector(checkSound:) userInfo:nil repeats:NO];
    }
}

- (void)handleMessage {
    DLog(@"PocketMode: Handling message...");
    
    [[UIApplication sharedApplication] setSystemVolumeHUDEnabled:NO forAudioCategory:@"Ringtone"];
    
    if(self.lux <= self.luxThreshold) {
        DLog(@"PocketMode: It's dark and lonely in here...");
        
        self.overrideInProgress = YES;
        
        int token;
        uint64_t state;
        notify_register_check("com.apple.springboard.ringerstate", &token);
        notify_get_state(token, &state);
        
        if(state == 0) {
            self.wasMuted = YES;
        } else {
            self.wasMuted = NO;
        }
        
        if(self.messagesOverrideMute && self.wasMuted) {
            notify_set_state(token, 1);
        }
        
        notify_cancel(token);
        notify_post("com.apple.springboard.ringerstate");
        
        if(self.messagesVolume > self.regularVolume) {
            [self setRingerVolume:self.messagesVolume];
        }
        
        self.soundMonitorTimer = [NSTimer scheduledTimerWithTimeInterval:7.0 target:self selector:@selector(checkSound:) userInfo:nil repeats:NO];
    }
}

- (void)handleNotification {
    DLog(@"PocketMode: Handling notification...");
    
    [[UIApplication sharedApplication] setSystemVolumeHUDEnabled:NO forAudioCategory:@"Ringtone"];
    
    if(self.lux <= self.luxThreshold) {
        DLog(@"PocketMode: It's dark and lonely in here...");
        
        self.overrideInProgress = YES;
        
        int token;
        uint64_t state;
        notify_register_check("com.apple.springboard.ringerstate", &token);
        notify_get_state(token, &state);
        
        if(state == 0) {
            self.wasMuted = YES;
        } else {
            self.wasMuted = NO;
        }
        
        if(self.notificationsOverrideMute && self.wasMuted) {
            notify_set_state(token, 1);
        }
        
        notify_cancel(token);
        notify_post("com.apple.springboard.ringerstate");
        
        if(self.notificationsVolume > self.regularVolume) {
            [self setRingerVolume:self.notificationsVolume];
        }
        
        self.soundMonitorTimer = [NSTimer scheduledTimerWithTimeInterval:7.0 target:self selector:@selector(checkSound:) userInfo:nil repeats:NO];
    }
}

#pragma mark - Handle Events

- (void)incomingBulletin:(BBBulletin *)bulletin {
    DLog(@"PocketMode: Incoming bulletin sectionID: %@", bulletin.sectionID);
    
    if(self.overrideInProgress || !self.globalEnabled || (self.waitingHandleType != PMHandleTypeNone)) {
        return;
    }
    
    if([bulletin.sectionID isEqualToString:PMSMSIdentifier]) {
        if(self.messagesEnabled) {
            DLog(@"PocketMode: Incoming SMS triggered: %@", bulletin.sectionID);
            
            float currentVolume;
            [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
            self.regularVolume = currentVolume;
            
            self.waitingHandleType = PMHandleTypeMessage;
            [self configureALS];
        }
    } else if(![bulletin.sectionID isEqualToString:PMMobileMailIdentifier]) {
        for(NSString *appIdentifier in self.notificationsAppIdentifiers) {
            if([appIdentifier isEqualToString:bulletin.sectionID]) {
                float currentVolume;
                [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
                self.regularVolume = currentVolume;
                
                self.waitingHandleType = PMHandleTypeNotification;
                [self configureALS];
                break;
            }
        }
    }
}

- (void)incomingMail {
    if(!self.overrideInProgress && self.globalEnabled && self.notificationsEnabled && self.notificationsMailEnabled && (self.waitingHandleType == PMHandleTypeNone)) {
        DLog(@"PocketMode: Incoming mail...");
    } else {
        DLog(@"PocketMode: Ignoring incoming mail.");
        return;
    }
    
    float currentVolume;
    [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
    self.regularVolume = currentVolume;
    
    self.waitingHandleType = PMHandleTypeMail;
    [self configureALS];
}

- (void)incomingFaceTimeCall:(id)chat {
    if(!self.overrideInProgress && self.globalEnabled && self.phoneCallEnabled && self.phoneCallFacetimeEnabled && (self.waitingHandleType == PMHandleTypeNone)) {
        DLog(@"PocketMode: Incoming FaceTime call... Current date: %@ ALS staleness: %@ Lux: %ld", [NSDate date], self.lastReadingDate, (long)self.lux);
    } else {
        DLog(@"PocketMode: Incoming FaceTime call... Not overriding.");
        return;
    }
    
    float currentVolume;
    [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
    self.regularVolume = currentVolume;
    
    self.waitingHandleType = PMHandleTypeCall;
    [self configureALS];
}

- (void)incomingPhoneCall:(id)call {
    if(!self.overrideInProgress && self.globalEnabled && self.phoneCallEnabled && (self.waitingHandleType == PMHandleTypeNone)) {
        DLog(@"PocketMode: Incoming phone call... Current date: %@ ALS staleness: %@ Lux: %ld", [NSDate date], self.lastReadingDate, (long)self.lux);
    } else {
        DLog(@"PocketMode: Incoming phone call... Not overriding.");
        return;
    }
    
    float currentVolume;
    [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
    self.regularVolume = currentVolume;
    
    self.waitingHandleType = PMHandleTypeCall;
    [self configureALS];
}

@end

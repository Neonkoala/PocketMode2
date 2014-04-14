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
		
		//NSLog(@"PocketMode: lux now %ld", (long)lux);
        
        [[PocketMode sharedManager] updateLux:lux];
    }
}

void preferenceNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[PocketMode sharedManager] updatePreferences];
}

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
NSString * const PMPreferenceNotificationsMailEnabled = @"NotificationsMailEnabled";

NSString * const PMPreferenceLuxLevel = @"LuxLevel";

@interface PocketMode()

// State

@property (nonatomic, assign) BOOL alsConfigured;
@property (nonatomic, assign) BOOL globalEnabled;
@property (nonatomic, assign) BOOL overrideInProgress;
@property (nonatomic, assign) BOOL wasMuted;
@property (nonatomic, assign) float regularVolume;
@property (nonatomic, assign) NSInteger lux;
@property (nonatomic, strong) NSDate *lastReadingDate;
@property (nonatomic, strong) NSTimer *gradualVolumeTimer;
@property (nonatomic, strong) NSTimer *soundMonitorTimer;
@property (nonatomic, strong) BBSound *activeSound;

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
@property (nonatomic, assign) BOOL notificationsOverrideMute;
@property (nonatomic, assign) BOOL notificationsMailEnabled;
@property (nonatomic, assign) float notificationsVolume;

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
        
        [self loadPreferences];
        [self configureALS];
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
    self.notificationsOverrideMute = NO;
    self.notificationsMailEnabled = NO;
    self.notificationsVolume = 1.0;
    
    float currentVolume;
    [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
    self.regularVolume = currentVolume;
    
    [self updatePreferences];
    
    // Start listening for future changes
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    if(center) {
        CFNotificationCenterAddObserver(center, NULL, preferenceNotificationCallback, CFSTR("be.dawson.pocketmode.prefsChanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}

- (void)updatePreferences {
    NSLog(@"PocketMode: Preferences changed!");
    // Load defaults from PList
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:PMPreferencesPath];
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
    if([preferences objectForKey:PMPreferenceNotificationsMailEnabled]) {
        self.notificationsMailEnabled = [[preferences objectForKey:PMPreferenceNotificationsMailEnabled] boolValue];
    }
    if([preferences objectForKey:PMPreferenceNotificationsVolume]) {
        self.notificationsVolume = [[preferences objectForKey:PMPreferenceNotificationsVolume] floatValue];
    }
    
    // Advanced
    if([preferences objectForKey:PMPreferenceLuxLevel]) {
        self.luxThreshold = [[preferences objectForKey:PMPreferenceLuxLevel] integerValue];
    }
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
    
    CFArrayRef matchingsrvs = IOHIDEventSystemClientCopyServices(s_hidSysC,0);
    
    if (CFArrayGetCount(matchingsrvs) == 0)
    {
        self.alsConfigured = NO;
        return;
    }
    
    // ----- configure the service -----------------
    
    IOHIDServiceClientRef alssc = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(matchingsrvs, 0);
    
    int desiredInterval = 500000;//1000;
    CFNumberRef interval = CFNumberCreate(CFAllocatorGetDefault(), kCFNumberIntType, &desiredInterval);
    IOHIDServiceClientSetProperty(alssc,CFSTR("ReportInterval"),interval);
    
    // ----- set ALS callback -----------------
    
	// will be set later in reloadPrefs
    IOHIDEventSystemClientScheduleWithRunLoop(s_hidSysC, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOHIDEventSystemClientRegisterEventCallback(s_hidSysC, handleALSEvent, NULL, NULL);
}

- (void)restoreALS {
    IOHIDEventSystemClientUnscheduleWithRunLoop(s_hidSysC, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
}

- (void)updateLux:(NSInteger)updatedLux {
    self.lux = updatedLux;
    self.lastReadingDate = [NSDate date];
    
    if(self.overrideInProgress) {
        if(self.lux > self.luxThreshold) {
            [self restoreRingerState];
        }
    }
}

- (void)restoreRingerState {
    [self setRingerVolume:self.regularVolume];
    
    if(self.wasMuted) {
        int token;
        notify_register_check("com.apple.springboard.ringerstate", &token);
        notify_set_state(token, 0);
        notify_cancel(token);
        notify_post("com.apple.springboard.ringerstate");
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
    [[AVSystemController sharedAVSystemController] setVolumeTo:volume forCategory:@"Ringtone"];
}

- (void)setRingerVolumeGradually:(float)volume {
    NSInteger increments = (self.phoneCallMaxVolume - self.regularVolume) / 0.1;
    
    NSLog(@"PocketMode: increments start: %ld", (long)increments);
    
    self.gradualVolumeTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(incrementVolume:) userInfo:@{PMUserInfoMaxVolumeKey: @(volume), PMUserInfoIncrementsRemainingKey: @(increments)} repeats:NO];
}

- (void)stopAlertTone {
    if(self.overrideInProgress) {
        [self restoreRingerState];
    }
}

- (void)stopRinging {
    if(self.overrideInProgress) {
        [self.gradualVolumeTimer invalidate];
        [self restoreRingerState];
    }
}

#pragma mark - Timers

- (void)incrementVolume:(NSTimer *)timer {
    float maxVolume = [timer.userInfo[PMUserInfoMaxVolumeKey] floatValue];
    float remainingIncrements = [timer.userInfo[PMUserInfoIncrementsRemainingKey] floatValue] - 1;
    
    float currentVolume;
    [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
    
    float targetVolume = currentVolume + 0.1;
    if(targetVolume > maxVolume) {
        targetVolume = maxVolume;
        remainingIncrements = 0;
    }
    
    [self setRingerVolume:targetVolume];
    
    if(remainingIncrements) {
        self.gradualVolumeTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(incrementVolume:) userInfo:@{PMUserInfoMaxVolumeKey: @(maxVolume), PMUserInfoIncrementsRemainingKey: @(remainingIncrements)} repeats:NO];
    } else {
        self.gradualVolumeTimer = nil;
    }
}

- (void)checkSound:(NSTimer *)timer {
    NSLog(@"PocketMode: Returning to normal after sound increase for alert...");
    
    [self stopAlertTone];
}

#pragma mark - Logic

- (void)handleCall {
    [[UIApplication sharedApplication] setSystemVolumeHUDEnabled:NO forAudioCategory:@"Ringtone"];
    
    float currentVolume;
    [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
    self.regularVolume = currentVolume;
    
    NSLog(@"Current volume: %f", currentVolume);
    
    if(self.lux <= self.luxThreshold) {
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
        
        if(self.phoneCallMaxVolume > currentVolume) {
            if(self.phoneCallGradualVolume) {
                [self setRingerVolumeGradually:self.phoneCallMaxVolume];
            } else {
                [self setRingerVolume:self.phoneCallMaxVolume];
            }
        }
    }
}

- (void)handleMessage:(BBBulletin *)bulletin {
    [[UIApplication sharedApplication] setSystemVolumeHUDEnabled:NO forAudioCategory:@"Ringtone"];
    
    float currentVolume;
    [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
    self.regularVolume = currentVolume;
    
    if(self.lux <= self.luxThreshold) {
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
        
        if(self.messagesVolume > currentVolume) {
            [self setRingerVolume:self.messagesVolume];
        }
        
        self.activeSound = bulletin.sound;
        self.soundMonitorTimer = [NSTimer scheduledTimerWithTimeInterval:7.0 target:self selector:@selector(checkSound:) userInfo:nil repeats:NO];
    }
}

#pragma mark - Handle Events

- (void)incomingBulletin:(BBBulletin *)bulletin {
    NSLog(@"PocketMode: Incoming bulletin sectionID: %@", bulletin.sectionID);
    
    if(!self.alsConfigured || self.overrideInProgress) {
        return;
    }
    
    if([bulletin.sectionID isEqualToString:PMSMSIdentifier]) {
        if(self.messagesEnabled) {
            NSLog(@"PocketMode: Incoming SMS triggered: %@", bulletin.sectionID);
            
            [self handleMessage:bulletin];
        }
    }
}

- (void)incomingFaceTimeCall:(id)chat {
    if(self.alsConfigured && !self.overrideInProgress && self.phoneCallEnabled && self.phoneCallFacetimeEnabled) {
        NSLog(@"PocketMode: Incoming FaceTime call... Current date: %@ ALS staleness: %@ Lux: %ld", [NSDate date], self.lastReadingDate, (long)self.lux);
    } else {
        NSLog(@"PocketMode: Incoming FaceTime call... Not overriding.");
        return;
    }
    
    [self handleCall];
}

- (void)incomingPhoneCall:(id)call {
    if(self.alsConfigured && !self.overrideInProgress && self.phoneCallEnabled) {
        NSLog(@"PocketMode: Incoming phone call... Current date: %@ ALS staleness: %@ Lux: %ld", [NSDate date], self.lastReadingDate, (long)self.lux);
    } else {
        NSLog(@"PocketMode: Incoming phone call... Not overriding.");
        return;
    }
    
    [self handleCall];
}

@end

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

#import <SpringBoard/SpringBoard.h>
#import <objc/runtime.h>


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

NSString * const PMPreferencesPath = @"/var/mobile/Library/Preferences/be.dawson.pocketmodeprefs.plist";

NSString * const PMUserInfoIncrementsRemainingKey = @"IncrementsRemainingKey";
NSString * const PMUserInfoMaxVolumeKey = @"MaxVolumeKey";

NSString * const PMPreferenceGlobalEnabled = @"GlobalEnabled";

NSString * const PMPreferencePhoneCallEnabled = @"PhoneCallEnabled";
NSString * const PMPreferencePhoneCallGradualVolume = @"PhoneCallGradual";
NSString * const PMPreferencePhoneCallOverrideMute = @"PhoneCallOverrideMute";
NSString * const PMPreferencePhoneCallVolume = @"PhoneCallVolume";
NSString * const PMPreferencePhoneCallFacetimeEnabled = @"PhoneCallFacetimeEnabled";

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

// Settings - General

@property (nonatomic, assign) NSInteger luxThreshold;

// Settings - Phone Calls

@property (nonatomic, assign) BOOL phoneCallEnabled;
@property (nonatomic, assign) BOOL phoneCallFacetimeEnabled;
@property (nonatomic, assign) BOOL phoneCallGradualVolume;
@property (nonatomic, assign) BOOL phoneCallOverrideMute;
@property (nonatomic, assign) float phoneCallMaxVolume;

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
    
    self.overrideInProgress = NO;
    
    if(self.wasMuted) {
        SBMediaController *mediaController = [objc_getClass("SBMediaController") sharedInstance];
        [mediaController setRingerMuted:YES];
    }
    
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

#pragma mark - Logic

- (void)startHandlingCall {
    [[UIApplication sharedApplication] setSystemVolumeHUDEnabled:NO forAudioCategory:@"Ringtone"];
    
    float currentVolume;
    [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
    self.regularVolume = currentVolume;
    
    NSLog(@"Current volume: %f", currentVolume);
    
    if(self.lux <= self.luxThreshold && self.phoneCallMaxVolume > currentVolume) {
        self.overrideInProgress = YES;
        
        SBMediaController *mediaController = [objc_getClass("SBMediaController") sharedInstance];
        self.wasMuted = [mediaController isRingerMuted];
        
        if(self.phoneCallOverrideMute && self.wasMuted) {
            [mediaController setRingerMuted:NO];
        }
        if(self.phoneCallGradualVolume) {
            [self setRingerVolumeGradually:self.phoneCallMaxVolume];
        } else {
            [self setRingerVolume:self.phoneCallMaxVolume];
        }
    }
}


#pragma mark - Handle Events

- (void)incomingBulletin:(BBBulletin *)bulletin {
    NSLog(@"PocketMode: Incoming bulletin:\n  bulletinID: %@\n  bulletinVersionID: %@\n  publisherBulletinID: %@\n  recordID: %@\n  title: %@\n  observers: %@\n  alertSuppressionContexts: %@\n  context: %@\n  dismissalID: %@\n  sectionID: %@\n  alertSuppressionAppIDs: %@", bulletin.bulletinID, bulletin.bulletinVersionID, bulletin.publisherBulletinID, bulletin.recordID, bulletin.title, bulletin.observers, bulletin.alertSuppressionContexts, bulletin.context, bulletin.dismissalID, bulletin.sectionID, bulletin.alertSuppressionAppIDs);
    
    // sectionID: com.apple.MobileSMS
}

- (void)incomingFaceTimeCall:(id)chat {
    if(self.alsConfigured && !self.overrideInProgress && self.phoneCallEnabled && self.phoneCallFacetimeEnabled) {
        NSLog(@"PocketMode: Incoming FaceTime call... Current date: %@ ALS staleness: %@ Lux: %ld", [NSDate date], self.lastReadingDate, (long)self.lux);
    } else {
        NSLog(@"PocketMode: Incoming FaceTime call... Not overriding.");
        return;
    }
    
    [self startHandlingCall];
}

- (void)incomingPhoneCall:(id)call {
    if(self.alsConfigured && !self.overrideInProgress && self.phoneCallEnabled) {
        NSLog(@"PocketMode: Incoming phone call... Current date: %@ ALS staleness: %@ Lux: %ld", [NSDate date], self.lastReadingDate, (long)self.lux);
    } else {
        NSLog(@"PocketMode: Incoming phone call... Not overriding.");
        return;
    }
    
    [self startHandlingCall];
}

@end

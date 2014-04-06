//
//  PocketMode.m
//  
//
//  Created by Nick Dawson on 06/04/2014.
//
//

#import "PocketMode.h"

#import <Celestial/Celestial.h>
#import <IOKit/hid/IOHIDEventSystemClient.h>

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
		
		NSLog(@"PocketMode: lux now %ld", (long)lux);
        
        [[PocketMode sharedManager] updateLux:lux];
    }
}

@interface PocketMode()

// State

@property (nonatomic, assign) BOOL alsConfigured;
@property (nonatomic, assign) BOOL overrideInProgress;
@property (nonatomic, assign) float regularVolume;
@property (nonatomic, assign) NSInteger lux;
@property (nonatomic, strong) NSDate *lastReadingDate;

// Settings - General

@property (nonatomic, assign) NSInteger luxThreshold;

// Settings - Phone Calls

@property (nonatomic, assign) BOOL phoneCallEnabled;
@property (nonatomic, assign) BOOL phoneCallGradualVolume;
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
        
        [self loadPreferences];
        [self configureALS];
    }
    return self;
}

#pragma mark - Preferences

- (void)loadPreferences {
    self.luxThreshold = 10;
    
    self.phoneCallEnabled = YES;
    self.phoneCallGradualVolume = NO;
    self.phoneCallMaxVolume = 1.0;
    
    float currentVolume;
    [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
    self.regularVolume = currentVolume;
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
    [[AVSystemController sharedAVSystemController] setVolumeTo:self.regularVolume forCategory:@"Ringtone"];
    
    self.overrideInProgress = NO;
}

#pragma mark - Ringer



#pragma mark - Handle Events

- (void)incomingPhoneCall:(id)call {
    if(self.alsConfigured && !self.overrideInProgress) {
        NSLog(@"PocketMode: Incoming phone call... Current date: %@ ALS staleness: %@ Lux: %ld", [NSDate date], self.lastReadingDate, (long)self.lux);
    } else {
        NSLog(@"PocketMode: Incoming phone call... ALS not configured!");
        return;
    }
    
    float currentVolume;
    [[AVSystemController sharedAVSystemController] getVolume:&currentVolume forCategory:@"Ringtone"];
    self.regularVolume = currentVolume;
    
    NSLog(@"Current volume: %f", currentVolume);
    
    if(self.lux <= self.luxThreshold) {
        self.overrideInProgress = YES;
        [[AVSystemController sharedAVSystemController] setVolumeTo:self.phoneCallMaxVolume forCategory:@"Ringtone"];
    }
}

- (void)stopRinging {
    if(self.overrideInProgress) {
        [self restoreRingerState];
    }
}

@end

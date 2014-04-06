#import <CaptainHook/CaptainHook.h>

#import "PocketMode.h"

CHDeclareClass(MPIncomingPhoneCallController);

CHOptimizedMethod(1, self, id, MPIncomingPhoneCallController, initWithCall, id, call) {
    id orig = CHSuper(1, MPIncomingPhoneCallController, initWithCall, call);
    NSLog(@"Incoming call: %@", call);
    [[PocketMode sharedManager] incomingPhoneCall:call];

    return orig;
}

CHDeclareClass(SBPluginManager);

CHOptimizedMethod(1, self, Class, SBPluginManager, loadPluginBundle, NSBundle *, bundle) {
    id orig = CHSuper(1, SBPluginManager, loadPluginBundle, bundle);
    
    NSLog(@"SB Plugin Bundle: %@", bundle);

    if ([[bundle bundleIdentifier] isEqualToString:@"com.apple.mobilephone.incomingcall"] && [bundle isLoaded]) {
        CHLoadLateClass(MPIncomingPhoneCallController);
        CHHook(1, MPIncomingPhoneCallController, initWithCall);
    }

    return orig;
}

CHConstructor {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    CHLoadLateClass(SBPluginManager);
    CHHook(1, SBPluginManager, loadPluginBundle);
    
    [PocketMode sharedManager];

    [pool drain];
}

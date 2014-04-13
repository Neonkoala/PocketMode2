#import <CaptainHook/CaptainHook.h>

#import "PocketMode.h"

#pragma mark - ChatKit Service Bundle

CHDeclareClass(CKMessageAlertItem);

CHOptimizedClassMethod(0, self, void, CKMessageAlertItem, stopPlayingCurrentAlertTone) {
    [[PocketMode sharedManager] stopAlertTone];
    
    CHSuper(0, CKMessageAlertItem, stopPlayingCurrentAlertTone);
}

#pragma mark - IncomingCall Service Bundle

CHDeclareClass(MPIncomingFaceTimeCallController);

CHOptimizedMethod(1, self, id, MPIncomingFaceTimeCallController, initWithChat, id, chat) {
    id orig = CHSuper(1, MPIncomingFaceTimeCallController, initWithChat, chat);
    
    [[PocketMode sharedManager] incomingFaceTimeCall:chat];
    
    return orig;
}

CHOptimizedMethod(0, self, void, MPIncomingFaceTimeCallController, stopRingingOrVibrating) {
    [[PocketMode sharedManager] stopRinging];

    CHSuper(0, MPIncomingFaceTimeCallController, stopRingingOrVibrating);
}

CHDeclareClass(MPIncomingPhoneCallController);

CHOptimizedMethod(1, self, id, MPIncomingPhoneCallController, initWithCall, id, call) {
    id orig = CHSuper(1, MPIncomingPhoneCallController, initWithCall, call);

    [[PocketMode sharedManager] incomingPhoneCall:call];

    return orig;
}

CHOptimizedMethod(0, self, void, MPIncomingPhoneCallController, stopRingingOrVibrating) {
    [[PocketMode sharedManager] stopRinging];

    CHSuper(0, MPIncomingPhoneCallController, stopRingingOrVibrating);
}

#pragma mark - SpringBoard

CHDeclareClass(SBBulletinSoundController);

CHOptimizedMethod(0, self, void, SBBulletinSoundController, killSounds) {
    NSLog(@"PocketMode: Killing ALL sounds");
    
    [[PocketMode sharedManager] stopAlertTone];
    
    CHSuper(0, SBBulletinSoundController, killSounds);
}

CHOptimizedMethod(1, self, void, SBBulletinSoundController, killSoundForBulletin, id, bulletin) {
    NSLog(@"PocketMode: Killing sounds for bulletin: %@", bulletin);
    
    [[PocketMode sharedManager] stopAlertTone];
    
    CHSuper(1, SBBulletinSoundController, killSoundForBulletin, bulletin);
}

CHOptimizedMethod(1, self, BOOL, SBBulletinSoundController, playSoundForBulletin, id, bulletin) {
    NSLog(@"PocketMode: Playing sound for bulletin: %@", bulletin);
    
    [[PocketMode sharedManager] incomingBulletin:bulletin];
    
    BOOL result = CHSuper(1, SBBulletinSoundController, playSoundForBulletin, bulletin);
    
    return result;
}

CHOptimizedMethod(0, self, BOOL, SBBulletinSoundController, quietModeEnabled) {
    BOOL result = CHSuper(0, SBBulletinSoundController, quietModeEnabled);
    
    NSLog(@"PocketMode: Quiet mode enabled: %d", result);
    
    return result;
}

CHDeclareClass(SBPluginManager);

CHOptimizedMethod(1, self, Class, SBPluginManager, loadPluginBundle, NSBundle *, bundle) {
    id orig = CHSuper(1, SBPluginManager, loadPluginBundle, bundle);

    if([[bundle bundleIdentifier] isEqualToString:@"com.apple.mobilephone.incomingcall"] && [bundle isLoaded]) {
        CHLoadLateClass(MPIncomingPhoneCallController);
        CHHook(1, MPIncomingPhoneCallController, initWithCall);
        CHHook(0, MPIncomingPhoneCallController, stopRingingOrVibrating);
        
        CHLoadLateClass(MPIncomingFaceTimeCallController);
        CHHook(1, MPIncomingFaceTimeCallController, initWithChat);
        CHHook(0, MPIncomingFaceTimeCallController, stopRingingOrVibrating);
    } else if([[bundle bundleIdentifier] isEqualToString:@"com.apple.SMSPlugin"] && [bundle isLoaded]) {
        CHLoadLateClass(CKMessageAlertItem);
        CHClassHook(0, CKMessageAlertItem, stopPlayingCurrentAlertTone);
    }

    return orig;
}

CHConstructor {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    CHLoadLateClass(SBPluginManager);
    CHHook(1, SBPluginManager, loadPluginBundle);
    
    CHLoadLateClass(SBBulletinSoundController);
    CHHook(0, SBBulletinSoundController, killSounds);
    CHHook(1, SBBulletinSoundController, killSoundForBulletin);
    CHHook(1, SBBulletinSoundController, playSoundForBulletin);
    CHHook(0, SBBulletinSoundController, quietModeEnabled);
    
    [PocketMode sharedManager];

    [pool drain];
}

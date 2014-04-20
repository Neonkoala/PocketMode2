#import <CaptainHook/CaptainHook.h>

#import "PocketMode.h"

#pragma mark - MessageUI Framework

CHDeclareClass(MFSoundController);

CHOptimizedClassMethod(2, self, void, MFSoundController, playNewMailSoundStyle, unsigned, arg1, forAccount, id, account) {
    NSLog(@"PocketMode: playNewMailSoundStyle account: %@", account);
    
    CHSuper(2, MFSoundController, playNewMailSoundStyle, arg1, forAccount, account);
}

#pragma mark - ChatKit Service Bundle

CHDeclareClass(CKMessageAlertItem);

CHOptimizedClassMethod(0, self, void, CKMessageAlertItem, playMessageReceived) {
    NSLog(@"PocketMode: CKMessageAlertItem  +playMessageReceived");
    
    CHSuper(0, CKMessageAlertItem, playMessageReceived);
}

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

CHDeclareClass(SBBannerController);

CHOptimizedMethod(1, self, void, SBBannerController, _playSoundForContext, id, context) {
    NSLog(@"PocketMode: Play sound for context: %@", context);
    
    // Context: <SBUIBannerContext:0x17043e4c0 target=<SBBannerController: 0x1704aa020> source=<SBBulletinBannerController: 0x170a459a0> item=<SBBulletinBannerItem: 0x170e40780>>
    
    CHSuper(1, SBBannerController, _playSoundForContext, context);
}

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

CHDeclareClass(SBLockScreenNotificationListController);

CHOptimizedMethod(1, self, void, SBLockScreenNotificationListController, _playSoundForBulletinIfPossible, id, bulletinIfPossible) {
    NSLog(@"PocketMode: _playSoundForBulletinIfPossible: %@", bulletinIfPossible);
    
    // Check if possible
    
    CHSuper(1, SBLockScreenNotificationListController, _playSoundForBulletinIfPossible, bulletinIfPossible);
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
        CHClassHook(0, CKMessageAlertItem, playMessageReceived);
        CHClassHook(0, CKMessageAlertItem, stopPlayingCurrentAlertTone);
    }

    return orig;
}

CHDeclareClass(SBPushStore);

CHOptimizedMethod(7, self, void, SBPushStore, saveRemoteNotificationWithMessage, id, message, soundName, id, name, actionText, id, text, badge, id, badge, userInfo, id, info, launchImage, id, image, forBundleID, id, bundleID) {
    NSLog(@"PocketMode: saveRemoteNotificationWithMessage: %@ soundName: %@ actionText: %@ badge: %@ userInfo: %@ bundleID: %@", message, name, text, badge, info, bundleID);
    
    // Good for all push except mail / messages
    
    CHSuper(7, SBPushStore, saveRemoteNotificationWithMessage, message, soundName, name, actionText, text, badge, badge, userInfo, info, launchImage, image, forBundleID, bundleID);
}

CHDeclareClass(SBSoundController);

CHOptimizedMethod(3, self, BOOL, SBSoundController, playSound, id, sound, environments, int, environments, completion, id, completion) {
    BOOL result = CHSuper(3, SBSoundController, playSound, sound, environments, environments, completion, completion);
    
    NSLog(@"PocketMode: SBSoundController: playSound: %@ environments: %d completion: %@", sound, environments, completion);
    
    return result;
}

CHConstructor {
    @autoreleasepool {
        CHLoadLateClass(SBPluginManager);
        CHHook(1, SBPluginManager, loadPluginBundle);
    
        CHLoadLateClass(SBBannerController);
        CHHook(1, SBBannerController, _playSoundForContext);
        
        CHLoadLateClass(SBBulletinSoundController);
        CHHook(0, SBBulletinSoundController, killSounds);
        CHHook(1, SBBulletinSoundController, killSoundForBulletin);
        CHHook(1, SBBulletinSoundController, playSoundForBulletin);
        
        CHLoadLateClass(SBLockScreenNotificationListController);
        CHHook(1, SBLockScreenNotificationListController, _playSoundForBulletinIfPossible);
        
        CHLoadLateClass(SBPushStore);
        CHHook(7, SBPushStore, saveRemoteNotificationWithMessage, soundName, actionText, badge, userInfo, launchImage, forBundleID);
        
        CHLoadLateClass(SBSoundController);
        CHHook(3, SBSoundController, playSound, environments, completion);
        
        CHLoadLateClass(MFSoundController);
        CHHook(2, MFSoundController, playNewMailSoundStyle, forAccount);
    
        [PocketMode sharedManager];
    }
}

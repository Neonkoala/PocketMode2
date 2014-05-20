#import "FSSwitchDataSource.h"
#import "FSSwitchPanel.h"

NSString * const PMPreferencesPath = @"/var/mobile/Library/Preferences/be.dawson.pocketmodeprefs.plist";
NSString * const PMPreferenceGlobalEnabled = @"GlobalEnabled";

@interface pocketmodeswitchSwitch : NSObject <FSSwitchDataSource>
@end

@implementation pocketmodeswitchSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:PMPreferencesPath];
    
    if(preferences) {
        BOOL enabled = [preferences[PMPreferenceGlobalEnabled] boolValue];
        if(enabled) {
            return FSSwitchStateOn;
        } else {
            return FSSwitchStateOff;
        }
    }
    
    return FSSwitchStateIndeterminate;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier
{
    BOOL enabled;
    
	switch (newState) {
        case FSSwitchStateOff:
            enabled = NO;
            break;
            
        case FSSwitchStateOn:
            enabled = YES;
            break;
            
        case FSSwitchStateIndeterminate:
        default:
            return;
    }
    
    NSMutableDictionary *preferences = [NSMutableDictionary dictionaryWithContentsOfFile:PMPreferencesPath];
    [preferences setObject:@(enabled) forKey:PMPreferenceGlobalEnabled];
    [preferences writeToFile:PMPreferencesPath atomically:YES];
    
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(center, CFSTR("be.dawson.pocketmode.prefsChanged"), NULL, NULL, TRUE);
    
    return;
}

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier {
        return @"PocketMode";
}

@end
#import <Preferences/Preferences.h>

@interface PocketModePrefsListController: PSListController

@end

@implementation PocketModePrefsListController

- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"PocketModePrefs" target:self] retain];
	}
	return _specifiers;
}

- (void)openTwitterLink {
    NSURL *deepLinkURL = [NSURL URLWithString:@"twitter://user?screen_name=nidawson"];
    if([[UIApplication sharedApplication] canOpenURL:deepLinkURL]) {
        [[UIApplication sharedApplication] openURL:deepLinkURL];
    } else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/nidawson"]];
    }
}

- (void)openUserGuide {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://dawson.be"]];
}

@end

// vim:ft=objc

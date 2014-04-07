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

- (void)openUserGuide {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://dawson.be"]];
}

@end

// vim:ft=objc

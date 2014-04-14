//
//  NotificationsController.m
//  
//
//  Created by Nick Dawson on 12/04/2014.
//
//

#import "NotificationsController.h"

@implementation NotificationsController

- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"PocketModePrefs" target:self] retain];
	}
	return _specifiers;
}

@end

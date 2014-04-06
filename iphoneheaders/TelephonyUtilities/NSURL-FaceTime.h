/*
 *     Generated by class-dump 3.4 (64 bit).
 *
 *     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2012 by Steve Nygard.
 */

#import "NSURL.h"

@interface NSURL (FaceTime)
+ (id)faceTimeURLWithURL:(id)arg1;
+ (id)faceTimeAcceptURLWithURL:(id)arg1 conferenceID:(id)arg2;
+ (id)faceTimeAcceptURLWithURL:(id)arg1;
+ (id)faceTimePromptURLWithURL:(id)arg1;
+ (id)_applyFaceTimeScheme:(id)arg1 toFaceTimeURL:(id)arg2;
+ (id)faceTimeURLWithDestinationID:(id)arg1 addressBookUID:(int)arg2 audioOnly:(BOOL)arg3;
+ (id)faceTimeURLWithDestinationID:(id)arg1 addressBookUID:(int)arg2;
+ (id)faceTimeURLWithDestinationID:(id)arg1;
+ (id)_faceTimeURLWithDestinationID:(id)arg1 addressBookUID:(int)arg2 audioOnly:(BOOL)arg3;
- (BOOL)isValidFaceTimeURL;
- (BOOL)isUpgradeURL;
- (BOOL)isFaceTimeAudioAcceptURL;
- (BOOL)isFaceTimeAudioPromptURL;
- (BOOL)isFaceTimeAudioURL;
- (BOOL)isFaceTimeAcceptURL;
- (BOOL)isFaceTimePromptURL;
- (BOOL)isFaceTimeURL;
- (BOOL)_isPhoneNumberID:(id)arg1;
- (id)faceTimeDestinationAccount;
@end


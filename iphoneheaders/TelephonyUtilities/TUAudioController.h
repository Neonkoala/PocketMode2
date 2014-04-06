/*
 *     Generated by class-dump 3.4 (64 bit).
 *
 *     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2012 by Steve Nygard.
 */

#import "NSObject.h"

@interface TUAudioController : NSObject
{
    struct dispatch_semaphore_s *_modifyingStateLock;
    struct dispatch_group_s *_outstandingRequestsGroup;
}

- (void)blockUntilOutstandingRequestsComplete;
- (void)dealloc;
- (id)init;
- (void)_requestUpdatedValueWithBlock:(id)arg1 object:(void)arg2 isRequestingPointer:(id *)arg3 forceNewRequest:(char *)arg4 scheduleTimePointer:(BOOL)arg5 notificationString:(unsigned long long *)arg6 queue:(id)arg7;
- (void)_leaveOutstandingRequestsGroup;
- (void)_enterOutstandingRequestsGroup;
- (void)_releaseLock;
- (void)_acquireLock;

@end


/**
 * This header is generated by class-dump-z 0.2-0.
 * class-dump-z is Copyright (C) 2009 by KennyTM~, licensed under GPLv3.
 *
 * Source: /System/Library/PrivateFrameworks/Symbolication.framework/Symbolication
 */

#import <Foundation/NSObject.h>

@class VMULinkedListEntry;

@interface VMULinkedList : NSObject {
	VMULinkedListEntry* _head;
	VMULinkedListEntry* _tail;
}
+(VMULinkedList*)linkedList;
// inherited: -(id)init;
-(id)head;
-(id)tail;
-(void)removeAllObjects;
-(void)pushHead:(id)head;
-(id)popTail;
-(void)remove:(id)remove;
@end


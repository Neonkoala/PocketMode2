/**
 * This header is generated by class-dump-z 0.2a.
 * class-dump-z is Copyright (C) 2009 by KennyTM~, licensed under GPLv3.
 *
 * Source: /System/Library/Frameworks/MediaPlayer.framework/MediaPlayer
 */

#import <Foundation/NSObject.h>
#import "NSCoding.h"

@class MPMediaItem, MPMediaItemCollectionInternal, NSArray;

@interface MPMediaItemCollection : NSObject <NSCoding> {
@private
	MPMediaItemCollectionInternal* _internal;
}
@property(readonly, assign, nonatomic) int mediaTypes;
@property(readonly, assign, nonatomic) unsigned count;
@property(readonly, assign, nonatomic) MPMediaItem* representativeItem;
@property(readonly, assign, nonatomic) NSArray* items;
+(id)collectionWithItems:(id)items;
-(id)init;
-(id)initWithItems:(id)items;
-(id)_init;
-(id)_initWithItemsQuery:(id)itemsQuery itemsCount:(unsigned)count representativeItem:(id)item containedMediaTypes:(int)types;
-(void)dealloc;
-(id)initWithCoder:(id)coder;
-(void)encodeWithCoder:(id)coder;
@end


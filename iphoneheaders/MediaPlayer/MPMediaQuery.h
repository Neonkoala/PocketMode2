/**
 * This header is generated by class-dump-z 0.2a.
 * class-dump-z is Copyright (C) 2009 by KennyTM~, licensed under GPLv3.
 *
 * Source: /System/Library/Frameworks/MediaPlayer.framework/MediaPlayer
 */

#import <Foundation/NSObject.h>
#import "MediaPlayer-Structs.h"
#import "NSCoding.h"
#import "NSCopying.h"

@class NSArray, MPMediaQueryInternal, NSSet;

@interface MPMediaQuery : NSObject <NSCoding, NSCopying> {
@private
	MPMediaQueryInternal* _internal;
}
@property(assign, nonatomic) int groupingType;
@property(readonly, assign, nonatomic) NSArray* collections;
@property(readonly, assign, nonatomic) NSArray* items;
@property(retain, nonatomic) NSSet* filterPredicates;
+(id)albumsQuery;
+(id)artistsQuery;
+(id)songsQuery;
+(id)playlistsQuery;
+(id)podcastsQuery;
+(id)audiobooksQuery;
+(id)compilationsQuery;
+(id)composersQuery;
+(id)genresQuery;
+(void)setFilteringDisabled:(BOOL)disabled;
+(id)videosQuery;
-(id)init;
-(id)initWithFilterPredicates:(id)filterPredicates;
-(id)_initWithMLQuery:(id)mlquery;
-(void)dealloc;
-(id)description;
-(id)initWithCoder:(id)coder;
-(void)encodeWithCoder:(id)coder;
-(id)copyWithZone:(NSZone*)zone;
-(void)addFilterPredicate:(id)predicate;
-(void)removeFilterPredicate:(id)predicate;
-(unsigned)countOfItems;
-(unsigned)countOfCollections;
-(BOOL)prefetchProperties;
-(void)setPrefetchProperties:(BOOL)properties;
-(void)setSortItems:(BOOL)items;
-(BOOL)sortItems;
-(void)_clearCachedItemsAndCollections;
-(void)_didReceiveMemoryWarning:(id)warning;
@end


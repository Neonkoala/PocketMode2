/**
 * This header is generated by class-dump-z 0.2-0.
 * class-dump-z is Copyright (C) 2009 by KennyTM~, licensed under GPLv3.
 *
 * Source: /System/Library/PrivateFrameworks/PhotoLibrary.framework/PhotoLibrary
 */

#import "NSObject.h"


@protocol PLItemView <NSObject>
-(void)updateZoomScales;
-(BOOL)isZoomedOut;
-(float)defaultZoomScale;
-(float)_zoomScale;
-(void)_setZoomScale:(float)scale duration:(double)duration;
-(float)minRotatedScale;
-(int)orientationWhenLastDisplayed;
-(void)setOrientationWhenLastDisplayed:(int)displayed;
@end


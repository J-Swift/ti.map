/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-Present by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiMapAnnotationProxy.h"
#import "TiUtils.h"
#import "TiViewProxy.h"
#import "ImageLoader.h"
#import "TiButtonUtil.h"
#import "TiMapConstants.h"
#import "UIColor+AndroidHueParity.h"
#import "TiMapViewProxy.h"
#import "TiMapView.h"

@implementation TiMapAnnotationProxy

@synthesize delegate;
@synthesize needsRefreshingWithSelection;
@synthesize placed;
@synthesize offset;

#define LEFT_BUTTON  1
#define RIGHT_BUTTON 2

#pragma mark Internal

-(void)_configure
{
	static int mapTags = 0;
	tag = mapTags++;
	needsRefreshingWithSelection = YES;
	offset = CGPointZero;
	[super _configure];
}

-(NSString*)apiName
{
    return @"Ti.Map.Annotation";
}

-(NSMutableDictionary*)langConversionTable
{
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:@"title",@"titleid",@"subtitle",@"subtitleid",nil];
}


-(UIView*)makeButton:(id)button tag:(int)buttonTag
{
	UIView *button_view = nil;
	if ([button isKindOfClass:[NSNumber class]])
	{
		// this is button type constant
		int type = [TiUtils intValue:button];
		button_view = [TiButtonUtil buttonWithType:type];
	}
	else 
	{
		UIImage *image = [[ImageLoader sharedLoader] loadImmediateImage:[TiUtils toURL:button proxy:self]];
		if (image!=nil)
		{
			CGSize size = [image size];
			UIButton *bview = [UIButton buttonWithType:UIButtonTypeCustom];
			[TiUtils setView:bview positionRect:CGRectMake(0,0,size.width,size.height)];
			bview.backgroundColor = [UIColor clearColor];
			[bview setImage:image forState:UIControlStateNormal];
			button_view = bview;
		}
	}
	if (button_view!=nil)
	{
		button_view.tag = buttonTag;
	}
	return button_view;
}

-(void)refreshAfterDelay
{
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
		[self refreshIfNeeded];
	});
}

-(void)setNeedsRefreshingWithSelection: (BOOL)shouldReselect
{
	if (delegate == nil)
	{
		return; //Nobody to refresh!
	}
	@synchronized(self)
	{
		BOOL invokeMethod = !needsRefreshing;
		needsRefreshing = YES;
		needsRefreshingWithSelection |= shouldReselect;

		if (invokeMethod)
		{
			TiThreadPerformOnMainThread(^{[self refreshAfterDelay];}, NO);
		}
	}
}

-(void)refreshIfNeeded
{
	@synchronized(self)
	{
		if (!needsRefreshing)
		{
			return; //Already done.
		}
		if (delegate!=nil && [delegate viewAttached])
		{
			[(TiMapView*)[delegate view] refreshAnnotation:self readd:needsRefreshingWithSelection];
		}
		needsRefreshing = NO;
		needsRefreshingWithSelection = NO;
	}
}

#pragma mark Public APIs

-(CLLocationCoordinate2D)coordinate
{
	CLLocationCoordinate2D result;
	result.latitude = [TiUtils doubleValue:[self valueForUndefinedKey:@"latitude"]];
	result.longitude = [TiUtils doubleValue:[self valueForUndefinedKey:@"longitude"]];
	return result;
}

-(void)setCoordinate:(CLLocationCoordinate2D)coordinate
{
	[self setValue:[NSNumber numberWithDouble:coordinate.latitude] forUndefinedKey:@"latitude"];
	[self setValue:[NSNumber numberWithDouble:coordinate.longitude] forUndefinedKey:@"longitude"];
}

-(void)setLatitude:(id)latitude
{
    double curValue = [TiUtils doubleValue:[self valueForUndefinedKey:@"latitude"]];
    double newValue = [TiUtils doubleValue:latitude];
    [self replaceValue:latitude forKey:@"latitude" notification:NO];
    if (newValue != curValue) {
        [self setNeedsRefreshingWithSelection:YES];
    }
}

-(void)setLongitude:(id)longitude
{
    double curValue = [TiUtils doubleValue:[self valueForUndefinedKey:@"longitude"]];
    double newValue = [TiUtils doubleValue:longitude];
    [self replaceValue:longitude forKey:@"longitude" notification:NO];
    if (newValue != curValue) {
        [self setNeedsRefreshingWithSelection:YES];
    }
}

// Title and subtitle for use by selection UI.
- (NSString *)title
{
	return [self valueForUndefinedKey:@"title"];
}

-(void)setTitle:(id)title
{
	title = [TiUtils replaceString:[TiUtils stringValue:title]
			characters:[NSCharacterSet newlineCharacterSet] withString:@" "];
	//The label will strip out these newlines anyways (Technically, replace them with spaces)

	id current = [self valueForUndefinedKey:@"title"];
	[self replaceValue:title forKey:@"title" notification:NO];
	if (![title isEqualToString:current])
	{
		[self setNeedsRefreshingWithSelection:NO];
	}
}

- (NSString *)subtitle
{
	return [self valueForUndefinedKey:@"subtitle"];
}

-(void)setSubtitle:(id)subtitle
{
	subtitle = [TiUtils replaceString:[TiUtils stringValue:subtitle]
			characters:[NSCharacterSet newlineCharacterSet] withString:@" "];
	
	// The label will strip out these newlines anyways (Technically, replace them with spaces)

	id current = [self valueForUndefinedKey:@"subtitle"];
	[self replaceValue:subtitle forKey:@"subtitle" notification:NO];
	
	if (![subtitle isEqualToString:current]) {
		[self setNeedsRefreshingWithSelection:NO];
	}
}

-(void)setHidden:(id)value
{
	id current = [self valueForUndefinedKey:@"hidden"];
	[self replaceValue:value forKey:@"hidden" notification:NO];
	
	if ([current isEqual:value] == NO) {
		[self setNeedsRefreshingWithSelection:YES];
	}
}

-(id)hidden
{
	return NUMBOOL([TiUtils boolValue:[self valueForUndefinedKey:@"hidden"] def:NO]);
}

-(id)pincolor
{
    return NUMINT([self valueForUndefinedKey:@"pincolor"]);
}

-(void)setPincolor:(id)color
{
	id current = [self valueForUndefinedKey:@"pincolor"];
	[self replaceValue:color forKey:@"pincolor" notification:NO];
	if (current!=color)
	{
		[self setNeedsRefreshingWithSelection:YES];
	}
}

// Mapping both string-colors, color constant and native colors to a pin color
// This is overcomplicated to maintain iOS < 9 compatibility. Remove this when
// we have a minimum iOS verion of 9.0+
-(id)nativePinColor
{
    id current = [self valueForUndefinedKey:@"pincolor"];
    
    if ([current isKindOfClass:[NSString class]]) {
#ifdef __IPHONE_9_0
        return [[TiUtils colorValue:current] color];
#else
        return MKPinAnnotationColorRed;
#endif
    }

    switch ([TiUtils intValue:current def:TiMapAnnotationPinColorRed]) {
        case TiMapAnnotationPinColorGreen: {
#ifdef __IPHONE_9_0
            return [MKPinAnnotationView greenPinColor];
#else
            return MKPinAnnotationColorGreen;
#endif
        }
        case TiMapAnnotationPinColorPurple: {
#ifdef __IPHONE_9_0
            return [MKPinAnnotationView purplePinColor];
#else
            return MKPinAnnotationColorPurple;
#endif
        }
#ifdef __IPHONE_9_0
        case TiMapAnnotationPinColorBlue:
        return [UIColor blueColor];
        case TiMapAnnotationPinColorCyan:
        return [UIColor cyanColor];
        case TiMapAnnotationPinColorMagenta:
        return [UIColor magentaColor];
        case TiMapAnnotationPinColorOrange:
        return [UIColor orangeColor];
        case TiMapAnnotationPinColorYellow:
        return [UIColor yellowColor];

        // UIColor extensions
        case TiMapAnnotationPinColorAzure:
        return [UIColor azureColor];
        case TiMapAnnotationPinColorRose:
        return [UIColor roseColor];
        case TiMapAnnotationPinColorViolet:
        return [UIColor violetColor];
#endif
        case TiMapAnnotationPinColorRed:
        default: {
#ifdef __IPHONE_9_0
            return [MKPinAnnotationView redPinColor];
#else
            return MKPinAnnotationColorRed;
#endif
        }
    }
}

- (BOOL)animatesDrop
{
	return [TiUtils boolValue:[self valueForUndefinedKey:@"animate"]];
}

- (UIView*)leftViewAccessory
{
	TiViewProxy* viewProxy = [self valueForUndefinedKey:@"leftView"];
	if (viewProxy!=nil && [viewProxy isKindOfClass:[TiViewProxy class]])
	{
		return [viewProxy view];
	}
	else
	{
		id button = [self valueForUndefinedKey:@"leftButton"];
		if (button!=nil)
		{
			return [self makeButton:button tag:LEFT_BUTTON];
		}
	}
	return nil;
}

- (UIView*)rightViewAccessory
{
	TiViewProxy* viewProxy = [self valueForUndefinedKey:@"rightView"];
	if (viewProxy!=nil && [viewProxy isKindOfClass:[TiViewProxy class]])
	{
		return [viewProxy view];
	}
	else
	{
		id button = [self valueForUndefinedKey:@"rightButton"];
		if (button!=nil)
		{
			return [self makeButton:button tag:RIGHT_BUTTON];
		}
	}
	return nil;
}

- (void)setLeftButton:(id)button
{
	id current = [self valueForUndefinedKey:@"leftButton"];
	[self replaceValue:button forKey:@"leftButton" notification:NO];
	if (current!=button)
	{
		[self setNeedsRefreshingWithSelection:YES];
	}
}

- (void)setRightButton:(id)button
{
	id current = [self valueForUndefinedKey:@"rightButton"];
	[self replaceValue:button forKey:@"rightButton" notification:NO];
	if (current!=button)
	{
		[self setNeedsRefreshingWithSelection:YES];
	}
}

- (void)setRightView:(id)rightview
{
	id current = [self valueForUndefinedKey:@"rightView"];
	[self replaceValue:rightview forKey:@"rightView" notification:NO];
	if (current!=rightview)
	{
		[self setNeedsRefreshingWithSelection:YES];
	}
}

- (void)setLeftView:(id)leftview
{
	id current = [self valueForUndefinedKey:@"leftView"];
	[self replaceValue:leftview forKey:@"leftView" notification:NO];
	if (current!=leftview)
	{
		[self setNeedsRefreshingWithSelection:YES];
	}
}

-(void)setImage:(id)image
{
	id current = [self valueForUndefinedKey:@"image"];
	[self replaceValue:image forKey:@"image" notification:NO];
	if ([current isEqual: image] == NO)
	{
		[self setNeedsRefreshingWithSelection:YES];
	}
}

-(void)setCustomView:(id)customView
{
	id current = [self valueForUndefinedKey:@"customView"];
	[self replaceValue:customView forKey:@"customView" notification:NO];
	if ([current isEqual: customView] == NO)
	{
        [current setProxyObserver:nil];
        [self forgetProxy:current];
        [self rememberProxy:customView];
        [customView setProxyObserver:self];
        [self setNeedsRefreshingWithSelection:YES];
	}
}

-(void)proxyDidRelayout:(id)sender
{
    id current = [self valueForUndefinedKey:@"customView"];
    if ( ([current isEqual:sender] == YES) && (self.placed) ) {
        [self setNeedsRefreshingWithSelection:YES];
    }
}

- (void)setCenterOffset:(id)centeroffset
{
    [self replaceValue:centeroffset forKey:@"centerOffset" notification:NO];
    CGPoint newVal = [TiUtils pointValue:centeroffset];
    if (!CGPointEqualToPoint(newVal,offset)) {
        offset = newVal;
        [self setNeedsRefreshingWithSelection:YES];
    }
}

-(int)tag
{
	return tag;
}

@end

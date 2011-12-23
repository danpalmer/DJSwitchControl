//
//  DJSwitchControl.m
//  DJSwitchControl
//
//  Created by Dan Palmer on 22/12/2011.
//  Copyright (c) 2011 Dan Palmer. All rights reserved.
//

#import "DJSwitchControl.h"

#import <QuartzCore/QuartzCore.h>

#define CONTROL_HEIGHT 30.0
#define CONTROL_WIDTH 80.0
#define CONTROL_CORNER_RADIUS (CONTROL_HEIGHT/2.0)

#define KNOB_DIAMETER 28.0
#define KNOB_CORNER_RADIUS (KNOB_DIAMETER/2.0)
#define KNOB_RADIUS (KNOB_DIAMETER/2.0)

#define BACKGROUND_SECTION_HEIGHT 30.0
#define BACKGROUND_SECTION_WIDTH (CONTROL_WIDTH - (KNOB_DIAMETER / 2.0))

#define SWITCH_FONT_SIZE 16.0
#define SWITCH_FONT_NAME @"Helvetica Neue Bold"

NSString *const DJSwitchControlLayerRoot = @"rootLayer";
NSString *const DJSwitchControlLayerKnob = @"knobLayer";
NSString *const DJSwitchControlLayerOn = @"onLayer";
NSString *const DJSwitchControlLayerOff = @"offLayer";
NSString *const DJSwitchControlLayerInnerShadow = @"inerLayer";

#pragma mark -
#pragma mark Categories

@interface NSColor (DJSwitchControlAdditions)
- (CGColorRef)CGColor;
+ (NSColor *)onStateColor;
+ (NSColor *)offStateColor;
@end

@implementation NSColor (DJSwitchControlAdditions)
- (CGColorRef)CGColor {
	CGColorSpaceRef colorSpace = [[self colorSpace] CGColorSpace];
	NSInteger componentCount = [self numberOfComponents];
	CGFloat *components = (CGFloat *)calloc(componentCount, sizeof(CGFloat));
	[self getComponents:components];
	CGColorRef color = CGColorCreate(colorSpace, components);
	free((void*)components);
	return color;
}

+ (NSColor *)onStateColor {
	return [NSColor colorWithDeviceRed:0.0000 green:0.4980 blue:0.9176 alpha:1.0000];
}
+ (NSColor *)offStateColor {
	return [NSColor colorWithDeviceRed:0.9333 green:0.9333 blue:0.9333 alpha:1.0000];
}
@end

@interface NSBezierPath (DJSwitchControlAdditions)
- (CGPathRef)CGPath;
@end

@implementation NSBezierPath (DJSwitchControlAdditions)

// From the Apple documentation for NSBezierPath
//   http://developer.apple.com/library/mac/#documentation/cocoa/Conceptual/CocoaDrawingGuide/Paths/Paths.html
- (CGPathRef)CGPath {
    NSInteger i, numElements;
    CGPathRef immutablePath = NULL;
    numElements = [self elementCount];
	
    if (numElements > 0) {
        CGMutablePathRef path = CGPathCreateMutable();
        NSPoint points[3];
        BOOL didClosePath = YES;
		
        for (i = 0; i < numElements; i++) {
            switch ([self elementAtIndex:i associatedPoints:points]) {
                case NSMoveToBezierPathElement:
                    CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
                    break;
					
                case NSLineToBezierPathElement:
                    CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
                    didClosePath = NO;
                    break;
					
                case NSCurveToBezierPathElement:
                    CGPathAddCurveToPoint(path, NULL, points[0].x, points[0].y,
										  points[1].x, points[1].y,
										  points[2].x, points[2].y);
                    didClosePath = NO;
                    break;
					
                case NSClosePathBezierPathElement:
                    CGPathCloseSubpath(path);
                    didClosePath = YES;
                    break;
            }
        }
		
        if (!didClosePath) {
			CGPathCloseSubpath(path);
		}
		
        immutablePath = CGPathCreateCopy(path);
        CGPathRelease(path);
    }
	
    return immutablePath;
}
@end

#pragma mark -
#pragma mark Private Interface

@interface DJSwitchControl ()

@property (retain) CALayer *knobLayer;
@property (retain) CALayer *onLayer;
@property (retain) CALayer *offLayer;
@property (copy) void (^mouseTrackingBlock)(NSEvent *);

@property (nonatomic, assign, getter=isActive) BOOL active;

- (void)setupLayers;
- (void)switchToOn;
- (void)switchToOff;
- (void)performAction;
- (void)moveSwitchToNewOffset:(NSInteger)newOffset disableAnimations:(BOOL)disableAnimations;
- (void)drawInnerShadowLayer:(CALayer *)layer inContext:(CGContextRef)context;
- (void)drawKnobLayer:(CALayer *)layer inContext:(CGContextRef)context;
- (void)drawOnLayer:(CALayer *)layer inContext:(CGContextRef)context;
- (void)drawOffLayer:(CALayer *)layer inContext:(CGContextRef)context;
- (void)drawHighlightForLayer:(CALayer *)layer inContext:(CGContextRef)context withOpacity:(CGFloat)opacity;
- (CGPathRef)newPathForRoundedRect:(CGRect)rect radius:(CGFloat)radius;
CGGradientRef CreateGradientRefWithColors(CGColorSpaceRef colorSpace, CGColorRef startColor, CGColorRef endColor);

@end

@implementation DJSwitchControl

@synthesize on=_on;
@synthesize target=_target;
@synthesize action=_action;

@synthesize knobLayer=_knobLayer;
@synthesize onLayer=_onLayer;
@synthesize offLayer=_offLayer;
@synthesize mouseTrackingBlock=_mouseTrackingBlock;

@synthesize active=_active;

#pragma mark -
#pragma mark Initialisation

- (void)awakeFromNib {
	[self setOn:NO];
	[self setupLayers];
}

- (void)setupLayers {
	// Note the initial state is ON, with the knob on the left hand side
	
	CALayer *rootLayer = [[[CALayer alloc] init] autorelease];
	[rootLayer setName:DJSwitchControlLayerRoot];
	[rootLayer setCornerRadius:CONTROL_CORNER_RADIUS];
	[rootLayer setBorderWidth:1.0];
	[rootLayer setBorderColor:[[NSColor blackColor] CGColor]];
	[rootLayer setFrame:CGRectMake(0, 0, CONTROL_WIDTH, CONTROL_HEIGHT)];
	[rootLayer setMasksToBounds:YES];
	[rootLayer setDelegate:self];
	
	CALayer *knobLayer = [[[CALayer alloc] init] autorelease];
	{
		[knobLayer setName:DJSwitchControlLayerKnob];
		[knobLayer setFrame:CGRectMake(0, 1, KNOB_DIAMETER, KNOB_DIAMETER)];
		[knobLayer setBackgroundColor:[[NSColor grayColor] CGColor]];
		[knobLayer setCornerRadius:KNOB_CORNER_RADIUS];
		[knobLayer setDelegate:self];
		[knobLayer setNeedsDisplay];
		
		[knobLayer setShadowColor:[[NSColor blackColor] CGColor]];
		[knobLayer setShadowOffset:CGSizeMake(0, 0)];
		[knobLayer setShadowRadius:3.0];
		[knobLayer setShadowOpacity:1.0];
	}
	[self setKnobLayer:knobLayer];
	
	
	CALayer *offLayer = [[[CALayer alloc] init] autorelease];
	{
		[offLayer setName:DJSwitchControlLayerOff];
		[offLayer setFrame:CGRectMake(KNOB_RADIUS, 0, BACKGROUND_SECTION_WIDTH, BACKGROUND_SECTION_HEIGHT)];
		[offLayer setBackgroundColor:[[NSColor offStateColor] CGColor]];
		[offLayer setDelegate:self];
		CATextLayer *offTextLayer = [[[CATextLayer alloc] init] autorelease];
		{
			[offTextLayer setString:@"OFF"];
			[offTextLayer setFontSize:SWITCH_FONT_SIZE];
			[offTextLayer setFont:@"Helvetica Neue Bold"];
			[offTextLayer setForegroundColor:[[NSColor grayColor] CGColor]];
			
			[offTextLayer setShadowOffset:CGSizeMake(0, -1)];
			[offTextLayer setShadowColor:[[NSColor whiteColor] CGColor]];
			[offTextLayer setShadowRadius:0.0];
			[offTextLayer setShadowOpacity:0.5];
			
			CGSize preferredSize = [offTextLayer preferredFrameSize];
			[offTextLayer setFrame:CGRectMake(lroundf((((BACKGROUND_SECTION_WIDTH - KNOB_RADIUS) / 2.0) - (preferredSize.width / 2.0)) + (KNOB_RADIUS * 0.75)), 
											  ((BACKGROUND_SECTION_HEIGHT / 2.0) - (preferredSize.height / 2.0)), 
											  preferredSize.width, 
											  preferredSize.height)];
		}
		[offLayer addSublayer:offTextLayer];
		[offLayer setNeedsDisplay];
	}
	[self setOffLayer:offLayer];
	
	CALayer *onLayer = [[[CALayer alloc] init] autorelease];
	{
		[onLayer setName:DJSwitchControlLayerOn];
		[onLayer setFrame:CGRectMake((KNOB_RADIUS - BACKGROUND_SECTION_WIDTH), 0, BACKGROUND_SECTION_WIDTH, BACKGROUND_SECTION_HEIGHT)];
		[onLayer setBackgroundColor:[[NSColor onStateColor] CGColor]];
		[onLayer setDelegate:self];
		CATextLayer *onTextLayer = [[[CATextLayer alloc] init] autorelease];
		{
			[onTextLayer setFrame:CGRectMake(KNOB_RADIUS, 0, BACKGROUND_SECTION_WIDTH - KNOB_RADIUS, BACKGROUND_SECTION_HEIGHT)];
			[onTextLayer setString:@"ON"];
			[onTextLayer setFontSize:SWITCH_FONT_SIZE];
			[onTextLayer setFont:@"Helvetica Neue Bold"];
			[onTextLayer setForegroundColor:[[NSColor whiteColor] CGColor]];
			
			[onTextLayer setShadowOffset:CGSizeMake(0, 1)];
			[onTextLayer setShadowColor:[[NSColor blackColor] CGColor]];
			[onTextLayer setShadowRadius:0.0];
			[onTextLayer setShadowOpacity:0.5];
			
			CGSize preferredSize = [onTextLayer preferredFrameSize];
			[onTextLayer setFrame:CGRectMake(lroundf((((BACKGROUND_SECTION_WIDTH - KNOB_RADIUS) / 2.0) - (preferredSize.width / 2.0)) + (KNOB_RADIUS * 0.25)), 
											  ((BACKGROUND_SECTION_HEIGHT / 2.0) - (preferredSize.height / 2.0)), 
											  preferredSize.width, 
											  preferredSize.height)];
		}
		[onLayer addSublayer:onTextLayer];
		[onLayer setNeedsDisplay];
	}
	[self setOnLayer:onLayer];
	
	CALayer *innerShadowLayer = [[[CALayer alloc] init] autorelease];
	[innerShadowLayer setName:DJSwitchControlLayerInnerShadow];
	[innerShadowLayer setDelegate:self];
	[innerShadowLayer setFrame:[rootLayer frame]];
	[innerShadowLayer setNeedsDisplay];
	
	[rootLayer addSublayer:offLayer];
	[rootLayer addSublayer:onLayer];
	[rootLayer addSublayer:innerShadowLayer];
	[rootLayer addSublayer:knobLayer];
	
	[rootLayer setNeedsDisplay];
	
	[self setLayer:rootLayer];
	[self setWantsLayer:YES];
}

- (void)viewDidMoveToWindow {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidChangeScreen:) name:NSWindowDidChangeScreenNotification object:nil];
}

- (void)windowDidChangeScreen:(NSNotification *)notification {
	[[[self layer] sublayers] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		[CATransaction begin];
		{
			[CATransaction setDisableActions:YES];
			[(CALayer *)obj setContentsScale:[[self window] backingScaleFactor]];
		}
		[CATransaction commit];
	}];
}

- (void)setOn:(BOOL)on {
	_on = on;
	if (on) {
		[self switchToOn];
	} else {
		[self switchToOff];
	}
}

- (void)setActive:(BOOL)active {
	_active = active;
	[[[self layer] sublayers] makeObjectsPerformSelector:@selector(setNeedsDisplay)];
}

- (void)setOnColor:(NSColor *)color {
	// TODO: set this.
}

#pragma mark -
#pragma mark Event Handlers

- (void)mouseDown:(NSEvent *)event {
	
	NSPoint eventPoint = [event locationInWindow];
	NSPoint localPoint = [self convertPoint:eventPoint fromView:nil];
	__block NSInteger mouseOffset = localPoint.x;
	__block NSInteger originalOffset = [[self knobLayer] frame].origin.x;
	
	[self setMouseTrackingBlock:^(NSEvent *currentEvent) {
		
		NSPoint eventPoint = [currentEvent locationInWindow];
		NSPoint localPoint = [self convertPoint:eventPoint fromView:nil];
		NSInteger newOffset = originalOffset + (localPoint.x - mouseOffset);
		
		if ([currentEvent type] == NSLeftMouseDown) {
			[self setActive:YES];
		}
		
		if ([currentEvent type] == NSLeftMouseDragged) {
			[self moveSwitchToNewOffset:newOffset disableAnimations:YES];
		}
		
		if ([currentEvent type] == NSLeftMouseUp) {
			
			if (originalOffset == newOffset) {
				if (originalOffset == 0) {
					[self setOn:YES];
				} else {
					[self setOn:NO];
				}
			} else if (newOffset < ((CONTROL_WIDTH - KNOB_DIAMETER) / 2.0)) {
				[self setOn:NO];
			} else {
				[self setOn:YES];
			}
			
			[self setActive:NO];
			[self setMouseTrackingBlock:nil];
			return;
		}
		
	}];
	[self mouseTrackingBlock](event);
}

- (void)mouseDragged:(NSEvent *)event {
	if ([self mouseTrackingBlock] == nil) return;
	
	[self mouseTrackingBlock](event);
}

- (void)mouseUp:(NSEvent *)event {
	if ([self mouseTrackingBlock] == nil) return;
	
	[self mouseTrackingBlock](event);
}

- (void)switchToOn {
	[self moveSwitchToNewOffset:(CONTROL_WIDTH - KNOB_DIAMETER) disableAnimations:NO];
	[self performAction];
}

- (void)switchToOff {
	[self moveSwitchToNewOffset:0 disableAnimations:NO];
	[self performAction];
}

- (void)performAction {
	[[self target] performSelector:[self action] withObject:self];
}

#pragma mark -
#pragma mark Layer Drawing

- (void)moveSwitchToNewOffset:(NSInteger)newOffset disableAnimations:(BOOL)disableAnimations {
	
	if (newOffset > (CONTROL_WIDTH - KNOB_DIAMETER)) {
		newOffset = (CONTROL_WIDTH - KNOB_DIAMETER);
	}
	
	if (newOffset < 0) {
		newOffset = 0;
	}
	
	CGRect newKnobRect = [[self knobLayer] frame];
	newKnobRect.origin.x = newOffset;
	
	CGRect newOnLayerRect = [[self onLayer] frame];
	newOnLayerRect.origin.x = newOffset + (KNOB_RADIUS - BACKGROUND_SECTION_WIDTH);
	
	CGRect newOffLayerRect = [[self offLayer] frame];
	newOffLayerRect.origin.x = newOffset + KNOB_RADIUS;
	
	[CATransaction begin];
	{
		[CATransaction setAnimationDuration:0.2];
		[CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
		[CATransaction setDisableActions:disableAnimations];
		
		[[self knobLayer] setFrame:newKnobRect];
		[[self onLayer] setFrame:newOnLayerRect];
		[[self offLayer] setFrame:newOffLayerRect];
	}
	[CATransaction commit];
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
	if ([[layer name] isEqual:DJSwitchControlLayerInnerShadow]) {
		[self drawInnerShadowLayer:layer inContext:ctx];
	} else if ([[layer name] isEqual:DJSwitchControlLayerKnob]) {
		[self drawKnobLayer:layer inContext:ctx];
	} else if ([[layer name] isEqual:DJSwitchControlLayerOn]) {
		[self drawOnLayer:layer inContext:ctx];
	} else if ([[layer name] isEqual:DJSwitchControlLayerOff]) {
		[self drawOffLayer:layer inContext:ctx];
	}
}

- (void)drawInnerShadowLayer:(CALayer *)layer inContext:(CGContextRef)context {
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
	
	NSGraphicsContext *g = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:NO];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:g];
    CGContextSaveGState(context);
	
	CGPathRef path = [self newPathForRoundedRect:[layer bounds] radius:(CONTROL_HEIGHT / 2.0)];
	CGContextAddPath(context, path);
    CGContextSetShadowWithColor(context, CGSizeMake(0.0, -2), 5.0, [[NSColor blackColor] CGColor]);
	CGContextSetStrokeColorWithColor(context, [[NSColor blackColor] CGColor]);
	CGContextSetLineWidth(context, 2.0);
	CGContextStrokePath(context);
	CGContextRestoreGState(context);
	
	
	[NSGraphicsContext restoreGraphicsState];
	
	CGColorSpaceRelease(colorSpace);
}

- (void)drawKnobLayer:(CALayer *)layer inContext:(CGContextRef)context {
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
	CGRect knobRect = CGRectInset([[self knobLayer] bounds], 1, 1);
	CGFloat knobRadius = [[self knobLayer] bounds].size.height;
	
	// knob outline (shadow is drawn in the toggle layer)
	CGContextSetStrokeColorWithColor(context, [[NSColor colorWithCalibratedWhite:0.62 alpha:1.0] CGColor]);
	CGContextSetLineWidth(context, 1.5);
	CGContextStrokeEllipseInRect(context, knobRect);
	CGContextSetShadowWithColor(context, CGSizeMake(0, 0), 0, NULL);
	
	// knob inner gradient
	CGContextAddEllipseInRect(context, knobRect);
	CGContextClip(context);
	CGColorRef knobStartColor = [[NSColor colorWithCalibratedWhite:0.82 alpha:1.0] CGColor];
	CGColorRef knobEndColor = ([self isActive]) ? [[NSColor colorWithCalibratedWhite:0.894 alpha:1.0] CGColor] : [[NSColor colorWithCalibratedWhite:0.996 alpha:1.0] CGColor];
	CGPoint topPoint = CGPointMake(0, 0);
	CGPoint bottomPoint = CGPointMake(0, knobRadius + 2);
	CGGradientRef knobGradient = CreateGradientRefWithColors(colorSpace, knobStartColor, knobEndColor);
	CGContextDrawLinearGradient(context, knobGradient, topPoint, bottomPoint, 0);
	CGGradientRelease(knobGradient);
	
	// knob inner highlight
	CGContextAddEllipseInRect(context, CGRectInset(knobRect, 0.5, 0.5));
	CGContextAddEllipseInRect(context, CGRectInset(knobRect, 1.5, 1.5));
	CGContextEOClip(context);
	CGGradientRef knobHighlightGradient = CreateGradientRefWithColors(colorSpace, [[NSColor whiteColor] CGColor], [[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] CGColor]);
	CGContextDrawLinearGradient(context, knobHighlightGradient, topPoint, bottomPoint, 0);
	CGGradientRelease(knobHighlightGradient);
	
	CGColorSpaceRelease(colorSpace);
}

- (void)drawOnLayer:(CALayer *)layer inContext:(CGContextRef)context {
	[self drawHighlightForLayer:layer inContext:context withOpacity:0.4];
}

- (void)drawOffLayer:(CALayer *)layer inContext:(CGContextRef)context {
	[self drawHighlightForLayer:layer inContext:context withOpacity:0.8];
}

- (void)drawHighlightForLayer:(CALayer *)layer inContext:(CGContextRef)context withOpacity:(CGFloat)opacity {
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
	CGRect highlightRect = [layer bounds];
	highlightRect.origin.y = highlightRect.origin.y - (CONTROL_HEIGHT / 2.0);
	
	NSGraphicsContext *g = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:NO];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:g];
	CGContextSaveGState(context);
	
	CGPathRef roundedHighlightPath = [self newPathForRoundedRect:highlightRect radius:(CONTROL_HEIGHT / 2.0)];
	CGContextAddPath(context, roundedHighlightPath);
	CGContextSetFillColorWithColor(context, [[NSColor colorWithCalibratedWhite:1.0 alpha:opacity] CGColor]);
	CGContextFillPath(context);
	
	CGContextRestoreGState(context);
	[NSGraphicsContext restoreGraphicsState];
	
	CGColorSpaceRelease(colorSpace);
}

#pragma mark -
#pragma mark Drawing Helper Methods

- (CGPathRef)newPathForRoundedRect:(CGRect)rect radius:(CGFloat)radius {
	CGMutablePathRef retPath = CGPathCreateMutable();
	
	CGRect innerRect = CGRectInset(rect, radius, radius);
	
	CGFloat inside_right = innerRect.origin.x + innerRect.size.width;
	CGFloat outside_right = rect.origin.x + rect.size.width;
	CGFloat inside_bottom = innerRect.origin.y + innerRect.size.height;
	CGFloat outside_bottom = rect.origin.y + rect.size.height;
	
	CGFloat inside_top = innerRect.origin.y;
	CGFloat outside_top = rect.origin.y;
	CGFloat outside_left = rect.origin.x;
	
	CGPathMoveToPoint(retPath, NULL, innerRect.origin.x, outside_top);
	
	CGPathAddLineToPoint(retPath, NULL, inside_right, outside_top);
	CGPathAddArcToPoint(retPath, NULL, outside_right, outside_top, outside_right, inside_top, radius);
	CGPathAddLineToPoint(retPath, NULL, outside_right, inside_bottom);
	CGPathAddArcToPoint(retPath, NULL,  outside_right, outside_bottom, inside_right, outside_bottom, radius);
	
	CGPathAddLineToPoint(retPath, NULL, innerRect.origin.x, outside_bottom);
	CGPathAddArcToPoint(retPath, NULL,  outside_left, outside_bottom, outside_left, inside_bottom, radius);
	CGPathAddLineToPoint(retPath, NULL, outside_left, inside_top);
	CGPathAddArcToPoint(retPath, NULL,  outside_left, outside_top, innerRect.origin.x, outside_top, radius);
	
	CGPathCloseSubpath(retPath);
	
	return retPath;
}

CGGradientRef CreateGradientRefWithColors(CGColorSpaceRef colorSpace, CGColorRef startColor, CGColorRef endColor) {
	CGFloat colorStops[2] = {0.0, 1.0};
	CGColorRef colors[] = {startColor, endColor};
	CFArrayRef colorsArray = CFArrayCreate(NULL, (const void**)colors, sizeof(colors) / sizeof(CGColorRef), &kCFTypeArrayCallBacks);
	CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colorsArray, colorStops);
	CFRelease(colorsArray);
	return gradient;
}

@end

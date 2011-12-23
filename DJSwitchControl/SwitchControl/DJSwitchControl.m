//
//  DJSwitchControl.m
//  DJSwitchControl
//
//  Created by Dan Palmer on 22/12/2011.
//  Copyright (c) 2011 Dan Palmer. All rights reserved.
//

#import "DJSwitchControl.h"

#import <QuartzCore/QuartzCore.h>

#import "NSColor+CGColor.h"

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

@interface DJSwitchControl ()

@property (retain) CALayer *knobLayer;
@property (retain) CALayer *onLayer;
@property (retain) CALayer *offLayer;
@property (copy) void (^mouseTrackingBlock)(NSEvent *);

- (void)setupLayers;
- (void)switchToOn;
- (void)switchToOff;
- (void)performAction;
- (void)moveSwitchToNewOffset:(NSInteger)newOffset disableAnimations:(BOOL)disableAnimations;

@end

@implementation DJSwitchControl

@synthesize on=_on;
@synthesize target=_target;
@synthesize action=_action;

@synthesize knobLayer=_knobLayer;
@synthesize onLayer=_onLayer;
@synthesize offLayer=_offLayer;
@synthesize mouseTrackingBlock=_mouseTrackingBlock;

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
	
	CALayer *knobLayer = [[[CALayer alloc] init] autorelease];
	{
		[knobLayer setName:DJSwitchControlLayerKnob];
		[knobLayer setFrame:CGRectMake(0, 1, KNOB_DIAMETER, KNOB_DIAMETER)];
		[knobLayer setBackgroundColor:[[NSColor grayColor] CGColor]];
		[knobLayer setCornerRadius:KNOB_CORNER_RADIUS];
		[knobLayer setDelegate:self];
		[knobLayer setNeedsDisplay];
	}
	[self setKnobLayer:knobLayer];
	
	
	CALayer *offLayer = [[[CALayer alloc] init] autorelease];
	{
		[offLayer setName:DJSwitchControlLayerOff];
		[offLayer setFrame:CGRectMake(KNOB_RADIUS, 0, BACKGROUND_SECTION_WIDTH, BACKGROUND_SECTION_HEIGHT)];
		[offLayer setBackgroundColor:[[NSColor whiteColor] CGColor]];
		[offLayer setDelegate:self];
		CATextLayer *offTextLayer = [[[CATextLayer alloc] init] autorelease];
		{
			[offTextLayer setString:@"OFF"];
			[offTextLayer setFontSize:SWITCH_FONT_SIZE];
			[offTextLayer setFont:@"Helvetica Neue Bold"];
			[offTextLayer setForegroundColor:[[NSColor darkGrayColor] CGColor]];
			
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
		[onLayer setBackgroundColor:[[NSColor blueColor] CGColor]];
		[onLayer setDelegate:self];
		CATextLayer *onTextLayer = [[[CATextLayer alloc] init] autorelease];
		{
			[onTextLayer setFrame:CGRectMake(KNOB_RADIUS, 0, BACKGROUND_SECTION_WIDTH - KNOB_RADIUS, BACKGROUND_SECTION_HEIGHT)];
			[onTextLayer setString:@"ON"];
			[onTextLayer setFontSize:SWITCH_FONT_SIZE];
			[onTextLayer setFont:@"Helvetica Neue Bold"];
			[onTextLayer setForegroundColor:[[NSColor whiteColor] CGColor]];
			
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
	
	
	[rootLayer addSublayer:offLayer];
	[rootLayer addSublayer:onLayer];
	[rootLayer addSublayer:knobLayer];
	
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
			// change state to pressed
		}
		
		if ([currentEvent type] == NSLeftMouseDragged) {
			[self moveSwitchToNewOffset:newOffset disableAnimations:YES];
		}
		
		if ([currentEvent type] == NSLeftMouseUp) {
			
			if (originalOffset == newOffset) {
				if (originalOffset == 0) {
					[self switchToOn];
				} else {
					[self switchToOff];
				}
			} else if (newOffset < ((CONTROL_WIDTH - KNOB_DIAMETER) / 2.0)) {
				[self setOn:NO];
			} else {
				[self setOn:YES];
			}
			
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

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
	NSLog(@"Drawing %@", [layer name]);
}

- (void)drawRect:(NSRect)dirtyRect {
	
}

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

@end

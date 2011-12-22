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
@property (copy) void (^mouseTrackingBlock)(NSEvent *);

- (void)setupLayers;
- (void)performAction;
- (void)moveSwitchToNewOffset:(NSInteger)newOffset disableAnimations:(BOOL)disableAnimations;

@end

@implementation DJSwitchControl

@synthesize on=_on;
@synthesize target=_target;
@synthesize action=_action;

@synthesize knobLayer=_knobLayer;
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
		[knobLayer setFrame:CGRectMake(1, 1, KNOB_DIAMETER, KNOB_DIAMETER)];
		[knobLayer setBackgroundColor:[[NSColor grayColor] CGColor]];
		[knobLayer setCornerRadius:KNOB_CORNER_RADIUS];
		[knobLayer setDelegate:self];
		[self setKnobLayer:knobLayer];
	}
	
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
			[offTextLayer setFrame:CGRectMake(lroundf((((BACKGROUND_SECTION_WIDTH - KNOB_RADIUS) / 2.0) - (preferredSize.width / 2.0)) + KNOB_RADIUS), 
											  ((BACKGROUND_SECTION_HEIGHT / 2.0) - (preferredSize.height / 2.0)), 
											  preferredSize.width, 
											  preferredSize.height)];
		}
		[offLayer addSublayer:offTextLayer];
	}
	
	CALayer *onLayer = [[[CALayer alloc] init] autorelease];
	{
		[onLayer setName:DJSwitchControlLayerOn];
		[onLayer setFrame:CGRectMake((KNOB_RADIUS-BACKGROUND_SECTION_WIDTH), 0, BACKGROUND_SECTION_WIDTH, BACKGROUND_SECTION_HEIGHT)];
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
			[onTextLayer setFrame:CGRectMake(lroundf((((BACKGROUND_SECTION_WIDTH - KNOB_RADIUS) / 2.0) - (preferredSize.width / 2.0)) + KNOB_RADIUS), 
											  ((BACKGROUND_SECTION_HEIGHT / 2.0) - (preferredSize.height / 2.0)), 
											  preferredSize.width, 
											  preferredSize.height)];
		}
		[onLayer addSublayer:onTextLayer];
	}
	
	
	[rootLayer addSublayer:offLayer];
	[rootLayer addSublayer:onLayer];
	[rootLayer addSublayer:knobLayer];
	
	[self setLayer:rootLayer];
	[self setWantsLayer:YES];
}

#pragma mark -
#pragma mark Event Handlers

- (void)mouseDown:(NSEvent *)event {
	
	__block NSInteger originalOffset = [[self knobLayer] frame].origin.x;
	[self setMouseTrackingBlock:^(NSEvent *currentEvent) {
		
		NSInteger newOffset = [[self knobLayer] frame].origin.x + [currentEvent deltaX];
		
		if ([currentEvent type] == NSLeftMouseDown) {
			//[self moveSwitchToNewOffset:newOffset disableAnimations:NO];
		}
		
		if ([currentEvent type] == NSLeftMouseDragged) {
			[self moveSwitchToNewOffset:newOffset disableAnimations:YES];
		}
		
		if ([currentEvent type] == NSLeftMouseUp) {
			[self moveSwitchToNewOffset:newOffset disableAnimations:NO];
			
			if (labs(originalOffset - newOffset) > (CONTROL_WIDTH / 2)) {
				// the knob has moved more than half way, snap it.
				NSLog(@"%ld", (originalOffset - newOffset));
			}
			
			[self setMouseTrackingBlock:nil];
			return;
		}
		
	}];
	[self mouseTrackingBlock](event);
}

- (void)mouseDragged:(NSEvent *)event {
	if ([self mouseTrackingBlock] == nil) {
		return;
	}
	
	[self mouseTrackingBlock](event);
}

- (void)mouseUp:(NSEvent *)event {
	if ([self mouseTrackingBlock] == nil) {
		return;
	}
	
	[self mouseTrackingBlock](event);
}

- (void)performAction {
	[[self target] performSelector:[self action] withObject:self];
}

#pragma mark -
#pragma mark Layer Drawing

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
	NSLog(@"Drawing %@", [layer name]);
}

- (void)moveSwitchToNewOffset:(NSInteger)newOffset disableAnimations:(BOOL)disableAnimations {
	
	CGRect newRect = [[self knobLayer] frame];
	newRect.origin.x = newOffset;
	
	[CATransaction begin];
	{
		[CATransaction setDisableActions:disableAnimations];
		[[self knobLayer] setFrame:newRect];
	}
	[CATransaction commit];
}

@end
//
//  NSColor+CGColor.m
//  DJSwitchControl
//
//  Created by Dan Palmer on 22/12/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "NSColor+CGColor.h"

#import <QuartzCore/QuartzCore.h>

@implementation NSColor (CGColor)

- (CGColorRef)CGColor {
	CGColorSpaceRef colorSpace = [[self colorSpace] CGColorSpace];
	NSInteger componentCount = [self numberOfComponents];
	CGFloat *components = (CGFloat *)calloc(componentCount, sizeof(CGFloat));
	[self getComponents:components];
	CGColorRef color = CGColorCreate(colorSpace, components);
	free((void*)components);
	return color;
}

@end

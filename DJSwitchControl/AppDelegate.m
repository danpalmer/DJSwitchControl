//
//  AppDelegate.m
//  DJSwitchControl
//
//  Created by Dan Palmer on 22/12/2011.
//  Copyright (c) 2011 Dan Palmer. All rights reserved.
//

#import "AppDelegate.h"

#import "SwitchControl/DJSwitchControl.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize label=_label;
@synthesize switchControl=_switchControl;

- (void)dealloc
{
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[[self switchControl] setTarget:self];
	[[self switchControl] setAction:@selector(switchChanged:)];
}

- (IBAction)switchChanged:(id)sender {
	
	if ([(DJSwitchControl *)sender isOn]) {
		[[self label] setStringValue:@"On"];
	} else {
		[[self label] setStringValue:@"Off"];
	}
}

@end

//
//  AppDelegate.h
//  DJSwitchControl
//
//  Created by Dan Palmer on 22/12/2011.
//  Copyright (c) 2011 Dan Palmer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "DJSwitchControl.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (retain) IBOutlet NSTextField *label;

@property (retain) IBOutlet DJSwitchControl *switchControl;

@end

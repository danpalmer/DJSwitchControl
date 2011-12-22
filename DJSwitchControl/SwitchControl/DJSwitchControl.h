//
//  DJSwitchControl.h
//  DJSwitchControl
//
//  Created by Dan Palmer on 22/12/2011.
//  Copyright (c) 2011 Dan Palmer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DJSwitchControl : NSView

@property (assign, getter = isOn) BOOL on;
@property (assign) __weak id target;
@property (assign) SEL action;

@end

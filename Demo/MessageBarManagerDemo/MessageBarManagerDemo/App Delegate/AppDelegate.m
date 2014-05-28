//
//  AppDelegate.m
//  MessageBarManagerDemo
//
//  Created by Terry Worona on 5/13/13.
//  Copyright (c) 2013 Terry Worona. All rights reserved.
//

#import "AppDelegate.h"

// Controllers
#import "TWMesssageBarDemoController.h"

// Strings
NSString * const kAppDelegateDemoStyleSheetImageIconError = @"icon-error.png";
NSString * const kAppDelegateDemoStyleSheetImageIconSuccess = @"icon-success.png";
NSString * const kAppDelegateDemoStyleSheetImageIconInfo = @"icon-info.png";

@interface TWAppDelegateDemoStyleSheet : NSObject <TWMessageBarStyleSheet>

+ (TWAppDelegateDemoStyleSheet *)styleSheet;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // default style sheet
    self.window.rootViewController = [[TWMesssageBarDemoController alloc] init];
    
    /*
     * Uncomment for custom style sheet (disabled)
     */
    // self.window.rootViewController = [[TWMesssageBarDemoController alloc] initWithStyleSheet:[TWAppDelegateDemoStyleSheet styleSheet]];
    
    /*
     * Uncomment for hidden status bar (testing purposes)
     */
    // [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    [self.window makeKeyAndVisible];
    return YES;
}

@end

@implementation TWAppDelegateDemoStyleSheet

#pragma mark - Alloc/Init

+ (TWAppDelegateDemoStyleSheet *)styleSheet
{
    return [[TWAppDelegateDemoStyleSheet alloc] init];
}

#pragma mark - TWMessageBarStyleSheet

- (UIColor *)backgroundColorForMessageType:(TWMessageBarMessageType)type
{
    UIColor *backgroundColor = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.75];
            break;
        case TWMessageBarMessageTypeSuccess:
            backgroundColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:0.75];
            break;
        case TWMessageBarMessageTypeInfo:
            backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:1.0 alpha:0.75];
            break;
        default:
            break;
    }
    return backgroundColor;
}

- (UIColor *)strokeColorForMessageType:(TWMessageBarMessageType)type
{
    UIColor *strokeColor = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            strokeColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:1.0];
            break;
        case TWMessageBarMessageTypeSuccess:
            strokeColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:1.0];
            break;
        case TWMessageBarMessageTypeInfo:
            strokeColor = [UIColor colorWithRed:0.0 green:0.0 blue:1.0 alpha:1.0];
            break;
        default:
            break;
    }
    return strokeColor;
}

- (UIImage *)iconImageForMessageType:(TWMessageBarMessageType)type
{
    UIImage *iconImage = nil;
    switch (type)
    {
        case TWMessageBarMessageTypeError:
            iconImage = [UIImage imageNamed:kAppDelegateDemoStyleSheetImageIconError];
            break;
        case TWMessageBarMessageTypeSuccess:
            iconImage = [UIImage imageNamed:kAppDelegateDemoStyleSheetImageIconSuccess];
            break;
        case TWMessageBarMessageTypeInfo:
            iconImage = [UIImage imageNamed:kAppDelegateDemoStyleSheetImageIconInfo];
            break;
        default:
            break;
    }
    return iconImage;
}

-(UIFont*) messageTitleFontForMessageType:(TWMessageBarMessageType)type
{
	return [UIFont fontWithName:@"AvenirNext-DemiBold" size:16.0f];
}

-(UIFont*) messageDescriptionFontForMessageType:(TWMessageBarMessageType)type
{
	return [UIFont fontWithName:@"AvenirNext-Regular" size:14.0f];
}

@end

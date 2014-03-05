//
//  CSMAppDelegate.m
//  iBeacons_Demo
//
//  Created by Christopher Mann on 9/5/13.
//  Copyright (c) 2013 Christopher Mann. All rights reserved.
//

#import "CSMAppDelegate.h"

#define kMyStoreNumber 1
#define kWeeklySpecialItemNumber 1


@implementation CSMAppDelegate

+ (CSMAppDelegate*)appDelegate {
    return (CSMAppDelegate*)[UIApplication sharedApplication].delegate;
}

- (NSUUID*)myUUID {
    if (!_myUUID) {
        // generate unique identifier
        //_myUUID = [[NSUUID alloc] initWithUUIDString:@"68656c6c-6f20-776f-726c-640000000000"];
        /*Amit testing auto create uuid based on text NSString * testUUID = @"hello world";
        NSData *data = [testUUID dataUsingEncoding:NSUTF8StringEncoding];
        
        NSMutableData *ndata = [[NSMutableData alloc] initWithCapacity : 16 ];
        [ndata appendData: data];
        [ndata increaseLengthBy: 16-data.length];
        uint8_t *rawBytes = [ndata bytes];
        NSUUID * temp = [[NSUUID alloc] initWithUUIDBytes: rawBytes];*/
        _myUUID = [[NSUUID alloc] initWithUUIDString:@"E20A39F4-73F5-4BC4-A12F-17D1AD07A961"];
        //_myUUID = [[NSUUID alloc] initWithUUIDString:@"10D39AE7-020E-4467-9CB2-DD36366F899D"];
    }
    return _myUUID;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.rootViewController = [[CSMRootViewController alloc] init];
    
    // define navbar appearance
    [[UINavigationBar appearance] setBarTintColor:kAppTintColor];
    [[UINavigationBar appearance] setTintColor:[UIColor blackColor]];
    [[UINavigationBar appearance] setBarStyle:UIBarStyleBlack];
    
    // set status bar style
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = self.rootViewController;
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.tintColor = kAppTintColor;
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end

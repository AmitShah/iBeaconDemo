//
//  CSMLocationManager.m
//  iBeacons_Demo
//
//  Created by Christopher Mann on 9/5/13.
//  Copyright (c) 2013 Christopher Mann. All rights reserved.
//

#import "CSMLocationManager.h"
#import "CSMLocationUpdateController.h"
#import "CSMAppDelegate.h"
#import "CSMBeaconRegion.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreMotion/CoreMotion.h>

#define kLocationUpdateNotification @"updateNotification"
#define kBackgroundUpdateNotification @"backgroundUpdate"

@interface CSMLocationManager () <CBPeripheralManagerDelegate>

@property (nonatomic, strong) CLLocationManager     *locationManager;
@property (nonatomic, strong) CBPeripheralManager   *peripheralManager;
@property (nonatomic, strong) NSDictionary          *peripheralData;
@property (nonatomic, assign) BOOL                  isMonitoringRegion;
@property (nonatomic, assign) BOOL                  didShowEntranceNotifier;
@property (nonatomic, assign) BOOL                  didShowExitNotifier;
@property (strong, nonatomic) CMMotionManager       *motionManager;

@end

static CSMLocationManager *_sharedInstance = nil;


@implementation CSMLocationManager

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[CSMLocationManager alloc] init];
    });
    return _sharedInstance;
}


#pragma mark - Peripheral Manager Helpers

- (void)initializePeripheralManager {
    // initialize new peripheral manager and begin monitoring for updates
    if (!self.peripheralManager) {
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
        
        // fire initial notification
        [self fireUpdateNotificationForStatus:@"Initializing CBPeripheralManager and waiting for state updates..."];
    }
}

- (void)initializeMotionManager{
    if(!self.motionManager){
        self.motionManager = [[CMMotionManager alloc] init];
        self.motionManager.accelerometerUpdateInterval = .1;
        self.motionManager.gyroUpdateInterval = .1;
        self.motionManager.deviceMotionUpdateInterval = 1;
        
        [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue]
                                                 withHandler:^(CMAccelerometerData  *accelerometerData, NSError *error) {
                                                     [self outputAccelertionData:accelerometerData];
                                                     if(error){
                                                         
                                                         NSLog(@"%@", error);
                                                     }
                                                 }];
        
        [self.motionManager startGyroUpdatesToQueue:[NSOperationQueue currentQueue]
                                        withHandler:^(CMGyroData *gyroData, NSError *error) {
                                            [self outputRotationData:gyroData];
                                        }];
        
        [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue]
                                         withHandler:^(CMDeviceMotion *motion, NSError *error){
                                             [self outputDeviceMotionData:motion];
                                         }];
    }
}

//Amit wrote this function
- (void)startAdvertisingBeacon :(NSString *)data {
    // initialize new CLBeaconRegion and start advertising target region
    NSData *d = [data dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableData *ndata = [[NSMutableData alloc] initWithCapacity : 16 ];
    [ndata appendData: d];
    [ndata increaseLengthBy: 16-d.length];
    uint8_t *rawBytes = [ndata bytes];
    NSUUID * temp = [[NSUUID alloc] initWithUUIDBytes: rawBytes];
    CLBeaconRegion * beacon = [[CLBeaconRegion alloc] initWithProximityUUID:temp
                                                                      major:1
                                                                      minor: 0
                                                                 identifier:@"stadium.io"];
    
    if (self.peripheralManager.state == CBPeripheralManagerStatePoweredOn && ![self.peripheralManager isAdvertising]) {
        self.peripheralData =[beacon peripheralDataWithMeasuredPower:nil];
        [self.peripheralManager startAdvertising:self.peripheralData];
        //Amit Test if we can after a very arbritrary time stop beaconing
        NSTimer * timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(stopBeacon) userInfo:nil repeats:NO];
    }
}

- (void) stopBeacon{
    if([self.peripheralManager isAdvertising]){
        [self.peripheralManager stopAdvertising];
    }
}
- (void)startAdvertisingBeacon {
    // initialize new CLBeaconRegion and start advertising target region
    if (![self.peripheralManager isAdvertising]) {
        self.peripheralData = [[CSMBeaconRegion targetRegion] peripheralDataWithMeasuredPower:nil];
        [self.peripheralManager startAdvertising:self.peripheralData];
        //Amit Test if we can after a very arbritrary time stop beaconing
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(stopAdvertisingBeacon) userInfo:nil repeats:NO];
    }
}

- (void)stopAdvertisingBeacon {
    // stop advertising CLBeaconRegion
    if ([self.peripheralManager isAdvertising]) {
        [self.peripheralManager stopAdvertising];
        self.peripheralManager = nil;
        self.peripheralData = nil;
    }
}

- (void)startBeaconRanging {
    
    // set entrance notifier flag
    self.didShowEntranceNotifier = YES;
    
    // start beacon ranging
    [self.locationManager startRangingBeaconsInRegion:[CSMBeaconRegion targetRegion]];
    
    // fire notification with region update
    [self fireUpdateNotificationForStatus:@"Welcome!  You have entered the target region."];
}

- (void)fireUpdateNotificationForStatus:(NSString*)status {
    // fire notification to update displayed status
    [[NSNotificationCenter defaultCenter] postNotificationName:kLocationUpdateNotification
                                                        object:Nil
                                                      userInfo:@{@"status" : status}];
}

- (void) fireUpdateNotificationForBackground:(UIColor *)color {
    [[NSNotificationCenter defaultCenter] postNotificationName:kBackgroundUpdateNotification
                                                        object:Nil
                                                      userInfo:@{@"color" : color}];
}

/*TODO - (void) fireUpdateNotificationForMotion:(UIColor *)color {
    [[NSNotificationCenter defaultCenter] postNotificationName:kMotionUpdateNotification
                                                        object:Nil
                                                      userInfo:@{@"color" : color}];
}*/

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    
    NSString *status;
    switch (peripheral.state) {
        case CBPeripheralManagerStateUnsupported:
            // ensure you are using a device supporting Bluetooth 4.0 or above.
            // not supported on iOS 7 simulator
            status = @"Device platform does not support BTLE peripheral role.";
            break;
            
        case CBPeripheralManagerStateUnauthorized:
            // verify app is permitted to use Bluetooth
            status = @"App is not authorized to use BTLE peripheral role.";
            break;
            
        case CBPeripheralManagerStatePoweredOff:
            // Bluetooth service is powered off
            status = @"Bluetooth service is currently powered off on this device.";
            break;
            
        case CBPeripheralManagerStatePoweredOn:
            // start advertising CLBeaconRegion
            status = @"Now advertising iBeacon signal.  Monitor other device for location updates.";
            //Amit Disable this for now
            //[self startAdvertisingBeacon];
            break;
            
        case CBPeripheralManagerStateResetting:
            // Temporarily lost connection
            status = @"Bluetooth connection was lost.  Waiting for update...";
            break;
            
        case CBPeripheralManagerStateUnknown:
        default:
            // Connection status unknown
            status = @"Current peripheral state unknown.  Waiting for update...";
            break;
    }
    
    // fire notification with status update
    [self fireUpdateNotificationForStatus:status];
}


#pragma mark - CLLocationManager Helpers

- (void)initializeRegionMonitoring {
    
    // initialize new location manager
    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    }
    
    if ([CSMAppDelegate appDelegate].applicationMode == CSMApplicationModeRegionMonitoring) {
        
        // begin region monitoring
        [self.locationManager startMonitoringForRegion:[CSMBeaconRegion targetRegion]];
        [self startBeaconRanging]; //Amit
        
        // fire notification with initial status
        [self fireUpdateNotificationForStatus:@"Initializing CLLocationManager and initiating region monitoring..."];
    }
}

- (void)monitorForRegions {
    // initialize new location manager
    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    }
    
    [self.locationManager startMonitoringForRegion:[CSMBeaconRegion targetRegion]];
    
        // fire notification with initial status
    [self fireUpdateNotificationForStatus:@"Initializing CLLocationManager and initiating region monitoring..."];
    

}

- (void)stopMonitoringForRegion:(CLBeaconRegion*)region {
    // stop monitoring for region
    [self.locationManager stopMonitoringForRegion:region];

    self.locationManager = nil;
    
    // reset notifiers
    self.didShowEntranceNotifier = NO;
    self.didShowExitNotifier = NO;
}


#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    
    // fire notification with failure status
    [self fireUpdateNotificationForStatus:[NSString stringWithFormat:@"Location manager failed with error: %@",error.localizedDescription]];
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.fireDate = Nil;
    notification.alertBody = @"State changed";
    notification.soundName = UILocalNotificationDefaultSoundName;
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];

    // handle notifyEntryStateOnDisplay
    // notify user they have entered the region, if you haven't already
    if (manager == self.locationManager &&
        [region.identifier isEqualToString:kUniqueRegionIdentifier] &&
        state == CLRegionStateInside &&
        !self.didShowEntranceNotifier) {
        
        // start beacon ranging
        [self startBeaconRanging];
    }
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    NSLog(@"Notification fired");
}

/*
 this is callback is called in background + sleepmode
 */

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    
    // handle notifyOnEntry
    // notify user they have entered the region, if you haven't already
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = @"Enter";
    notification.fireDate = Nil;
    notification.soundName = UILocalNotificationDefaultSoundName;
    
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
    
    if (manager == self.locationManager &&
        [region.identifier isEqualToString:kUniqueRegionIdentifier] &&
        !self.didShowEntranceNotifier) {
        
        // start beacon ranging
        [self startBeaconRanging];
    }
}
/*
 this is callback is called in background + sleepmode
 */
 
- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    
    // notify user they have entered the region, if you haven't already
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = @"Exit";
    notification.fireDate = Nil;
    notification.soundName = UILocalNotificationDefaultSoundName;
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
    // optionally notify user they have left the region
    if (!self.didShowExitNotifier) {
        
        self.didShowExitNotifier = YES;
        
        // fire notification with region update
        [self fireUpdateNotificationForStatus:@"Thanks for visiting.  You have now left the target region."];
    }
    
    // reset entrance notifier
    self.didShowEntranceNotifier = NO;
    
    // stop beacon ranging
    [manager stopRangingBeaconsInRegion:[CSMBeaconRegion targetRegion]];
}
/*
 this function only called in foreground
 */
- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    
    /*UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.fireDate = Nil;
    notification.alertBody = @"Ranged beacons found";
    notification.soundName = UILocalNotificationDefaultSoundName;
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
     */
    
    // identify closest beacon in range
    if ([beacons count] > 0) {
        NSString *dateString = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                              dateStyle:NSDateFormatterShortStyle
                                                              timeStyle:NSDateFormatterFullStyle];
        CLBeacon *closestBeacon = beacons[0];
        
        if (closestBeacon.proximity == CLProximityImmediate) {
            /**
             Provide proximity based information to user.  You may choose to do this repeatedly
             or only once depending on the use case.  Optionally use major, minor values here to provide beacon-specific content
             */
            // notify user they have entered the region, if you haven't already
            //closestBeacon.major  closestBeacon.minor;
            
            [self fireUpdateNotificationForBackground: [UIColor redColor] ];
            [self fireUpdateNotificationForStatus:[@"You are in the immediate vicinity of the Beacon." stringByAppendingString:dateString]];
            
            
        } else if (closestBeacon.proximity == CLProximityNear) {
            // detect other nearby beacons
            // optionally hide previously displayed proximity based information
            // notify user they have entered the region, if you haven't already
            [self fireUpdateNotificationForBackground: [UIColor yellowColor] ];
            [self fireUpdateNotificationForStatus:[@"There are Beacons nearby." stringByAppendingString:dateString]];
        } else if (closestBeacon.proximity == CLProximityFar){
            [self fireUpdateNotificationForBackground: [UIColor grayColor] ];
            [self fireUpdateNotificationForStatus:[@"There are Beacons Far." stringByAppendingString:dateString]];
            
        }
    } else {
        // no beacons in range - signal may have been lost
        // optionally hide previously displayed proximity based information
        [self fireUpdateNotificationForBackground: [UIColor whiteColor] ];
        [self fireUpdateNotificationForStatus:@"There are currently no Beacons within range."];
    }
}

- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error {

    // fire notification of range failure
    [self fireUpdateNotificationForStatus:[NSString stringWithFormat:@"Beacon ranging failed with error: %@", error]];
    
    // assume notifications failed, reset indicators
    self.didShowEntranceNotifier = NO;
    self.didShowExitNotifier = NO;
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    
    // fire notification of region monitoring
    [self fireUpdateNotificationForStatus:[NSString stringWithFormat:@"Now monitoring for region: %@",((CLBeaconRegion*)region).identifier]];
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {

    // fire notification with status update
    [self fireUpdateNotificationForStatus:[NSString stringWithFormat:@"Region monitoring failed with error: %@", error]];
    
    // assume notifications failed, reset indicators
    self.didShowEntranceNotifier = NO;
    self.didShowExitNotifier = NO;
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    
    // current location usage is required to use this demo app
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        [[[UIAlertView alloc] initWithTitle:@"Current Location Required"
                                    message:@"Please re-enable Core Location to run this Demo.  The app will now exit."
                                   delegate:self
                          cancelButtonTitle:nil
                          otherButtonTitles:@"OK", nil] show];
    }
}

//motion sensor delegates

-(void)outputAccelertionData:(CMAccelerometerData *)acceleration
{
    // fire notification with status update
    //[self fireUpdateNotificationForStatus:[NSString stringWithFormat:@"Accelertion"]];
}
-(void)outputRotationData:(CMGyroData *)rotation
{
    // fire notification with status update
    //[self fireUpdateNotificationForStatus:[NSString stringWithFormat:@"Rotation"]];
    
}
-(void)outputDeviceMotionData:(CMDeviceMotion *)motion
{
    // fire notification with status update
    
    double calculateGs = sqrt(pow(motion.userAcceleration.x,2) + pow(motion.userAcceleration.y, 2) + pow(motion.userAcceleration.z,2));
    if(calculateGs > 2){
        [self startAdvertisingBeacon:[NSString stringWithFormat:@"%g", calculateGs ]];
    }
    [self fireUpdateNotificationForStatus:[NSString stringWithFormat:@"%g", calculateGs ]];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    // exit application if user declined Current Location permissions
    exit(0);
}

@end

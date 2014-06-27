//
//  CSMLocationManager.h
//  iBeacons_Demo
//
//  Created by Christopher Mann on 9/5/13.
//  Copyright (c) 2013 Christopher Mann. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>


@interface CSMLocationManager : NSObject<CLLocationManagerDelegate>

+ (instancetype)sharedManager;

- (void)initializePeripheralManager;

- (void)initializeMotionManager;

- (void)initializeRegionMonitoring;

- (void)monitorForRegions;

- (void)stopMonitoringForRegion:(CLBeaconRegion*)region;

- (void)stopAdvertisingBeacon;

- (void)startAdvertisingBeacon:(NSString*) data;

- (void)outputAccelertionData:(CMAccelerometerData *)acceleration;

- (void)outputRotationData:(CMGyroData *)rotation;

- (void)updateSelectedSide:(NSString *) side;

@end

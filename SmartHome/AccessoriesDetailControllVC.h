//
//  AccessoriesDetailControllVC.h
//  SmartHome
//
//  Created by olami on 2017/5/12.
//  Copyright © 2017年 VIA Technologies, Inc. & OLAMI Team. All rights reserved.
//

#import "ViewController.h"
#import <HomeKit/HomeKit.h>

@interface AccessoriesDetailControllVC : ViewController
@property (strong, nonatomic) HMAccessory *accessory;
@end

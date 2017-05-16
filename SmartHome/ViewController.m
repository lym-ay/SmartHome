//
//  ViewController.m
//  SmartHome
//
//  Created by olami on 2017/5/11.
//  Copyright © 2017年 VIA Technologies, Inc. & OLAMI Team. All rights reserved.
//

#import "ViewController.h"
#import <HomeKit/HomeKit.h>
#import "AccessoriesDetailControllVC.h"

@interface ViewController () <HMHomeManagerDelegate, HMHomeDelegate, HMAccessoryDelegate,
                                UITableViewDelegate,UITableViewDataSource>


@property (weak, nonatomic) IBOutlet UILabel *currentHomeLabel;
@property (nonatomic, strong) HMHomeManager *homeManager;
@property (nonatomic, strong) HMHome *currentHome;
@property (nonatomic, strong) NSMutableArray *accessories;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self setupData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.accessories = [NSMutableArray array];
    
    if (self.homeManager && self.homeManager.primaryHome) {
        for (HMAccessory *accessory in self.homeManager.primaryHome.accessories) {
            [self.accessories insertObject:accessory atIndex:0];
            accessory.delegate = self;
            [self.tableView reloadData];
        }
    }
    
    _currentHomeLabel.text = @"当前Home：";
}

-(void)setupData {
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.bounces = NO;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    self.homeManager = [[HMHomeManager alloc] init];
    self.homeManager.delegate = self;

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (IBAction)addHomeBtnClicked:(id)sender {
    UIAlertController *inputNameAlter = [UIAlertController alertControllerWithTitle:@"请输入新home的名字" message:@"请确保这个名字的唯一性" preferredStyle:UIAlertControllerStyleAlert];
    [inputNameAlter addTextFieldWithConfigurationHandler:^(UITextField *textField){
        textField.placeholder = @"请输入新家的名字";
    }];
    UIAlertAction *action1 = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
    }];
    __weak ViewController *weakSelf = self;
    UIAlertAction *action2 = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *newName = inputNameAlter.textFields.firstObject.text;
        [weakSelf.homeManager addHomeWithName:newName completionHandler:^(HMHome * _Nullable home, NSError * _Nullable error) {
            
        }];
    }];
    [inputNameAlter addAction:action1];
    [inputNameAlter addAction:action2];
    [self presentViewController:inputNameAlter animated:YES completion:^{}];

}

- (IBAction)removeHomeBtnClicked:(id)sender {
    if (_currentHome) {
        [self.homeManager removeHome:_currentHome completionHandler:^(NSError * _Nullable error) {
            if (!error) {
                NSLog(@"删除home成功！");
            }
        }];
    }

}

- (NSMutableArray *)accessories {
    if (_accessories == nil) {
        _accessories = [NSMutableArray array];
    }
    
    return _accessories;
}

- (void)updateCurrentHomeInfo {
    _currentHomeLabel.text = [NSString stringWithFormat:@"current home：%@", _currentHome.name];
    
    _currentHome.delegate = self;
    
    self.accessories = nil;
    for (HMAccessory *accessory in _currentHome.accessories) {
        [self.accessories addObject:accessory];
        accessory.delegate = self;
    }
    
    [self.tableView reloadData];
}


#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.accessories.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    HMAccessory *accessory = self.accessories[indexPath.row];
    cell.textLabel.text = accessory.name;
    if (accessory.reachable) {
        cell.detailTextLabel.text = @"可用";
        cell.detailTextLabel.textColor = [UIColor colorWithRed:46.0/255.0 green:108.0/255.0 blue:73.0/255.0 alpha:1.0];
    } else {
        cell.detailTextLabel.text = @"不可用";
        cell.detailTextLabel.textColor = [UIColor redColor];
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //[tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    UIStoryboard *mainStoryBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    AccessoriesDetailControllVC *accessoriesVC = [mainStoryBoard instantiateViewControllerWithIdentifier:@"AccessoryDetail"];
    
    accessoriesVC.accessory = self.accessories[indexPath.row];
    [self presentViewController:accessoriesVC animated:YES completion:nil];
}


#pragma mark - HMHomeManagerDelegate

// 你的应用程序要重新加载所有的数据
- (void)homeManagerDidUpdateHomes:(HMHomeManager *)manager {
    
    if (manager.primaryHome) {
        _currentHome = self.homeManager.primaryHome;
        [self updateCurrentHomeInfo];
    } else {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"no home" message:@"" preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)homeManager:(HMHomeManager *)manager didAddHome:(HMHome *)home {
    
}


- (void)homeManager:(HMHomeManager *)manager didRemoveHome:(HMHome *)home {
    
}

- (void)homeManagerDidUpdatePrimaryHome:(HMHomeManager *)manager {
    _currentHome = self.homeManager.primaryHome;
    [self updateCurrentHomeInfo];
}

#pragma mark - HMHomeDelegate

- (void)home:(HMHome *)home didAddAccessory:(HMAccessory *)accessory {
    
    for (HMAccessory *accessory in _currentHome.accessories) {
        [self.accessories addObject:accessory];
        accessory.delegate = self;
        [self.tableView reloadData];
    }
}

- (void)home:(HMHome *)home didRemoveAccessory:(HMAccessory *)accessory {
    
    if ([self.accessories containsObject:accessory]) {
        NSUInteger index = [self.accessories indexOfObject:accessory];
        [self.accessories removeObjectAtIndex:index];
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)home:(HMHome *)home didUpdateRoom:(HMRoom *)room forAccessory:(HMAccessory *)accessory {
    
}

#pragma mark - HMAccessoryDelegate

- (void)accessoryDidUpdateReachability:(HMAccessory *)accessory {
    if ([self.accessories containsObject:accessory]) {
        NSUInteger index = [self.accessories indexOfObject:accessory];
        
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
        
        if (accessory.reachable) {
            cell.detailTextLabel.text = @"可用";
            cell.detailTextLabel.textColor = [UIColor colorWithRed:46.0/255.0 green:108.0/255.0 blue:73.0/255.0 alpha:1.0];
        } else {
            cell.detailTextLabel.text = @"不可用";
            cell.detailTextLabel.textColor = [UIColor redColor];
        }
    }
}

- (void)accessory:(HMAccessory *)accessory service:(HMService *)service didUpdateValueForCharacteristic:(HMCharacteristic *)characteristic
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"characteristicValueChanged" object:nil userInfo:@{@"accessory": accessory,
                                                                                                                   @"service": service,
                                                                                                                   @"characteristic": characteristic}];
}

- (void)accessoryDidUpdateServices:(HMAccessory *)accessory {
    
}





@end

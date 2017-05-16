//
//  AccessoriesDetailControllVC.m
//  SmartHome
//
//  Created by olami on 2017/5/12.
//  Copyright © 2017年 VIA Technologies, Inc. & OLAMI Team. All rights reserved.
//

#import "AccessoriesDetailControllVC.h"
#import "OlamiRecognizer.h"

#define OLACUSID   @"73D424AD-A85D-8163-52BB-F7515BFC3CBF"

@interface AccessoriesDetailControllVC ()<UITableViewDelegate,UITableViewDataSource,
OlamiRecognizerDelegate,UITextViewDelegate> {
    OlamiRecognizer *olamiRecognizer;
}

@property (weak, nonatomic) IBOutlet UIButton *recordBtn;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UILabel *accessoryName;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSMutableDictionary *slotDic;     //保存slot的值
@property (weak, nonatomic) IBOutlet UITextView *asrTextView;//用来显示ASRs识别的语句
@property (nonatomic, strong) NSMutableDictionary *serviceDic;//用来保存当前服务的key==服务名 value=service对象指针


@end

@implementation AccessoriesDetailControllVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupInitData];
    [self setupUI];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)setupInitData{
    _serviceDic = [[NSMutableDictionary alloc] init];
    
    _accessoryName.text = self.accessory.name;
    for(HMService *service in _accessory.services) {
        [_serviceDic setObject:service forKey:service.name];
        NSLog(@"service.name is %@",service.name);
    }
    
    
    olamiRecognizer= [[OlamiRecognizer alloc] init];
    olamiRecognizer.delegate = self;
    [olamiRecognizer setAuthorization:@"6b744b8419484ed6aef8bffbde738fab"
                                  api:@"asr" appSecret:@"428a1b659f244e8ab27f81e681182bd5" cusid:OLACUSID];
    
    [olamiRecognizer setLocalization:LANGUAGE_SIMPLIFIED_CHINESE];//设置语系，这个必须在录音使用之前初始化
}

- (void)setupUI {
    [_progressView setProgress:0.2];
    _recordBtn.layer.borderColor = [UIColor grayColor].CGColor;
    _recordBtn.layer.borderWidth = 1;
    _recordBtn.layer.cornerRadius = _recordBtn.frame.size.width/2;
    _recordBtn.layer.masksToBounds = YES;
    
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.bounces = NO;
    //_tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (IBAction)backButtonAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)recordAction:(id)sender {
    [olamiRecognizer setInputType:0];
    if (olamiRecognizer.isRecording) {
        [olamiRecognizer stop];
        [_recordBtn setTitle:@"开始录音" forState:UIControlStateNormal];
        
    }else{
        [olamiRecognizer start];
        [_recordBtn setTitle:@"结束录音" forState:UIControlStateNormal];
    }

}

#pragma mark--NLU delegate
- (void)onUpdateVolume:(float)volume {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.progressView setProgress:(volume/100) animated:YES];
    });
}

- (void)onResult:(NSData *)result {
    NSError *error;
    __weak typeof(self) weakSelf = self;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:result
                                                        options:NSJSONReadingMutableContainers
                                                          error:&error];
    if (error) {
        NSLog(@"error is %@",error.localizedDescription);
    }else{
        NSString *jsonStr=[[NSString alloc]initWithData:result
                                               encoding:NSUTF8StringEncoding];
        NSLog(@"jsonStr is %@",jsonStr);
        NSString *ok = [dic objectForKey:@"status"];
        if ([ok isEqualToString:@"ok"]) {
            NSDictionary *dicData = [dic objectForKey:@"data"];
            NSDictionary *asr = [dicData objectForKey:@"asr"];
            if (asr) {//如果asr不为空，说明目前是语音输入
                [weakSelf processASR:asr];
            }
            NSDictionary *nli = [[dicData objectForKey:@"nli"] objectAtIndex:0];
            NSDictionary *desc = [nli objectForKey:@"desc_obj"];
            int status = [[desc objectForKey:@"status"] intValue];
            if (status != 0) {// 0 说明状态正常,非零为状态不正常
                NSString *result  = [desc objectForKey:@"result"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    _asrTextView.text = result;
                });
                
            }else{
                NSDictionary *semantic = [[nli objectForKey:@"semantic"]
                                          objectAtIndex:0];
                [weakSelf processSemantic:semantic];
                
            }
            
        }else{
            dispatch_async(dispatch_get_main_queue(), ^{
                _asrTextView.text = @"请说出10以内的4个数";
            });
        }
    }
    
    
    
}

- (void)onEndOfSpeech {
    [_recordBtn setTitle:@"开始录音" forState:UIControlStateNormal];
}


- (void)onError:(NSError *)error {
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"网络超时，请重试!"
                                          message:nil
                                          preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alertController animated:YES completion:^{
        dispatch_time_t time=dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC);
        dispatch_after(time, dispatch_get_main_queue(), ^{
            [alertController dismissViewControllerAnimated:YES completion:nil];
            
        });
        
    }];
    
    if (error) {
        NSLog(@"error is %@",error.localizedDescription);
    }
    
}


#pragma mark -- 处理语音和语义的结果
- (void)processModify:(NSString*) str {
    if ([str isEqualToString:@"open"]){//打开空调
        HMService *tmpService = _serviceDic[@"Switch"];
        HMCharacteristic *characteristic = tmpService.characteristics[1];
        
        if ([characteristic.characteristicType isEqualToString:HMCharacteristicTypeTargetLockMechanismState] ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypePowerState] ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypeObstructionDetected]) {
            
            [characteristic writeValue:@YES completionHandler:^(NSError *error){
                
                if(error == nil) {
                    dispatch_async(dispatch_get_main_queue(), ^ {
                        _asrTextView.text = @"空调已打开";
                    });
                } else {
                    NSLog(@"error in writing characterstic: %@", error);
                    dispatch_async(dispatch_get_main_queue(), ^ {
                        _asrTextView.text = @"空调打开失败，请重试!";
                    });
                }
            }];
            
        }

        
    }else if ([str isEqualToString:@"close"]){//关闭空调
        HMService *tmpService = _serviceDic[@"Switch"];
        HMCharacteristic *characteristic = tmpService.characteristics[1];
        
        if ([characteristic.characteristicType isEqualToString:HMCharacteristicTypeTargetLockMechanismState] ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypePowerState] ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypeObstructionDetected]) {
            
            [characteristic writeValue:@NO completionHandler:^(NSError *error){
                
                if(error == nil) {
                    dispatch_async(dispatch_get_main_queue(), ^ {
                        _asrTextView.text = @"空调已关闭";
                    });
                } else {
                    NSLog(@"error in writing characterstic: %@", error);
                    _asrTextView.text = @"空调关闭失败，请重试!";
                }
            }];
            
        }

        
    }else if ([str isEqualToString:@"control_temperature"]){//调节空调的温度
        HMService *tmpService1 = _serviceDic[@"Switch"];
        HMCharacteristic *characteristic1 = tmpService1.characteristics[1];
        BOOL isOpen = [characteristic1.value boolValue];
        if (isOpen) {
            UIAlertController *alertController = [UIAlertController
                                                  alertControllerWithTitle:@"空调还没有打开，请打开空调"
                                                  message:nil
                                                  preferredStyle:UIAlertControllerStyleAlert];
            [self presentViewController:alertController animated:YES completion:^{
                dispatch_time_t time=dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC);
                dispatch_after(time, dispatch_get_main_queue(), ^{
                    [alertController dismissViewControllerAnimated:YES completion:nil];
                    
                });
                
            }];
            
            return;

        }

        
        
        if ([characteristic1.characteristicType isEqualToString:HMCharacteristicTypeTargetLockMechanismState] ||
            [characteristic1.characteristicType isEqualToString:HMCharacteristicTypePowerState] ||
            [characteristic1.characteristicType isEqualToString:HMCharacteristicTypeObstructionDetected]) {
            
            [characteristic1 writeValue:@YES completionHandler:^(NSError *error){
                
                if(error == nil) {
                    
                } else {
                    NSLog(@"error in writing characterstic: %@", error);
                }
            }];
            
        }

        
        HMService *tmpService = _serviceDic[@"Temperature"];
        HMCharacteristic *characteristic = tmpService.characteristics[2];
       
        float minimumValue = [characteristic.metadata.minimumValue floatValue];
        float maximumValue = [characteristic.metadata.maximumValue floatValue];
        
        float value = [characteristic.value floatValue];
        if ([_slotDic.allKeys containsObject:@"regulation"]) {//如果包含regulation，说明是调整温度
            NSString *type = _slotDic[@"regulation"];
            if ([type isEqualToString:@"down"]) {//调低温度
                NSString *typeValue = _slotDic[@"value"];
                if (typeValue) {
                    value = [self translationArebicStr:typeValue];
                }else{
                     value -= 5;//每次调整五度
                }
               
                if (value < minimumValue) {
                    UIAlertController *alertController = [UIAlertController
                                                          alertControllerWithTitle:@"当前已经是最低温度了"
                                                          message:nil
                                                          preferredStyle:UIAlertControllerStyleAlert];
                    [self presentViewController:alertController animated:YES completion:^{
                        dispatch_time_t time=dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC);
                        dispatch_after(time, dispatch_get_main_queue(), ^{
                            [alertController dismissViewControllerAnimated:YES completion:nil];
                            
                        });
                        
                    }];
                    
                }else{
                    [characteristic writeValue:[NSNumber numberWithFloat:value] completionHandler:^(NSError *error){
                        
                        if(error == nil) {
                            
                        } else {
                            NSLog(@"error in writing characterstic: %@", error);
                        }
                    }];
                    
                }
                
            }else if ([type isEqualToString:@"up"]){//调高温度
                NSString *typeValue = _slotDic[@"value"];
                if (typeValue) {
                    value = [self translationArebicStr:typeValue];
                }else{
                    value += 5;//每次调整五度
                }
                if (value > maximumValue) {
                    UIAlertController *alertController = [UIAlertController
                                                          alertControllerWithTitle:@"超过了最高温度了"
                                                          message:nil
                                                          preferredStyle:UIAlertControllerStyleAlert];
                    [self presentViewController:alertController animated:YES completion:^{
                        dispatch_time_t time=dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC);
                        dispatch_after(time, dispatch_get_main_queue(), ^{
                            [alertController dismissViewControllerAnimated:YES completion:nil];
                            
                        });
                        
                    }];
                    
                }else{
                    [characteristic writeValue:[NSNumber numberWithFloat:value] completionHandler:^(NSError *error){
                        
                        if(error == nil) {
                            
                        } else {
                            NSLog(@"error in writing characterstic: %@", error);
                        }
                    }];
                    
                }
                
            }
        }else{//设置温度，
            NSString *typeValue = _slotDic[@"value"];
            float value = [self translationArebicStr:typeValue];
            
            
            if (value > maximumValue) {
                UIAlertController *alertController = [UIAlertController
                                                      alertControllerWithTitle:@"超过了最高温度了"
                                                      message:nil
                                                      preferredStyle:UIAlertControllerStyleAlert];
                [self presentViewController:alertController animated:YES completion:^{
                    dispatch_time_t time=dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC);
                    dispatch_after(time, dispatch_get_main_queue(), ^{
                        [alertController dismissViewControllerAnimated:YES completion:nil];
                        
                    });
                    
                }];

            }else if (value <minimumValue){
                UIAlertController *alertController = [UIAlertController
                                                      alertControllerWithTitle:@"当前已经是最低温度了"
                                                      message:nil
                                                      preferredStyle:UIAlertControllerStyleAlert];
                [self presentViewController:alertController animated:YES completion:^{
                    dispatch_time_t time=dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC);
                    dispatch_after(time, dispatch_get_main_queue(), ^{
                        [alertController dismissViewControllerAnimated:YES completion:nil];
                        
                    });
                    
                }];

            }else{
                [characteristic writeValue:[NSNumber numberWithFloat:value] completionHandler:^(NSError *error){
                    
                    if(error == nil) {
                        
                    } else {
                        NSLog(@"error in writing characterstic: %@", error);
                    }
                }];

            }
            
        }
    }
    
}

//处理ASR节点
- (void)processASR:(NSDictionary*)asrDic {
    NSString *result  = [asrDic objectForKey:@"result"];
    if (result.length == 0) { //如果结果为空，则弹出警告框
        UIAlertController *alertController = [UIAlertController
                                              alertControllerWithTitle:@"没有接受到语音，请重新输入!"
                                              message:nil
                                              preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertController animated:YES completion:^{
            dispatch_time_t time=dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC);
            dispatch_after(time, dispatch_get_main_queue(), ^{
                [alertController dismissViewControllerAnimated:YES completion:nil];
                
            });
            
        }];
        
    }else{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *str = [result stringByReplacingOccurrencesOfString:@" " withString:@""];//去掉字符中间的空格
            _asrTextView.text = str;
        });
    }
    
}

//处理Semantic节点
- (void)processSemantic:(NSDictionary*)semanticDic {
    NSArray *slot = [semanticDic objectForKey:@"slots"];
    _slotDic = [[NSMutableDictionary alloc] init];
    if (slot.count != 0) {
        for (NSDictionary *dic in slot) {
            NSString* name = [dic objectForKey:@"name"];
            NSString* value = [dic objectForKey:@"value"];
            [_slotDic setObject:value forKey:name];
        }
        
    }
    
    NSArray *modify = [semanticDic objectForKey:@"modifier"];
    if (modify.count != 0) {
        for (NSString *s in modify) {
            [self processModify:s];
            
        }
        
    }
    
}




#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    HMService *tmpService = _serviceDic[@"空调"];
    return tmpService.characteristics.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor clearColor];
    HMService *tmpService = _serviceDic[@"空调"];
    HMCharacteristic *characteristic = tmpService.characteristics[indexPath.row];
    if (characteristic.value != nil) {
        cell.textLabel.text = [NSString stringWithFormat:@"%@", characteristic.value];;
    } else {
        cell.textLabel.text = @"";
    }
    
    cell.detailTextLabel.text = characteristic.localizedDescription;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    return;
}

//中文数字转换为阿拉伯数字
-(int)translationArebicStr:(NSString *)chineseStr{
    NSArray *arabic_numerals = @[@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"0",@"0"];
    NSArray *chinese_numerals = @[@"一",@"二",@"三",@"四",@"五",@"六",@"七",@"八",@"九",@"零", @"十"];
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjects:arabic_numerals forKeys:chinese_numerals];
    
    int num = 0;
    if ([chineseStr isEqualToString:@"十"]) {
        num = 10;
    }else{
        for (int i = 0; i < chineseStr.length; i ++) {
            NSString *substr = [chineseStr substringWithRange:NSMakeRange(i, 1)];
            NSString *sum;
            if([substr isEqualToString:@"十"] && i < chineseStr.length){
                NSString *nextStr = [chineseStr substringWithRange:NSMakeRange(i, 1)];
                if([chinese_numerals containsObject:nextStr]){
                    if (num != 0) {
                        continue;
                    }else{
                        num = 1;
                        
                    }
                }
            }else{
                if([chinese_numerals containsObject:substr]){
                    sum = [dictionary objectForKey:substr];
                    num = num*10 + [sum intValue];
                }

            }
            
            
        }

    }
    
    return num;
    
}

@end

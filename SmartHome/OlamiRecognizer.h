//
//  OlamiRecognizer.h
//  OlamiRecognizer
//
//  Created by olami on 2017/5/8.
//  Copyright © 2017年 VIA Techologies, Inc. &OLAMI Team All rights reserved.
//  http://olami.ai

#import <Foundation/Foundation.h>

#define Version 1.0

@protocol OlamiRecognizerDelegate <NSObject>

@optional

//返回结果
- (void)onResult:(NSData*)result;

//取消本次会话
- (void)onCancel;

//识别失败
- (void)onError:(NSError *)error;

//音量的大小 音频强度范围时0到100
- (void)onUpdateVolume:(float) volume;


//开始录音
- (void)onBeginningOfSpeech;

//结束录音
- (void)onEndOfSpeech;

@end

typedef NS_ENUM(NSInteger, LanguageLocalization) {
    LANGUAGE_SIMPLIFIED_CHINESE = 0, //简体中文
    LANGUAGE_TRADITIONA_CHINESE = 1  //繁体中文
};
@interface OlamiRecognizer : NSObject
@property (nonatomic, weak) id<OlamiRecognizerDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL isRecording;   //是否正在录音
- (void)start;           //开始录音
- (void)stop;            //结束录音，开始识别
- (void)cancel;          //取消本次回话

//设置语系的选项，目前只支持一种，简体中文
- (void)setLocalization:(LanguageLocalization) location;

/**
 *CUSID;        //终端用户标识id，用来区分各个最终用户 例如:手机的IMEI
 *appKey;       //创建应用的appkey
 *api;          //要调用的API类型。现有3种：语义(nli)和分词(seg)和语音(asr)
 *appSecret;    //加密的秘钥，由应用管理自动生成
 */
- (void)setAuthorization:(NSString*)appKey api:(NSString*)api appSecret:(NSString*)appSecret cusid:(NSString*)CUSID;
- (void)setVADTimeoutFrontSIL:(unsigned int)value;      //设置VAD前端点超时范围 1000~~10000（ms） 默认3000
- (void)setVADTimeoutBackSIL:(unsigned int)value;       //设置VAD后端点超时范围  1000~~10000（ms） 默认2000
- (void)setInputType:(int) type;                        //设置是语音输入还是文字输入 0 为语音 1为文字输入
- (void)sendText:(NSString*)text;                       //发送输入的文字
- (void)setLatitudeAndLongitude:(double) latitude longitude:(double)longit; //设置地理位置,参数为经纬度

@end


//
//  XDControlLightViewController.m
//  Hue-forCSK
//
//  Created by Gai on 16/9/1.
//  Copyright © 2016年 Gai. All rights reserved.
//

#import "XDControlLightViewController.h"
#import "XDBridgePushLinkViewController.h"
#import "XDLoadingView.h"
#import "XDCaptureViewController.h"
#import "so_hptimer.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface XDControlLightViewController () <XDBridgePushLinkViewControllerDelegate,
                                            UITextViewDelegate>
{
    BOOL        _flag;
    so_hptimer  mHPTimer;
    UIButton    *_tempButton;

}

@property (strong, nonatomic) XDLoadingView         *loadingView;
@property (strong, nonatomic) PHBridgeSearching     *bridgeSearching;

@property (strong, nonatomic) UISwitch              *switch1;
@property (strong, nonatomic) UISlider              *slider1;
@property (strong, nonatomic) UIButton              *transmitingButton;
@property (strong, nonatomic) UIButton              *stopButton;
@property (strong, nonatomic) UIButton              *decodingButton;
@property (strong, nonatomic) UITextView            *inputTextView;
@property (strong, nonatomic) UIButton              *receivingButton;
@property (strong, nonatomic) UILabel               *originDataLabel;

@property (strong, nonatomic) NSMutableArray        *timeIntervalArray;
@property (strong, nonatomic) NSString              *dataStream;

@property (strong, nonatomic) NSNumber              *currentBrightness;

@property (strong, nonatomic) dispatch_source_t     timer;

@property (assign, nonatomic) NSInteger             selectedCSKOrder;

@end

@implementation XDControlLightViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
//    self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:20.0/255 green:20.0/255 blue:20.0/255 alpha:1.0];
    self.navigationController.navigationBar.barTintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.translucent = NO;
    
    // 启用监听
    PHNotificationManager *notificationManager = [PHNotificationManager defaultManager];
    
    [notificationManager registerObject:self withSelector:@selector(localConnection) forNotification:LOCAL_CONNECTION_NOTIFICATION];
    [notificationManager registerObject:self withSelector:@selector(noLocalConnection) forNotification:NO_LOCAL_CONNECTION_NOTIFICATION];
    [notificationManager registerObject:self withSelector:@selector(notAuthenticated) forNotification:NO_LOCAL_AUTHENTICATION_NOTIFICATION];
    
    [self startConnect];


    [self setUI];
}


- (void)setUI {

    [self setUIForControllLightState];
    [self setUIForCSK];
    
    _inputTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, 200, [UIScreen mainScreen].bounds.size.width, 100)];
    _inputTextView.delegate = self;
    [_inputTextView setBackgroundColor:[UIColor greenColor]];
    _inputTextView.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:_inputTextView];
    // _placeholderLabel
    UILabel *placeHolderLabel = [[UILabel alloc] init];
    placeHolderLabel.text = @"请输入内容";
    placeHolderLabel.numberOfLines = 0;
    placeHolderLabel.textColor = [UIColor lightGrayColor];
    placeHolderLabel.font = _inputTextView.font;
    [placeHolderLabel sizeToFit];
    [_inputTextView addSubview:placeHolderLabel];
    [_inputTextView setValue:placeHolderLabel forKey:@"_placeholderLabel"];
    
    _receivingButton = [[UIButton alloc] initWithFrame:CGRectMake(100, 450, 100, 30)];
    [_receivingButton setTitle:@"接收" forState:UIControlStateNormal];
    [_receivingButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_receivingButton addTarget:self action:@selector(beginReceptionAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_receivingButton];
    
    _originDataLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 310, SCREEN_WIDTH, 100)];
    _originDataLabel.textColor = [UIColor blackColor];
    _originDataLabel.text = @"发送的数据流为：";
    _originDataLabel.numberOfLines = 10;
    [self.view addSubview:_originDataLabel];

}

- (void)setUIForControllLightState {
    _slider1 = [[UISlider alloc] initWithFrame:CGRectMake(10, 20, 255, 10)];
    _slider1.minimumValue = 1.0;
    _slider1.maximumValue = 254.0;
    _slider1.value = 127.0;
    _slider1.continuous = NO;
    [_slider1 addTarget:self action:@selector(brightnessChangeLight1:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_slider1];
    
    _switch1 = [[UISwitch alloc] initWithFrame:CGRectMake(300, 20, 10, 10)];
    [_switch1 addTarget:self action:@selector(switchChangeLight1:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_switch1];
}

- (void)setUIForCSK {
    _transmitingButton = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH * 0.2, 90, SCREEN_WIDTH * 0.2, 30)];
    [_transmitingButton setTitle:@"发送" forState:UIControlStateNormal];
    [_transmitingButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_transmitingButton addTarget:self action:@selector(beginTransmissionAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_transmitingButton];
    
    _stopButton = [[UIButton alloc] initWithFrame:CGRectMake(SCREEN_WIDTH * 0.6, 90, SCREEN_WIDTH * 0.2, 30)];
    [_stopButton setTitle:@"停止" forState:UIControlStateNormal];
    [_stopButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_stopButton addTarget:self action:@selector(stopTransmissionAction) forControlEvents:UIControlEventTouchUpInside];
    _stopButton.enabled = NO;
    [self.view addSubview:_stopButton];
    
    for (int i = 0; i < 3; i++) {
        NSString *string = [NSString stringWithFormat:@"%d%@", (int)pow(2, (i + 2)), @"CSK"];
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = 1000 + i;
        button.frame = CGRectMake(SCREEN_WIDTH * 0.075 + i * (SCREEN_WIDTH * 0.3), 150, SCREEN_WIDTH * 0.25, 30);
        button.layer.cornerRadius = button.frame.size.height / 2;
        button.layer.borderColor = [UIColor blackColor].CGColor;
        button.layer.borderWidth = 1;
        button.backgroundColor = [UIColor whiteColor];
        [button setTitle:string forState:UIControlStateNormal];
        [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(chooseCSKOrder:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
    }
}

#pragma mark - Controll light state

- (void)brightnessChangeLight1:(UISlider *)sender {
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    NSArray *allLights = [cache.lights allValues];
    PHLight *light1 = allLights[0];
    PHLightState *state = [[PHLightState alloc] init];
    state.brightness = [NSNumber numberWithInt:(int)sender.value];
    self.currentBrightness = state.brightness;
    PHBridgeSendAPI *bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
    [bridgeSendAPI updateLightStateForId:light1.identifier withLightState:state completionHandler:^(NSArray *errors) {
        if (!errors){
            NSLog(@"success");
        } else {
            NSLog(@"false");
        }
    }];
}

- (void)switchChangeLight1:(UISwitch *)sender {
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    NSArray *allLights = [cache.lights allValues];
    PHLight *light1 = allLights[0];
    PHLightState *state = [[PHLightState alloc] init];
    state.on = [NSNumber numberWithBool:sender.on];
    PHBridgeSendAPI *bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
    [bridgeSendAPI updateLightStateForId:light1.identifier withLightState:state completionHandler:^(NSArray *errors) {
        if (!errors){
            NSLog(@"success");
        } else {
            NSLog(@"false");
        }
    }];
    
}

#pragma mark - Transmit data

/**
 使用CSK信号发送数据
 */
- (void)beginTransmissionAction {
    NSLog(@"transmitingButton");
    self.transmitingButton.enabled = NO;
    self.stopButton.enabled = YES;
    self.timeIntervalArray = [[NSMutableArray alloc] init];
    
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    NSArray *allLights = [cache.lights allValues];
    PHLight *light1 = allLights[0];
    PHLightState *oldState = light1.lightState;
    self.currentBrightness = oldState.brightness;
    PHLightState *state = [[PHLightState alloc] init];
    PHBridgeSendAPI *bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
    
    _flag = NO;
    
    NSLog(@"%@",self.dataStream);
    if (self.dataStream.length == 0) {
        [self showBasicAlertWithTitle:@"提示" andMessage:@"请输入需要发送的内容"];
        self.transmitingButton.enabled = YES;
        return;
    }
    
    if (self.selectedCSKOrder == 0) {
        [self showBasicAlertWithTitle:@"提示" andMessage:@"请选择CSK调制阶数"];
        self.transmitingButton.enabled = YES;
        return;
    }
    NSInteger symbolLength = log2(self.selectedCSKOrder);

    if (self.dataStream.length % symbolLength != 0) {
        NSString *addZero = @"";
        addZero = [addZero stringByPaddingToLength:(3 - self.dataStream.length % symbolLength) withString:@"0" startingAtIndex:0];
        self.dataStream = [self.dataStream stringByAppendingString:addZero];
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss.SSS"];

    __block NSDate *lastDate = [NSDate date];
    NSLog(@"lastDate:%@", [dateFormatter stringFromDate:lastDate]);
    __block NSDate *currentDate = [NSDate date];
    NSLog(@"currentDate:%@", [dateFormatter stringFromDate:currentDate]);
    
    __weak typeof(self) weakSelf = self;
    
    __block NSInteger count = 0;
    
    // 定时发送数据
    so_hptimer_create(&mHPTimer, 1 * NSEC_PER_SEC);
    so_hptimer_set_action(mHPTimer, ^{
        NSString *oneSymbol = [weakSelf.dataStream substringWithRange:NSMakeRange(count, symbolLength)];
        count = count + symbolLength;
        NSLog(@"第%ld个数据：%@", count / symbolLength, oneSymbol);
        if (count == weakSelf.dataStream.length) {
            count = 0;
            NSLog(@"reset data");
//            [self stopTransmissionAction];
        }
        CGPoint constellationPoint = [weakSelf colorCoding:oneSymbol];
        state.x = [NSNumber numberWithFloat:constellationPoint.x];
        state.y = [NSNumber numberWithFloat:constellationPoint.y];
        state.transitionTime = [NSNumber numberWithInt:0];
        
        [bridgeSendAPI updateLightStateForId:light1.identifier withLightState:state completionHandler:^(NSArray *errors) {
            if (!errors){
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"send success");
                    NSLog(@"send data %@",oneSymbol);
                });
            } else {
                NSLog(@"send false");
            }
        }];
        currentDate = [NSDate date];
        NSTimeInterval timeInterval = [currentDate timeIntervalSinceDate:lastDate];
        [weakSelf.timeIntervalArray addObject:[NSNumber numberWithDouble:timeInterval]];
        NSLog(@"time interval:%f",timeInterval);
        lastDate = currentDate;
        NSLog(@"currentDate:%@",[dateFormatter stringFromDate:currentDate]);
    });
    so_hptimer_resume(mHPTimer);

}

/**
 停止发送数据
 */
- (void)stopTransmissionAction {
    
    so_hptimer_suspend(mHPTimer);
    _transmitingButton.enabled = YES;
    double sum = 0;
    double max = 0;
    double min = 1;
    double avg = 0;
    double var = 0;
    for (int i = 1; i < self.timeIntervalArray.count; i++) {
        double oneValue = [self.timeIntervalArray[i] doubleValue];
        //        if (temp != 0) {
        sum += oneValue;
        max = MAX(max, oneValue);
        min = MIN(min, oneValue);
        //        }
        
    }
    avg = sum / (self.timeIntervalArray.count-1);
    double temp = 0;
    for (int i = 1; i < self.timeIntervalArray.count; i++) {
        double oneValue = [self.timeIntervalArray[i] doubleValue];
        temp += (oneValue - avg) * (oneValue - avg);
    }
    var = temp / (self.timeIntervalArray.count-1);
    NSLog(@"the total number of data sended:%lu",(unsigned long)self.timeIntervalArray.count);
    NSLog(@"%@",self.timeIntervalArray);
    NSLog(@"sum:%f",sum);
    NSLog(@"count:%lu",(unsigned long)self.timeIntervalArray.count);
    NSLog(@"average time-interval:%f",avg);
    NSLog(@"variance time-interval:%f",var);
    NSLog(@"max time-interval:%f",max);
    NSLog(@"min time-interval:%f",min);
    
}

#pragma mark - Color coding

/**
 选择使用几阶CSK来进行编码
 
 @param sender 点击的Button
 */
- (void)chooseCSKOrder:(UIButton *)sender {
    if (_tempButton != sender) {
        if (_tempButton != nil) {
            _tempButton.selected = NO;
            _tempButton.backgroundColor = [UIColor whiteColor];
        }
        sender.selected = YES;
        sender.backgroundColor = [UIColor orangeColor];
        _tempButton = sender;
        self.selectedCSKOrder = (NSInteger)pow(2, (sender.tag - 1000 + 2));
    }
}

/**
 进行CSK编码

 @param symbol 所要编码的symbol

 @return 返回编码后的结果
 */
- (CGPoint)colorCoding:(NSString *)symbol {
    CGPoint constellationPoint;
    NSDictionary *allConstellationPoints = [XDControlLightViewController getConstellationData];
    NSDictionary *onePoint =  [allConstellationPoints objectForKey:symbol];
    constellationPoint.x = [[onePoint objectForKey:@"x"] floatValue];
    constellationPoint.y = [[onePoint objectForKey:@"y"] floatValue];
    
    return constellationPoint;
}

/**
 从数据文件中获取星座点数据

 @return 以字典的形式返回星座点数据
 */
+ (NSDictionary *)getConstellationData {
    NSString *jsonPath = [[NSBundle mainBundle] pathForResource:@"ConstellationPoint" ofType:@"json"];
    NSString *jsonString = [[NSString alloc] initWithContentsOfFile:jsonPath encoding:NSUTF8StringEncoding error:nil];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:nil];
    NSMutableDictionary *allConstellationPoints = [[NSMutableDictionary alloc] init];
    for (NSString *key in [dic allKeys]) {
        NSDictionary *subDic = [dic objectForKey:key];
        for (NSString *subKey in [subDic allKeys]) {
            [allConstellationPoints setObject:[subDic objectForKey:subKey] forKey:subKey];
        }
    }
    
    return (NSDictionary *)[allConstellationPoints mutableCopy];
}

#pragma mark - Get data stream

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) {
        [textView resignFirstResponder];
        self.dataStream = [self convertTextToDataStream:textView.text];
        self.originDataLabel.text = [@"发送的数据流为：" stringByAppendingString:self.dataStream];
        return NO;
    }
    return YES;
}

/**
 生成50位随机数据流

 @return 以字符串形式返回随机数据流
 */
- (NSString *)createRandomSequence {
    NSString *randomSequence = @"";
    for (NSInteger i = 0; i < 50; i++) {
        int x = arc4random() % 2;
        randomSequence = [randomSequence stringByAppendingFormat:@"%d",x];
    }
    return randomSequence;
}

/**
 输入文本转换成01数据流

 @param inputText 需要转换的文本

 @return 以字符串形式返回01数据流
 */
- (NSString *)convertTextToDataStream:(NSString *)inputText {
    NSLog(@"%@",inputText);
    __block NSString *dataStream = @"";
    for (int i = 0 ; i < inputText.length; i++) {
        // 输入字符转换为ascii码
        int asciiCode = [inputText characterAtIndex:i];
        if (asciiCode >= 32 && asciiCode <= 126) {
            // 符合条件的转换成二进制
            NSString *binaryCode = [self covertAsciiToBinary:asciiCode];
            dataStream = [dataStream stringByAppendingString:binaryCode];
        } else {
            // 不符合条件则弹出提示窗口，并清空数据流
            [self showBasicAlertWithTitle:@"提示" andMessage:@"仅可输入26个基本拉丁字母、阿拉伯数字和英式标点符号"];
            dataStream = @"";
            break;
        }
        NSLog(@"%d", asciiCode);
    }
    NSLog(@"%@", dataStream);
    dataStream = [self addSyncFrame:dataStream];
    NSLog(@"%@", dataStream);
    return dataStream;
}

/**
 十进制ascii码转八位二进制

 @param asciiNumber 十进制ascii码

 @return 以字符串形式返回八位二进制数
 */
- (NSString *)covertAsciiToBinary:(int)asciiNumber {
    
    NSString *binaryNumber = [self covertDecimalToBinary:asciiNumber];
    
    // 给二进制补0凑够八位,因为ascii码对应的二进制是八位的
    NSString *addZero = @"";
    addZero = [addZero stringByPaddingToLength:(8 - binaryNumber.length) withString:@"0" startingAtIndex:0];
    binaryNumber = [NSString stringWithFormat:@"%@%@",addZero, binaryNumber];
    
    return binaryNumber;
}

/**
 十进制转二进制

 @param decimalNumber 十进制整数

 @return 以字符串形式返回二进制数
 */
- (NSString *)covertDecimalToBinary:(int)decimalNumber {
    
    int remainder = 0; // 余数
    int quotient = 0; // 商
    NSString *binaryNumber = @"";
    
    // 转换
    while (decimalNumber) {
        remainder = decimalNumber % 2;
        quotient = decimalNumber / 2;
        binaryNumber = [NSString stringWithFormat:@"%d%@",remainder, binaryNumber];
        decimalNumber = quotient;
    }
    
    return binaryNumber;
}



- (NSString *)covertBinaryToDecimal:(NSString *)binaryNumber {
    
    NSString *decimalNumber = @"";
    
    return decimalNumber;
}

/**
 为数据流添加同步帧

 @param dataStream 需要添加同步帧的数据流

 @return 返回已经添加同步帧的数据流
 */
- (NSString *)addSyncFrame:(NSString *)dataStream {
    
    NSString *syncFrame = @"";
    syncFrame = [syncFrame stringByPaddingToLength:16 withString:@"1" startingAtIndex:0];
    dataStream = [dataStream stringByAppendingString:syncFrame];
    
    return dataStream;
}

#pragma mark - Private method

- (void)showBasicAlertWithTitle:(NSString *)title andMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) { }];
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)beginReceptionAction {
    XDCaptureViewController *captureViewController = [[XDCaptureViewController alloc] init];
    [self presentViewController:captureViewController animated:YES completion:nil];
}

#pragma mark - Hue SDK

- (void)localConnection {
    [self removeLoadingView];
    NSLog(@"localConnection");
}

- (void)noLocalConnection {
    [self searchBridge];
}

- (void)notAuthenticated {
    [self doAuthenticated];
}

// 进行身份验证
- (void)doAuthenticated {
    [UIAppDelegate.phHueSDK disableLocalConnection];
    XDBridgePushLinkViewController *bridgePushLinkViewController = [[XDBridgePushLinkViewController alloc] init];
    bridgePushLinkViewController.delegate = self;
    [self presentViewController:bridgePushLinkViewController animated:YES completion:^{
        [bridgePushLinkViewController startPushLink];
    }];
    
}

// 推送链接成功
- (void)pushLinkSuccess {
    [self dismissViewControllerAnimated:YES completion:nil];
    [self startConnect];
}

// 尝试连接
- (void)startConnect {
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    if (cache.bridgeConfiguration != nil && cache.bridgeConfiguration.ipaddress != nil) {
        [self showLoadingView:@"Connecting..."];
        [UIAppDelegate.phHueSDK enableLocalConnection];
    } else {
        [self searchBridge];
    }
}

// 寻找桥接器
- (void)searchBridge {
    
    [UIAppDelegate.phHueSDK disableLocalConnection];
    
    [self showLoadingView:@"Searching..."];
    
    self.bridgeSearching = [[PHBridgeSearching alloc] initWithUpnpSearch:YES
                                                         andPortalSearch:YES
                                                       andIpAdressSearch:YES];
    
    [self.bridgeSearching startSearchWithCompletionHandler:^(NSDictionary *bridgesFound) {
        
        if (bridgesFound.count > 0) {
            NSArray *sortedKeys = [bridgesFound.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
            NSString *bridgeID = sortedKeys[0];
            NSString *ip = bridgesFound[bridgeID];
            [self showLoadingView:@"Connecting..."];
            [UIAppDelegate.phHueSDK setBridgeToUseWithId:bridgeID ipAddress:ip];
//            [self performSelector:@selector(startConnect) withObject:nil afterDelay:1.0];
            [self startConnect];
            
        } else {
            // 没有发现桥接器，弹出警告
        }
    }];
}


- (void)showLoadingView:(NSString *)string {
    // 先移除旧的
    [self removeLoadingView];
    // 再生成新的
    self.loadingView = [[XDLoadingView alloc] initWithString:string];
    [self.navigationController.view insertSubview:self.loadingView belowSubview:self.navigationController.navigationBar];
}

- (void)removeLoadingView {
    if (self.loadingView != nil) {
        [self.loadingView removeFromSuperview];
        self.loadingView = nil;
    }
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end

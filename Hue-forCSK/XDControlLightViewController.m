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
#import "so_hptimer.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface XDControlLightViewController () <XDBridgePushLinkViewControllerDelegate,
                                            UITextViewDelegate>
{
    BOOL        _flag;
    so_hptimer  mHPTimer;

}

@property (strong, nonatomic) XDLoadingView         *loadingView;
@property (strong, nonatomic) PHBridgeSearching     *bridgeSearching;

@property (strong, nonatomic) UISwitch              *switch1;
@property (strong, nonatomic) UISlider              *slider1;
@property (strong, nonatomic) UIButton              *CSKButton;
@property (strong, nonatomic) UIButton              *stopButton;
@property (strong, nonatomic) UIButton              *decodingButton;
@property (strong, nonatomic) UITextView            *inputTextView;

@property (strong, nonatomic) NSMutableArray        *timeIntervalArray;
@property (strong, nonatomic) NSString              *dataStream;

@property (strong, nonatomic) NSNumber              *currentBrightness;

@property (strong, nonatomic) dispatch_source_t     timer;

@end

@implementation XDControlLightViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:20.0/255 green:20.0/255 blue:20.0/255 alpha:1.0];
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
    
    _CSKButton = [[UIButton alloc] initWithFrame:CGRectMake(10, 100, 100, 10)];
    [_CSKButton setTitle:@"csk" forState:UIControlStateNormal];
    [_CSKButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_CSKButton addTarget:self action:@selector(CSKButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_CSKButton];
    
    _stopButton = [[UIButton alloc] initWithFrame:CGRectMake(200, 100, 100, 10)];
    [_stopButton setTitle:@"stop" forState:UIControlStateNormal];
    [_stopButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_stopButton addTarget:self action:@selector(stopTransmissionAction) forControlEvents:UIControlEventTouchUpInside];
    _stopButton.enabled = NO;
    [self.view addSubview:_stopButton];
    
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

}


-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) {
        [textView resignFirstResponder];
        self.dataStream = [self convertTextToDataStream:textView.text];
        return NO;
    }
    return YES; 
}


- (void)brightnessChangeLight1:(UISlider *)sender {
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    NSArray *allLights = [cache.lights allValues];
    PHLight *light1 = allLights[1];
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
    PHLight *light1 = allLights[1];
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

/**
 进行CSK信号发送数据
 */
- (void)CSKButtonAction {
    NSLog(@"CSKButton");
    _CSKButton.enabled = NO;
    _stopButton.enabled = YES;
    self.timeIntervalArray = [[NSMutableArray alloc] init];
    
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    NSArray *allLights = [cache.lights allValues];
    PHLight *light1 = allLights[1];
    PHLightState *oldState = light1.lightState;
    self.currentBrightness = oldState.brightness;
    PHLightState *state = [[PHLightState alloc] init];
    PHBridgeSendAPI *bridgeSendAPI = [[PHBridgeSendAPI alloc] init];
    
    _flag = NO;
    
    NSLog(@"%@",self.dataStream);
    if (self.dataStream.length == 0) {
        return;
    }
    
    UIColor *colorForZero = [[UIColor alloc] initWithRed:0.3 green:0.5 blue:0.8 alpha:1.0];
    UIColor *colorForOne = [[UIColor alloc] initWithRed:0.8 green:0.5 blue:0.4 alpha:1.0];
    
    CGPoint xyForZero = [PHUtilities calculateXY:colorForZero forModel:@"LCT001"];
    CGPoint xyForOne = [PHUtilities calculateXY:colorForOne forModel:@"LCT001"];
    
    __block int i = 0;
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss.SSS"];

    
    __block NSDate *lastDate = [NSDate date];
    NSLog(@"lastDate:%@",[dateFormatter stringFromDate:lastDate]);
    __block NSDate *currentDate = [NSDate date];
    NSLog(@"currentDate:%@",[dateFormatter stringFromDate:currentDate]);
    __weak typeof(self) weakSelf = self;
    
    so_hptimer_create(&mHPTimer, 0.1 * NSEC_PER_SEC);
    so_hptimer_set_action(mHPTimer, ^{
        int data = ([weakSelf.dataStream characterAtIndex:i] == 48 ? 0 : 1);
        i++;
        NSLog(@"第%d个数据：%d",i, data);
        if (i == weakSelf.dataStream.length) {
            i = 0;
            NSLog(@"reset data");
//            [self stopTransmissionAction];
        }
        if (data == 0) {
            state.x = [NSNumber numberWithFloat:xyForZero.x];
            state.y = [NSNumber numberWithFloat:xyForZero.y];
        } else {
            state.x = [NSNumber numberWithFloat:xyForOne.x];
            state.y = [NSNumber numberWithFloat:xyForOne.y];
        }
        state.transitionTime = [NSNumber numberWithInt:0];
        
        [bridgeSendAPI updateLightStateForId:light1.identifier withLightState:state completionHandler:^(NSArray *errors) {
            if (!errors){
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"send success");
                    NSLog(@"send data %d",data);
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
    _CSKButton.enabled = YES;
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
            NSString *binaryCode = [self covertDecimalToBinary:asciiCode];
            dataStream = [dataStream stringByAppendingString:binaryCode];
        } else {
            // 不符合条件则弹出提示窗口，并清空数据流
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"仅可输入26个基本拉丁字母、阿拉伯数字和英式标点符号" preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) { }];
            [alert addAction:defaultAction];
            [self presentViewController:alert animated:YES completion:nil];
            dataStream = @"";
            break;
        }
        NSLog(@"%d",asciiCode);
    }
    NSLog(@"%@",dataStream);
    return dataStream;
}


/**
 十进制转二进制

 @param decimalNumber 十进制整数

 @return 以字符串形式返回八位二进制数
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
    
    // 给二进制补0凑够八位
    NSString *addZero = @"";
    addZero = [addZero stringByPaddingToLength:(8 - binaryNumber.length) withString:@"0" startingAtIndex:0];
    binaryNumber = [NSString stringWithFormat:@"%@%@",addZero, binaryNumber];
    
    return binaryNumber;
}

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
            NSString *bridgeID = sortedKeys[1];
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

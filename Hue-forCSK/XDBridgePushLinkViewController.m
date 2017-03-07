//
//  XDBridgePushLinkViewController.m
//  Hue-forCSK
//
//  Created by Gai on 16/9/1.
//  Copyright © 2016年 Gai. All rights reserved.
//

#import "XDBridgePushLinkViewController.h"

@interface XDBridgePushLinkViewController ()

@property (strong, nonatomic) UIProgressView                *progressView;
@property (strong, nonatomic) UIImageView                   *imageView;

@end

@implementation XDBridgePushLinkViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.imageView = [[UIImageView alloc] init];
    self.imageView.frame = CGRectMake(0, 0, SCREEN_WIDTH, (SCREEN_HEIGHT - 64) * 0.8);
    self.imageView.image = [UIImage imageNamed:@"press_smartbridge"];
    [self.view addSubview:self.imageView];
    
    self.progressView = [[UIProgressView alloc] init];
    self.progressView.frame = CGRectMake(SCREEN_WIDTH * 0.05, (SCREEN_HEIGHT - 64) * 0.9, SCREEN_WIDTH * 0.9, 10);
    self.progressView.progress = 1.0;
    [self.view addSubview:self.progressView];
    
}


// 推送认证链接
- (void)startPushLink {
    PHNotificationManager *notificationManager = [PHNotificationManager defaultManager];
    [notificationManager registerObject:self withSelector:@selector(authenticationSuccess) forNotification:PUSHLINK_LOCAL_AUTHENTICATION_SUCCESS_NOTIFICATION];
    [notificationManager registerObject:self withSelector:@selector(authenticationFailed) forNotification:PUSHLINK_LOCAL_AUTHENTICATION_FAILED_NOTIFICATION];
    [notificationManager registerObject:self withSelector:@selector(noLocalConnection) forNotification:PUSHLINK_NO_LOCAL_CONNECTION_NOTIFICATION];
    [notificationManager registerObject:self withSelector:@selector(noLocalBridge) forNotification:PUSHLINK_NO_LOCAL_BRIDGE_KNOWN_NOTIFICATION];
    [notificationManager registerObject:self withSelector:@selector(buttonNotPressed:) forNotification:PUSHLINK_BUTTON_NOT_PRESSED_NOTIFICATION];
    
    [UIAppDelegate.phHueSDK startPushlinkAuthentication];

}

// 认证成功
- (void)authenticationSuccess {
    [[PHNotificationManager defaultManager] deregisterObjectForAllNotifications:self];
    [self.delegate pushLinkSuccess];
}

- (void)authenticationFailed {
    
}

- (void)noLocalConnection {
    
}

- (void)noLocalBridge {
    
}

- (void)buttonNotPressed:(NSNotification *)noticication {
    NSDictionary *dict = noticication.userInfo;
    NSNumber *progressPercentage = [dict objectForKey:@"progressPercentage"];
    float progressBarValue = [progressPercentage floatValue] / 100.0f;
    self.progressView.progress = 1 - progressBarValue;
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

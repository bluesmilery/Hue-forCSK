//
//  XDBridgePushLinkViewController.h
//  Hue-forCSK
//
//  Created by Gai on 16/9/1.
//  Copyright © 2016年 Gai. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

@protocol XDBridgePushLinkViewControllerDelegate <NSObject>

- (void)pushLinkSuccess;

@end


@interface XDBridgePushLinkViewController : UIViewController

@property (assign, nonatomic) id<XDBridgePushLinkViewControllerDelegate> delegate;

- (void)startPushLink;

@end

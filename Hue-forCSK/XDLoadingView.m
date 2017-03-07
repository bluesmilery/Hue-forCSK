//
//  XDLoadingView.m
//  Hue-forCSK
//
//  Created by Gai on 16/9/1.
//  Copyright © 2016年 Gai. All rights reserved.
//

#import "XDLoadingView.h"

@interface XDLoadingView ()

@property (strong, nonatomic) UIActivityIndicatorView           *activityIndicatorView;
@property (strong, nonatomic) UILabel                           *label;

@end

@implementation XDLoadingView

- (instancetype)initWithString:(NSString *)string {
    
    self = [super initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)];
    
    if (self) {
        
        self.backgroundColor = [UIColor lightGrayColor];
        
        self.activityIndicatorView = [[UIActivityIndicatorView alloc] init];
        self.activityIndicatorView.center = CGPointMake(SCREEN_WIDTH / 2, 64 + (SCREEN_HEIGHT - 64) / 2);
        self.activityIndicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        [self.activityIndicatorView startAnimating];
        [self addSubview:self.activityIndicatorView];
        
        self.label = [[UILabel alloc] init];
        self.label.text = string;
        self.label.textColor = [UIColor whiteColor];
        [self.label sizeToFit];
        self.label.center = CGPointMake(SCREEN_WIDTH / 2, self.activityIndicatorView.frame.origin.y + 30);
        [self addSubview:self.label];
        
    }
    
    return self;
}




/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end

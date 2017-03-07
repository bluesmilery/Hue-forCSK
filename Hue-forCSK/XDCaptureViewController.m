//
//  XDCaptureViewController.m
//  Hue-forCSK
//
//  Created by Gai on 2016/10/31.
//  Copyright © 2016年 Gai. All rights reserved.
//

#import "XDCaptureViewController.h"
#import "XDControlLightViewController.h"

#define SAMPLINGRATE 10

typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

@interface XDCaptureViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    float           _previewLayerHeight;                // 视频预览view高度
    float           _previewLayerWidth;                 // 视频预览view宽度
    BOOL            _startFlag;
    BOOL            _endFlag;
    BOOL            _syncFlag;
}

@property (strong, nonatomic) UIView                        *videoView; // 视频区域
@property (strong, nonatomic) UIView                        *showInfoView; // 展示解码信息区域
@property (strong, nonatomic) UILabel                       *finalLabel;

@property (strong, nonatomic) AVCaptureSession              *captureSession; //媒体捕获会话，负责输入设备和输出设备之间的数据传递
@property (strong, nonatomic) AVCaptureDeviceInput          *videoCaptureDeviceInput; //负责获得视频输入数据
@property (strong, nonatomic) AVCaptureVideoDataOutput      *videoDataOutput; // 负责输出视频数据
@property (strong, nonatomic) AVAssetWriter                 *assetWriter;
@property (strong, nonatomic) AVAssetWriterInput            *videoAssetWriterInput;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer    *captureVideoPreviewLayer; //相机拍摄预览图层

@property (strong, nonatomic) NSString                      *tempFilePath;

@property (strong, nonatomic) dispatch_queue_t              processingData;

@property (assign, nonatomic) NSInteger                     samplingCount; // 每一个symbol采样计数（摄像头帧率除以灯闪烁速率）
@property (strong, nonatomic) NSMutableArray                *samplingSymbolDataArray;
@property (strong, nonatomic) NSString                      *finalDataStream; // 最终解码的数据流
@property (assign, nonatomic) NSInteger                     syncFrameCount;
@property (strong, nonatomic) NSString                      *lastDecodedSymbol;

@end

@implementation XDCaptureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _previewLayerWidth = SCREEN_WIDTH;
    _previewLayerHeight = _previewLayerWidth * 0.75;
    
    self.view.backgroundColor = [UIColor redColor];
    
    self.videoView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, 2 * SCREEN_HEIGHT / 4)];
    [self.view addSubview:self.videoView];
    
    self.showInfoView = [[UIView alloc] initWithFrame:CGRectMake(0, self.videoView.frame.size.height, SCREEN_WIDTH, SCREEN_HEIGHT - self.videoView.frame.size.height)];
    self.showInfoView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.showInfoView];
    
    self.finalLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 50, SCREEN_WIDTH, 200)];
    self.finalLabel.textColor = [UIColor blackColor];
    self.finalLabel.numberOfLines = 10;
    [self.showInfoView addSubview:self.finalLabel];
    
    [self setRecordingVideoModule];
    
    // 设置帧率
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        NSArray *supportedFrameRateRanges = [captureDevice.activeFormat videoSupportedFrameRateRanges];
        NSLog(@"%@", supportedFrameRateRanges);
        
        NSArray *supportedFormats = captureDevice.formats;
        for (AVCaptureDeviceFormat *newFormat in supportedFormats) {
            NSArray *array = [newFormat videoSupportedFrameRateRanges];
            for (AVFrameRateRange *range in array) {
                if (range.maxFrameRate == 240) {
                    captureDevice.activeFormat = newFormat;
                    break;
                }
            }
        }
        NSLog(@"%@", supportedFormats);
        
        captureDevice.activeVideoMaxFrameDuration = CMTimeMake(1, 10);
        captureDevice.activeVideoMinFrameDuration = CMTimeMake(1, 10);
    }];
    self.samplingCount = 0;
    self.samplingSymbolDataArray = [[NSMutableArray alloc] init];
    self.finalDataStream = @"";
    self.lastDecodedSymbol = @"";
    self.processingData = dispatch_queue_create("com.gai.processingData", DISPATCH_QUEUE_SERIAL);

    [self.captureSession startRunning];
}

// 视频模块初始化相关
- (void)setRecordingVideoModule
{
    // 存储错误
    NSError *error = nil;
    
    // 创建会话（AVCaptureSession）对象
    self.captureSession = [[AVCaptureSession alloc] init];
    
    [self.captureSession beginConfiguration];
    
    // 设置视频分辨率
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        [self.captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
    } // 注：目前测试在5，6，6s上high均为1920*1080
    
    
    // 获取一个视频输入设备（总共有两个，前／后摄像头），我们使用后摄像头
    AVCaptureDevice *videoCaptureDevice = [self getVideoDeviceWithPosition:AVCaptureDevicePositionBack];
    
    // 根据输入设备初始化设备输入对象，用于获得输入数据
    self.videoCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoCaptureDevice error:&error];
    if (error) {
        NSLog(@"videoCaptureDeviceInput error:%@",error);
    }
    
    dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("com.gai.videoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    // 初始化设备输出对象，用于获得输出数据
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    NSDictionary* setcapSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                                    nil];
    self.videoDataOutput.videoSettings = setcapSettings;
    self.videoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    
    // 将视频输入对象添加到会话中
    if ([self.captureSession canAddInput:self.videoCaptureDeviceInput]) {
        [self.captureSession addInput:self.videoCaptureDeviceInput];
    }
    
    // 将视频输出对象添加到会话中
    if ([self.captureSession canAddOutput:self.videoDataOutput]) {
        [self.captureSession addOutput:self.videoDataOutput];
    }
    

    
    // 设置视频防抖（采用自动模式）及朝向
    AVCaptureConnection *captureConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    captureConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    if ([captureConnection isVideoStabilizationSupported]) {
        captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
    }
    
    NSString *tempFileName = [NSProcessInfo processInfo].globallyUniqueString;
    self.tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[tempFileName stringByAppendingPathExtension:@"mp4"]];
    [[NSFileManager defaultManager] removeItemAtPath:self.tempFilePath error:&error];
    self.assetWriter = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:self.tempFilePath] fileType:AVFileTypeMPEG4 error:nil];
    self.videoAssetWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:[self.videoDataOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4]];
    self.videoAssetWriterInput.expectsMediaDataInRealTime = YES;
    
    if ([self.assetWriter canAddInput:self.videoAssetWriterInput]) {
        [self.assetWriter addInput:self.videoAssetWriterInput];
    }
    
    [self.captureSession commitConfiguration];
    
    // 创建相机拍摄预览图层，用于实时展示摄像头状态
    self.captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    CALayer *layer = self.videoView.layer;
    layer.masksToBounds = YES;
    self.captureVideoPreviewLayer.frame = layer.bounds;
    self.captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill; // 填充模式
    [layer addSublayer:self.captureVideoPreviewLayer];
}

// 改变设备属性的统一操作方法
- (void)changeDeviceProperty:(PropertyChangeBlock)propertyChange {
    AVCaptureDevice *videoCaptureDevice = [self.videoCaptureDeviceInput device];
    NSError *error = nil;
    //注意改变设备属性前一定要首先调用lockForConfiguration，调用完之后使用unlockForConfiguration方法解锁
    if ([videoCaptureDevice lockForConfiguration:&error]) {
        // 改变会话的配置前一定要先开启配置，配置完成后提交配置改变
        [self.captureSession beginConfiguration];
        propertyChange(videoCaptureDevice);
        [self.captureSession commitConfiguration];
        [videoCaptureDevice unlockForConfiguration];
    } else {
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

// 获取摄像头
- (AVCaptureDevice *)getVideoDeviceWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *videoDevice in devices) {
        if (videoDevice.position == position) {
            return videoDevice;
        }
    }
    return nil;
}




















- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
//    NSLog(@"%@",self.tempFilePath);
//    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//    int pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
//    switch (pixelFormat) {
//        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
//            NSLog(@"capture pixel format=kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange");
//            break;
//        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
//            NSLog(@"capture pixel format=kCVPixelFormatType_420YpCbCr8BiPlanarFullRange");
//            break;
//        default:
//            NSLog(@"capture pixel format=kCVPixelFormatType_32BGRA");
//            break;
//     }
    
    [self testGetAverageColor:sampleBuffer];
//    CGImageRef cgImage = [self imageFromSampleBufferRef:sampleBuffer];
//
//    dispatch_async(self.processingData, ^{
//        NSUInteger width = CGImageGetWidth(cgImage);
//        NSUInteger height = CGImageGetHeight(cgImage);
//        NSUInteger pixelCount = width * height;
//        NSUInteger bytesPerPixel = 4;
//        NSUInteger bytesPerRow = bytesPerPixel * width;
//        NSUInteger bitsPerComponent = 8;
//        unsigned char *rawData = (unsigned char *)malloc(height * width * 4);
//        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
//        CGContextRef context = CGBitmapContextCreate(rawData,
//                                                     width,
//                                                     height,
//                                                     bitsPerComponent,
//                                                     bytesPerRow,
//                                                     colorSpace,
//                                                     kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
//        CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
//        CGColorSpaceRelease(colorSpace);
//        CGContextRelease(context);
//        CGImageRelease(cgImage);
//        double red, green, blue;
//        for (int k = 0; k < pixelCount; k++) {
//            // Get color components as floating point value in [0,1]
//            red   += (double)rawData[k * 4 + 0] / 255.0;
//            green += (double)rawData[k * 4 + 1] / 255.0;
//            blue  += (double)rawData[k * 4 + 2] / 255.0;
//        }
//        free(rawData);
//        red   = red / pixelCount;
//        green = green / pixelCount;
//        blue  = blue / pixelCount;
//        UIColor *color = [UIColor colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:1];
//        //    NSLog(@"%@", color);
//        
//        CGPoint point = [PHUtilities calculateXY:color forModel:@"LCT001"];
//        NSLog(@"%@", NSStringFromCGPoint(point));
//    });

    
    
    
    
    
    
    
    
    
//    UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
//    UIColor *color = [self averageColorForImage:image];
//    NSLog(@"%@",color);

//    NSLog(@"out");

}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
//    [self testGetAverageColor:sampleBuffer];

    if (self.samplingCount == SAMPLINGRATE) {
        self.samplingCount = 0;
    }
    self.samplingCount ++;
    NSLog(@"drop");
}

- (void)testGetAverageColor:(CMSampleBufferRef)sampleBuffer {
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t length = CVPixelBufferGetDataSize(imageBuffer);
    size_t pixelCount = width * height;
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    unsigned char *imageData = (unsigned char *)malloc(length);
    memcpy(imageData, baseAddress, length);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

//    CFDataRef data = CFDataCreate(NULL, imageData, length);
//    free(imageData);
//    UInt8 *aaa = CFDataGetBytePtr(data);
    __block CGFloat b=0 ,g=0 ,r=0;
    
    
    
//    NSBlockOperation *operation1 = [NSBlockOperation blockOperationWithBlock:^{
////        NSLog(@"累加 - %@", [NSThread currentThread]);
//        for (NSInteger i = 0; i < pixelCount; i ++) {
//                b += imageData[i * 4 + 0];
//                g += imageData[i * 4 + 1];
//                r += imageData[i * 4 + 2];
//        }
//    }];
//    
//    NSBlockOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
////        NSLog(@"计算   - %@", [NSThread currentThread]);
//        free(imageData);
//        
//        b = b / length / 255.0;
//        g = g / length / 255.0;
//        r = r / length / 255.0;
//        UIColor *color = [UIColor colorWithRed:r green:g blue:b alpha:1];
//        CGPoint point = [PHUtilities calculateXY:color forModel:@"LCT001"];
//        NSLog(@"%@", NSStringFromCGPoint(point));
//    }];
//    
//    [operation2 addDependency:operation1];
//    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
//    [queue addOperations:@[operation2, operation1] waitUntilFinished:YES];
//    
    
    
    
    NSInteger startCount =  0.25 * pixelCount;
    NSInteger endCount = 0.75 * pixelCount;
    NSInteger count = endCount - startCount;
    
    for (NSInteger i = startCount; i < endCount; i ++) {
        b += imageData[i * 4 + 0];
        g += imageData[i * 4 + 1];
        r += imageData[i * 4 + 2];
    }
//    free(aaa);

    free(imageData);
        
    b = b / count / 255.0;
    g = g / count / 255.0;
    r = r / count / 255.0;
    UIColor *color = [UIColor colorWithRed:r green:g blue:b alpha:1];
    CGPoint point = [PHUtilities calculateXY:color forModel:@"LCT001"];
//    NSLog(@"%@", NSStringFromCGPoint(point));
//    dispatch_async(self.processingData, ^{
        [self calculateMED:point];
//    });

//    NSLog(@"output");
}

- (void)calculateMED:(CGPoint)receviedPoint {
    NSDictionary *allConstellationPoints = [XDControlLightViewController getConstellationData];
    float minED = 100;
    NSArray *symbol = [[NSArray alloc] initWithObjects:@"00", @"01", @"10", @"11", nil];
    NSString *decodingSymbol;
    for (int i = 0; i < symbol.count; i++) {
        NSDictionary *onePoint =  [allConstellationPoints objectForKey:symbol[i]];
        CGPoint constellationPoint;
        constellationPoint.x = [[onePoint objectForKey:@"x"] floatValue];
        constellationPoint.y = [[onePoint objectForKey:@"y"] floatValue];
        float ed = hypot(constellationPoint.x - receviedPoint.x, constellationPoint.y - receviedPoint.y);
        if (ed < minED) {
            minED = ed;
            decodingSymbol = symbol[i];
        }
    }
    [self.samplingSymbolDataArray addObject:decodingSymbol];
    NSLog(@"decodingSymbol:%@", decodingSymbol);
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        self.lastDecodedSymbol = decodingSymbol;
    });
    
    if (!_syncFlag) {
        if (![self.lastDecodedSymbol isEqualToString:decodingSymbol]) {
            self.samplingCount = 0;
            _syncFlag = YES;
        }
    }
    
    
    
    
    if (self.samplingCount == SAMPLINGRATE) {
        self.samplingCount = 0;
        NSString *finalSymbol = [self chooseFinalSymbol];
        self.samplingSymbolDataArray = [[NSMutableArray alloc] init];
        NSLog(@"finalSymbol:%@", finalSymbol);
        
        if (_endFlag) {
            _startFlag = NO;
            [self.captureSession stopRunning];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.finalLabel.text = [@"解码完成，最终结果为：" stringByAppendingString:self.finalDataStream];
                NSLog(@"finalDataStream:%@", self.finalDataStream);
            });
        }
        
        if (_startFlag) {
            self.finalDataStream = [self.finalDataStream stringByAppendingString:finalSymbol];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.finalLabel.text = [@"正在解码：" stringByAppendingString:self.finalDataStream];
            });
        }


        
        if ([finalSymbol isEqualToString:@"11"]) {
            self.syncFrameCount ++;
        } else {
            self.syncFrameCount = 0;
        }
        if (_startFlag) {
            if (self.syncFrameCount == 8) {
                _endFlag = YES;
            }
        }
        if (self.syncFrameCount == 8) {
            _startFlag = YES;
            self.syncFrameCount = 0;
        }
    }
    self.samplingCount ++;
    
    self.lastDecodedSymbol = decodingSymbol;
    
}

- (NSString *)chooseFinalSymbol {
    int count_00 = 0;
    int count_01 = 0;
    int count_10 = 0;
    int count_11 = 0;
    for (NSString *symbol in self.samplingSymbolDataArray) {
        if ([symbol isEqualToString:@"00"]) {
            count_00 ++;
        }
        else if ([symbol isEqualToString:@"01"]) {
            count_01 ++;
        }
        else if ([symbol isEqualToString:@"10"]) {
            count_10 ++;
        }
        else if ([symbol isEqualToString:@"11"]) {
            count_11 ++;
        }
    }
    int maxCount = MAX(MAX(MAX(count_00, count_01), count_10), count_11);
    if (maxCount == count_00) {
        return @"00";
    } else if (maxCount == count_01) {
        return @"01";
    } else if (maxCount == count_10) {
        return @"10";
    } else {
        return @"11";
    }
}


// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}

// 捕捉视频帧，将其转换为图片
- (CGImageRef)imageFromSampleBufferRef:(CMSampleBufferRef)sampleBufferRef {
    
    // 为媒体数据设置一个CMSampleBufferRef
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBufferRef);
    // 锁定 pixel buffer 的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    // 得到 pixel buffer 的基地址
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // 得到 pixel buffer 的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到 pixel buffer 的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    // 创建一个依赖于设备的 RGB 颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphic context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    //根据这个位图 context 中的像素创建一个 Quartz image 对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁 pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    // 释放 context 和颜色空间
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    //    CVBufferRelease(imageBuffer);
    // 用 Quzetz image 创建一个 UIImage 对象
    // UIImage *image = [UIImage imageWithCGImage:quartzImage];
    // 释放 Quartz image 对象
    // CGImageRelease(quartzImage);
    return quartzImage;
    
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

//
//  OpenCVBridge.mm
//  Psylocke
//
//  Created by Xinyi Ding on 4/17/16.
//  Copyright © 2016 Xinyi. All rights reserved.
//


#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>

#include "OpenCVBridge.h"
#include "opencv2/core/core.hpp"
#include "opencv2/contrib/contrib.hpp"
#include "opencv2/highgui/highgui.hpp"
#include "opencv2/imgproc/imgproc.hpp"
#include "FisherFace.hpp"

#include <iostream>
#include <fstream>
#include <sstream>

using namespace std;
using namespace cv;


@interface OpenCVBridge()
@property FisherFace *fisher;
@end

@implementation OpenCVBridge


+ (NSString *)applicationDocumentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}


- (int) OpenCVFisherFaceClassifier: (CIFaceFeature *) faceFeature usingImage:(CIImage*)ciFrameImage
{
    int res;
    //get face bounds and copy over smaller face image as CIIMage
    CGRect faceRect = faceFeature.bounds;
    CIImage *faceImage = [ciFrameImage imageByCroppingToRect:faceRect];
    
    cv::Mat cvMat = [OpenCVBridge ciimageTocvMat:faceImage];
    cv::Mat face_resized;
    cv::Mat greyMat;
    cv::cvtColor(cvMat, greyMat, CV_BGR2GRAY);

    cv::resize(greyMat, face_resized, cv::Size(200, 200), 1.0, 1.0, INTER_CUBIC);
    res = self.fisher->getClassification(face_resized);
    
    return res;
    
}

- (CIImage*) OpenCVDrawAndReturnFaces:(CIFaceFeature *)faceFeature usingImage:(CIImage*)ciFrameImage
{
    
    cv::Mat cvMat = [OpenCVBridge ciimageTocvMat:ciFrameImage];

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    
    //get face bounds and copy over smaller face image as CIIMage
    CGRect faceRect = faceFeature.bounds;
    cv::Mat faceGray;
    cv::Mat face;
    cv::Rect cvct = cv::Rect(faceRect.origin.x, faceRect.origin.y, faceRect.size.width, faceRect.size.height);
    
    cv::rectangle(cvMat, cvct, cv::Scalar(0,255,0));
    //cv::putText(cvMat, "hello face",cvPoint(30 , 30), FONT_HERSHEY_COMPLEX_SMALL, 1.5, cv::Scalar(0,255,0));
    
    
    // convert back
    // setup NS byte buffer using the data from the cvMat to show
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize() * cvMat.total()];
    
    
    // setup buffering object
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // setup the copy to go from CPU to GPU
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                     // Width
                                        cvMat.rows,                                     // Height
                                        8,                                              // Bits per component
                                        8 * cvMat.elemSize(),                           // Bits per pixel
                                        cvMat.step[0],                                  // Bytes per row
                                        colorSpace,                                     // Colorspace
                                        kCGImageAlphaNone | kCGBitmapByteOrderDefault,  // Bitmap info flags
                                        provider,                                       // CGDataProviderRef
                                        NULL,                                           // Decode
                                        false,                                          // Should interpolate
                                        kCGRenderingIntentDefault);                     // Intent
    // do the copy inside of the object instantiation for retImage
    CIImage* retImage = [[CIImage alloc]initWithCGImage:imageRef];
    
    // clean up
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return retImage;
}

+ (cv::Mat)cvMatWithImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC1); // 8 bits per component, 4 channels, CV_8UC1 for grayscale ?
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to backing data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNone); // Bitmap info flags , kCGImageAlphaNone for grayscale?
    

    
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

+ (cv::Mat)ciimageTocvMat: (CIImage *) image
{
    CIContext *context =  [CIContext contextWithCGContext:nil options: nil];
    CGImageRef imageCG = [context createCGImage:image fromRect:image.extent];
    
    // setup the OPenCV mat fro copying into
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(imageCG);
    CGFloat cols = image.extent.size.width;
    CGFloat rows = image.extent.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4);
    
    // setup the copy buffer (to copy from the GPU)
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to backing data
                                                    cols,                      // Width of bitmap
                                                    rows,                     // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    // do the copy
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), imageCG);
    
    // release intermediary buffer objects
    CGContextRelease(contextRef);
    CGImageRelease(imageCG);
    
    return cvMat;
}

- (float *) trainData {
   
    self.fisher = new FisherFace();
    NSString* haar = [[NSBundle mainBundle] pathForResource:@"haarcascade_frontalface_default" ofType:@"xml"];
    NSLog(@"%@", haar);
    
    std::string bar = std::string([haar UTF8String]);
    CascadeClassifier face_cascade;
    if (!face_cascade.load(bar))
        printf("--(!)Error loading\n");
    
    cv::vector<cv::Rect> faces;
    
    vector<Mat> images;
    vector<int> labels;
    
    NSArray *emotions = @[@"normal", @"happy", @"sad",
                          @"surprised", @"sleepy", @"wink"];
    
    
    for (int i = 1; i <= 15; i++) {
        for (int j = 0; j < 6; j ++) {
            NSString * fileParh =[NSString stringWithFormat:@"yalefaces/subject%02d.%@.png", i, emotions[j]];
            UIImage *curImage = [UIImage imageNamed:fileParh];
            cv::Mat cvimg = [OpenCVBridge cvMatWithImage: curImage ];
            
            face_cascade.detectMultiScale(cvimg, faces);
            
            if (faces.size() > 0) {
                cv::Mat roi = cv::Mat(cvimg, faces[0]);
                cv::Mat face_resized;
                cv::resize(roi, face_resized, cv::Size(200, 200), 1.0, 1.0, INTER_CUBIC);
                
                images.push_back(face_resized);
                labels.push_back(j);
                
            }
        }
    }
    cv::Mat eigenValues = self.fisher->train(images, labels);
    
    static float r[5];
    for (int i = 0; i < 5; i++)
        r[i] = eigenValues.at<double>(i);
    return r;
}

@end



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
    
    CIContext *context =  [CIContext contextWithCGContext:nil options: nil];
    CGImageRef faceImageCG = [context createCGImage:faceImage fromRect:faceRect];
    
    // setup the OPenCV mat fro copying into
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(faceImageCG);
    CGFloat cols = faceRect.size.width;
    CGFloat rows = faceRect.size.height;
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    
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
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), faceImageCG);
    
    // release intermediary buffer objects
    CGContextRelease(contextRef);
    CGImageRelease(faceImageCG);
    
    
    cv::Mat face_resized;
    cv::Mat greyMat;
    cv::cvtColor(cvMat, greyMat, CV_BGR2GRAY);

    cv::resize(greyMat, face_resized, cv::Size(200, 200), 1.0, 1.0, INTER_CUBIC);
    res = self.fisher->getClassification(face_resized);
    
    return res;
    
}

+ (cv::Mat)cvMatWithImage:(UIImage *)image
{
    
    // CIContext * context = [CIContext contextWithCGContext:nil options: nil];
    
    //CIImage * faceImage = image.CIImage;
    //CGRect faceRect = [faceImage extent];
    //CGImageRef faceImageCG = [context createCGImage: faceImage fromRect: faceRect];
    
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


- (void) trainData {
    
    //UIImage *myImage1 = [UIImage imageNamed:@"yalefaces/subject01.gif.png"];
    //UIImage *myImage = [UIImage imageNamed:@"yalefaces/subject01.happy.png"];
    
    
    //NSString *docPath = [self applicationDocumentsDirectory];
    
    //NSString *face_cascade_name = [docPath stringByAppendingString:@"/haarcascade_frontalface_default.xml"];
    
    //NSLog(@"%@", face_cascade_name);
    
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
            cv::Mat cvimg = [OpenCVBridge cvMatWithImage: curImage];
            
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
    self.fisher->train(images, labels);
}

//- (int) oneUglySolution:(CIFaceFeature *) faceFeature usingImage:(CIImage*)ciFrameImage {
//
//    int res;
//    //get face bounds and copy over smaller face image as CIIMage
//    CGRect faceRect = faceFeature.bounds;
//    CIImage *faceImage = [ciFrameImage imageByCroppingToRect:faceRect];
//    
//    CIContext *context =  [CIContext contextWithCGContext:nil options: nil];
//    CGImageRef faceImageCG = [context createCGImage:faceImage fromRect:faceRect];
//    
//    // setup the OPenCV mat fro copying into
//    CGColorSpaceRef colorSpace = CGImageGetColorSpace(faceImageCG);
//    CGFloat cols = faceRect.size.width;
//    CGFloat rows = faceRect.size.height;
//    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
//    
//    // setup the copy buffer (to copy from the GPU)
//    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to backing data
//                                                    cols,                      // Width of bitmap
//                                                    rows,                     // Height of bitmap
//                                                    8,                          // Bits per component
//                                                    cvMat.step[0],              // Bytes per row
//                                                    colorSpace,                 // Colorspace
//                                                    kCGImageAlphaNoneSkipLast |
//                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
//    // do the copy
//    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), faceImageCG);
//    
//    // release intermediary buffer objects
//    CGContextRelease(contextRef);
//    CGImageRelease(faceImageCG);
//    
//    
//    cv::Mat predict_face;
//    cv::Mat greyMat;
//    cv::cvtColor(cvMat, greyMat, CV_BGR2GRAY);
//    cv::resize(greyMat, predict_face, cv::Size(200, 200), 1.0, 1.0, INTER_CUBIC);
//    
//    
//    //Train data
//    
//    NSString* haar = [[NSBundle mainBundle] pathForResource:@"haarcascade_frontalface_default" ofType:@"xml"];
//    
//    NSLog(@"%@", haar);
//    
//    std::string bar = std::string([haar UTF8String]);
//    CascadeClassifier face_cascade;
//    if (!face_cascade.load(bar))
//        printf("--(!)Error loading\n");
//    
//    cv::vector<cv::Rect> faces;
//    
//    vector<Mat> images;
//    vector<int> labels;
//    
//    NSArray *emotions = @[@"normal", @"happy", @"sad",
//                          @"surprised", @"sleepy", @"wink"];
//    
//    
//    for (int i = 1; i <= 15; i++) {
//        for (int j = 0; j < 6; j ++) {
//            NSString * fileParh =[NSString stringWithFormat:@"yalefaces/subject%02d.%@.png", i, emotions[j]];
//            UIImage *curImage = [UIImage imageNamed:fileParh];
//            cv::Mat cvimg = [OpenCVBridge cvMatWithImage: curImage];
//            
//            face_cascade.detectMultiScale(cvimg, faces);
//            
//            if (faces.size() > 0) {
//                cv::Mat roi = cv::Mat(cvimg, faces[0]);
//                cv::Mat face_resized;
//                cv::resize(roi, face_resized, cv::Size(200, 200), 1.0, 1.0, INTER_CUBIC);
//                
//                images.push_back(face_resized);
//                labels.push_back(j);
//                
//            }
//        }
//    }
//
//    
//    
//    
//    res = self.fisher->uglySolution(images, labels, predict_face);
//    
//    return res;
//
//}

@end



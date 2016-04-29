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
    
   // CGRect faceRect = faceFeature.bounds;
   // CIImage *faceImage = [ciFrameImage imageByCroppingToRect:faceRect];
    
    //Rotate and get the cropped face image
    CIImage *faceImage = [OpenCVBridge rotateAndCrop:ciFrameImage];
    cv::Mat cvMat = [OpenCVBridge ciimageTocvMat:faceImage];
    cv::Mat face_resized;
    cv::Mat greyMat;
    cv::cvtColor(cvMat, greyMat, CV_BGR2GRAY);

    cv::resize(greyMat, face_resized, cv::Size(200, 200), 1.0, 1.0, INTER_CUBIC);
    res = self.fisher->getClassification(face_resized);
    
    return res;
    
}

+ (CIImage *) rotateAndCrop: (CIImage *) ciFrameImage
{
    
    CGFloat x = 438;
    CGFloat y = 608;
    CGFloat x2 = 612;
    CGFloat y2 = 666;
//    These codes are just for testing
//    NSString * fileParh =[NSString stringWithFormat:@"test.png"];
//    UIImage *curImage = [UIImage imageNamed:fileParh];
//    
//    CIImage* coreImage = curImage.CIImage;
//    
//    if (!coreImage) {
//        NSLog(@"init from CG");
//        coreImage = [CIImage imageWithCGImage:curImage.CGImage];
//    }
//    
//    if (!coreImage) {
//        NSLog(@"error !");
//    }
    
    // Need to cloclwise 90 degree of the incoming ciframeImage and also keep the origin at (0,0) otherwise, there will be issues finding eye position!
    // I don't know why do the following transform, but it works, figure this out later!
    CGAffineTransform transform2 = CGAffineTransformMakeTranslation(0,  1280);
    transform2 = CGAffineTransformRotate(transform2, -(90.0 / 180) * M_PI);
    transform2 = CGAffineTransformTranslate(transform2,0,0);
    
//    CGAffineTransform transform2 = CGAffineTransformMakeRotation(M_PI_2);
//    transform2 = CGAffineTransformScale(transform2, -1, 1);
    
    CIImage * adjustedciFrameImage = [ciFrameImage imageByApplyingTransform:transform2];

    NSLog(@"print shape %f, %f, %f, %f", adjustedciFrameImage.extent.origin.x, adjustedciFrameImage.extent.origin.y, adjustedciFrameImage.extent.size.width, adjustedciFrameImage.extent.size.height);
    

    
    CIDetector* detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:nil options:[NSDictionary dictionaryWithObject:CIDetectorAccuracyHigh forKey:CIDetectorAccuracy]];
    
    NSArray* features = [detector featuresInImage:adjustedciFrameImage];
    
    for(CIFaceFeature* faceObject in features)
    {
        if(faceObject.hasLeftEyePosition)
        {
            NSLog(@"left eye position %f, %f", faceObject.leftEyePosition.x, faceObject.leftEyePosition.y);
            x = faceObject.leftEyePosition.x;
            y = 1280 - faceObject.leftEyePosition.y;
        }
        if(faceObject.hasRightEyePosition)
        {
            NSLog(@"right eye position %f, %f", faceObject.rightEyePosition.x, faceObject.rightEyePosition.y);
            x2 = faceObject.rightEyePosition.x;
            y2 =1280 - faceObject.rightEyePosition.y;
        }
        
    }

    int dest_height = 200;
    int dest_width = 200;
    float offset_pct = 0.25;
    
    float offset_h = floor(offset_pct * dest_width);
    float offset_v = floor(offset_pct * dest_height);
    
    //Get eye direction
    float direct_x = x2 - x;
    float direct_y = y2 - y;
    
    //Calc rotation angle in radians
    CGFloat rads = atan2(direct_y, direct_x);
    rads = 0;
    
    //Calculate the distance between two eyes
    float dist = sqrt(pow((x2 - x), 2) + pow((y2 - y),2));
    
    float reference = dest_width - 2.0 * offset_h;
    float scale = dist / reference;
    
    float crop_x = x - scale * offset_h;
    float crop_y = y - scale * offset_v;
    
    float crop_size_h = scale * dest_height;
    float crop_size_w = scale * dest_width;
    
    CGRect rect = CGRectMake(crop_x, crop_y, crop_size_w , crop_size_h);
    

    CGAffineTransform transform = CGAffineTransformMake(cos(rads),sin(rads),-sin(rads),cos(rads),x-x*cos(rads)+y*sin(rads),y-x*sin(rads)-y*cos(rads));
//    The above one line transform can also be implemented using the following three!
//    CGAffineTransform transform = CGAffineTransformMakeTranslation(x, y);
//    transform = CGAffineTransformRotate(transform, a);
//    transform = CGAffineTransformTranslate(transform,-x,-y);
    
    
    CIImage *alignedImage = [adjustedciFrameImage imageByApplyingTransform:transform];
    
    // Convert back to UIImage
    CIContext *context = [CIContext contextWithOptions:nil];
    //CGRect rrcct = alignedImage.extent;
    CGRect coreRect = ciFrameImage.extent;
    CGRect adjustedRect = CGRectMake(0 , 0, adjustedciFrameImage.extent.size.width, adjustedciFrameImage.extent.size.height);
    CGImage * cgImage = [context createCGImage:alignedImage fromRect: adjustedRect]; //Do not use rrcct here!! it is rotated!!
   
    
    CGImageRef imageRef = CGImageCreateWithImageInRect(cgImage, rect);
    
    UIImage *u = [UIImage imageWithCGImage: imageRef];
    
    CGImageRelease(imageRef);
    //UIImage *uiImage = [[UIImage alloc] initWithCIImage:alignedImage];    // This is not working, interesting!
    
    
//  
//    UIImageWriteToSavedPhotosAlbum(u,
//                                   self,
//                                   @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:),
//                                   nil);
    if (!u.CIImage) {
        NSLog(@"CIImage is nil");
        CIImage * retImage  = [CIImage imageWithCGImage: imageRef];
        return retImage;
        
    } else {
        return u.CIImage;
    }
}

- (void)thisImage:(UIImage *)image hasBeenSavedInPhotoAlbumWithError:(NSError *)error usingContextInfo:(void*)ctxInfo {
    if (error) {
        NSLog(@"whaaaaaat!");
        // Do anything needed to handle the error or display it to the user
    } else {
        NSLog(@"successfully saved");
        // .... do anything you want here to handle
        // .... when the image has been saved in the photo album
    }
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

+ (cv::Mat)cvMatWithImageCustome:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels, CV_8UC1 for grayscale ?
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to backing data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags , kCGImageAlphaNone for grayscale?
    
    
    
    
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

- (float *) customTrain {
    
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
    
    NSArray *emotions = @[@"netrual", @"happy", @"sad",
                          @"surprised", @"sleepy", @"angry"];
    
    
    for (int i = 0; i < 6; i++) {
        for (int j = 1; j <= 5; j++) {
            NSString * fileParh =[NSString stringWithFormat:@"xinyiface/%@_%d.png", emotions[i], j];
            UIImage *curImage = [UIImage imageNamed:fileParh];
            cv::Mat cvimg = [OpenCVBridge cvMatWithImageCustome: curImage ];
            
            cv::Mat greyMat;
            cv::cvtColor(cvimg, greyMat, CV_BGR2GRAY);
            
            cv::Mat face_resized;
            cv::resize(greyMat, face_resized, cv::Size(200, 200), 1.0, 1.0, INTER_CUBIC);
                
            images.push_back(face_resized);
            labels.push_back(i);
            
//            face_cascade.detectMultiScale(cvimg, faces);
//            
//            if (faces.size() > 0) {
//                cv::Mat roi = cv::Mat(cvimg, faces[0]);
//                
//                cv::Mat greyMat;
//                cv::cvtColor(roi, greyMat, CV_BGR2GRAY);
//                
//                cv::Mat face_resized;
//                cv::resize(greyMat, face_resized, cv::Size(200, 200), 1.0, 1.0, INTER_CUBIC);
//                
//                images.push_back(face_resized);
//                labels.push_back(i);
//                
//            }

        }
    }
    cv::Mat eigenValues = self.fisher->train(images, labels);
    
    static float r[5];
    for (int i = 0; i < 5; i++)
        r[i] = eigenValues.at<double>(i);
    return r;
}

@end



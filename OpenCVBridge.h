//
//  fisherFace.h
//  Psylocke
//
//  Created by Xinyi Ding on 4/17/16.
//  Copyright © 2016 Xinyi. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>


@interface OpenCVBridge : NSObject

- (int) OpenCVFisherFaceClassifier: (CIFaceFeature *) faceFeature usingImage:(CIImage*)ciFrameImage;

- (CIImage*) OpenCVDrawAndReturnFaces:(CIFaceFeature *)faceFeature usingImage:(CIImage*)ciFrameImage;

- (float *) trainData;


@end
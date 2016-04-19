//
//  FisherFace.cpp
//  Psylocke
//
//  Created by Xinyi Ding on 4/18/16.
//  Copyright © 2016 Xinyi. All rights reserved.
//

#include "FisherFace.hpp"


using namespace cv;
using namespace std;


FisherFace::FisherFace() {
    printf("init");
}
FisherFace::~FisherFace() {}


void FisherFace::train(vector<Mat>& images, vector<int>& labels) {
    Mat testSample = images[images.size() - 1];
    int testLabel = labels[labels.size() - 1];
    images.pop_back();
    labels.pop_back();
  
    
    
    
    //model_orig = (Ptr<FaceRecognizer>) model;
    model->train(images, labels);

    int predictedLabel = model->predict(testSample);
    
    printf("%d\n",predictedLabel);
    printf("%d\n", testLabel);
    
}

int FisherFace::getClassification(Mat& m) {
    
    int res = -1;
    res = model->predict(m);
    printf("Get predicted res: %d", res);
    return res;
}

//int FisherFace::uglySolution(vector<Mat>& images, vector<int>& labels, Mat& m) {
//    printf("in training and predict");
//    Mat mm = m;
//    int res = -1;
//    Ptr<FaceRecognizer> model = createFisherFaceRecognizer();
//    model->train(images, labels);
//    res = model->predict(m);
//    printf("predict res is %d", res);
//    return res;
//}
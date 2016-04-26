//
//  FisherFace.hpp
//  Psylocke
//
//  Created by Xinyi Ding on 4/18/16.
//  Copyright © 2016 Xinyi. All rights reserved.
//

#ifndef FisherFace_hpp
#define FisherFace_hpp

#include <stdio.h>

#endif /* FisherFace_hpp */



#include "opencv2/core/core.hpp"
#include "opencv2/contrib/contrib.hpp"
#include "opencv2/highgui/highgui.hpp"
#include "opencv2/imgproc/imgproc.hpp"

#include <iostream>



using namespace cv;
using namespace std;

class FisherFace {
   
    
    
public: FisherFace();
    ~FisherFace();
    
    
public:
    int testDo;

    Mat train(vector<Mat>& images, vector<int>& labels);
    int getClassification( Mat& m);
    //int uglySolution(vector<Mat>& images, vector<int>& labels, Mat& m);
    
private:
    Ptr<FaceRecognizer> model = createFisherFaceRecognizer();
    double testValue;
    static const int i = 10;
    
};


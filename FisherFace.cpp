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


Mat FisherFace::train(vector<Mat>& images, vector<int>& labels) {
    Mat testSample = images[images.size() - 1];
    int testLabel = labels[labels.size() - 1];
//    images.pop_back();
//    labels.pop_back();
//    
//    images.pop_back();
//    labels.pop_back();
    
  
    int blabla;
    //crossValidate(images, labels);
    model->train(images, labels);

    int predictedLabel = model->predict(testSample);
    printf("%d\n",predictedLabel);
    printf("%d\n", testLabel);
    
    Mat eigenValues = model->getMat("eigenvalues");
    return eigenValues;
    
}

void shuffleArray(int* array,int size)
{
    int n = size;
    while (n > 1)
    {
        // 0 <= k < n.
        int k = rand()%n;
        
        // n is now the last pertinent index;
        n--;
        // swap array[n] with array[k]
        int temp = array[n];
        array[n] = array[k];
        array[k] = temp;
    }
}


double FisherFace::crossValidate(vector<Mat>& images, vector<int>& labels) {
    //totally 88 images
    int vSize = images.size();
    //
    int k = 5;
    vector<Mat> train;
    vector<Mat> test;
    vector<int> trainLabel;
    vector<int> testLabel;
    int indices[vSize];
    for (int j=0; j < vSize; j++) {
        indices[j] = j;
    }
    shuffleArray(indices, vSize);
    int totalCorrect = 0;
    int incorrect = 0;
    double accuracy = 1.0;
    //8 Fold cross validation
    for (int i = 0; i < k; i++) {
        //Get testing data
        int j;
        for (j = i * k; j < i * k + k; j++) {
            test.push_back(images[indices[j]]);
            testLabel.push_back(labels[indices[j]]);
        }
        //Get training data
        for (int g = 0; g < vSize - k; g++ ) {
            train.push_back(images[indices[(j+g) % vSize]]);
            trainLabel.push_back(labels[indices[(j + g) % vSize]]);
        }
        model->train(train, trainLabel);
        for (int t=0; t < k; t++) {
            int predicted = model->predict(test[t]);
            int realLabel = testLabel[t];
            if (realLabel == predicted) {
                totalCorrect++;
            } else {
                incorrect++;
            }
            printf("Get predict label %d and realLabel %d\n", predicted, realLabel);
        }
        train.clear();
        test.clear();
        trainLabel.clear();
        testLabel.clear();
    }
    accuracy = totalCorrect / (float)(totalCorrect + incorrect);
    printf("The overall accuracy is : %f", accuracy);
    return accuracy;
}

int FisherFace::getClassification(Mat& m) {
    
    int res = -1;
    res = model->predict(m);
    printf("Get predicted res: %d", res);
    Mat eigenValues = model->getMat("eigenvalues");
    Mat eigenVectors = model->getMat("eigenvectors");
    for (int i = 0; i < min(16, eigenVectors.cols); i++) {
        string msg = format("Eigenvalue #%d = %.5f", i, eigenValues.at<double>(i));
        cout << msg <<endl;
    }
    return res;
}

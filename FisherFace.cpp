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
    images.pop_back();
    labels.pop_back();
    
    images.pop_back();
    labels.pop_back();
    
  
    int blabla;
    crossValidate(images, labels);
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
    int k = 8;
    vector<Mat> train;
    vector<Mat> test;
    vector<int> trainLabel;
    vector<int> testLabel;
    int indices[88];
    for (int j=0; j < 88; j++) {
        indices[j] = j;
    }
    shuffleArray(indices, 88);
    int totalCorrect = 0;
    double accuracy = 1.0;
    //8 Fold cross validation
    for (int i = 0; i < 8; i++) {
        //Get testing data
        int j;
        for (j = i * k; j < i * k + 8; j++) {
            test.push_back(images[indices[j]]);
            testLabel.push_back(labels[indices[j]]);
        }
        //Get training data
        for (int g = 0; g < 80; g++ ) {
            train.push_back(images[indices[(j+g) % 88]]);
            trainLabel.push_back(labels[indices[(j + g) % 88]]);
        }
        model->train(train, trainLabel);
        for (int t=0; t < 8; t++) {
            int predicted = model->predict(test[t]);
            int realLabel = testLabel[t];
            if (realLabel == predicted) {
                totalCorrect++;
            }
            printf("Get predict label %d and realLabel %d\n", predicted, realLabel);
        }
        train.clear();
        test.clear();
        trainLabel.clear();
        testLabel.clear();
    }
    accuracy = totalCorrect / 88.0;
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

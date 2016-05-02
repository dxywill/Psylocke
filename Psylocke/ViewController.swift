//
//  ViewController.swift
//  Psylocke
//
//  Created by Xinyi Ding on 3/12/16.
//  Copyright © 2016 Xinyi. All rights reserved.
//

import UIKit
import AVFoundation


class ViewController: UIViewController {

    private var psylocke : Psylocke?
    let dataLabel : UILabel = UILabel(frame: CGRectMake(10, 30, 300, 20))
    let eigen_0 : UILabel = UILabel(frame: CGRectMake(10, 50, 300, 20))
    let eigen_1 : UILabel = UILabel(frame: CGRectMake(10, 70, 300, 20))
    let eigen_2 : UILabel = UILabel(frame: CGRectMake(10, 90, 300, 20))
    let eigen_3 : UILabel = UILabel(frame: CGRectMake(10, 110, 300, 20))
    let eigen_4 : UILabel = UILabel(frame: CGRectMake(10, 130, 300, 20))
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
        var faceDetectorOptions : [String : AnyObject]?
        faceDetectorOptions = [CIDetectorAccuracy : CIDetectorAccuracyHigh]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: faceDetectorOptions)

        let opencvBridge = OpenCVBridge()
        opencvBridge.uploadImages()
        
        
        let eigenValues = opencvBridge.trainData()
        
        self.psylocke = Psylocke(cameraPosition: Psylocke.CameraDevice.FaceTimeCamera, optimizeFor: Psylocke.DetectorAccuracy.HigherPerformance)
        
        
        self.psylocke?.setProcessingBlock({ (imageInput) -> (CIImage) in
            
            // this ungodly mess makes sure the image is the correct orientation
            //var optsFace = [CIDetectorImageOrientation:self.videoManager.getImageOrientationFromUIOrientation(UIApplication.sharedApplication().statusBarOrientation)]
            
            // get the face features
            let options = [CIDetectorSmile: true, CIDetectorEyeBlink: true, CIDetectorImageOrientation : 6]
            var features = faceDetector.featuresInImage(imageInput, options: options) as! [CIFaceFeature]
            //var filterCenter = CGPoint()
            var retClass = -1
            
            // do some processing in core image and in OpenCV
            for f in features {
                // this is a blocking call
                if (f.hasLeftEyePosition && f.hasRightEyePosition) {
                    print("print eye position:" + String(f.leftEyePosition.x) + ", " + String(f.leftEyePosition.y) + "," + String(f.rightEyePosition.x) + "," + String(f.rightEyePosition.y))
                    
                    retClass = Int(opencvBridge.OpenCVFisherFaceClassifier(f, usingImage: imageInput))
                    let retEmo = self.numberToEmo(retClass)
                    //update label
                    dispatch_async(dispatch_get_main_queue(), {
                        //perform all UI stuff here
                        self.dataLabel.text = "The detected emotion:" + retEmo
                        //self.dataLabel.font = self.dataLabel.font.fontWithSize(30)
                    })
                    return opencvBridge.OpenCVDrawAndReturnFaces(f, usingImage: imageInput)
                }
                
            }
            return imageInput
        })
        
        psylocke?.beginFaceDetection()
        
        let cameraView = psylocke!.psylockeCameraView
        self.view.addSubview(cameraView)
        dataLabel.text = "hello face"
        dataLabel.textColor = UIColor.greenColor()
        eigen_0.text = "Eigenvalue #0 = :" + String(eigenValues[0])
        eigen_0.textColor = UIColor.greenColor()
        eigen_1.text = "Eigenvalue #1 = :" + String(eigenValues[1])
        eigen_1.textColor = UIColor.greenColor()
        eigen_2.text = "Eigenvalue #2 = :" + String(eigenValues[2])
        eigen_2.textColor = UIColor.greenColor()
        eigen_3.text = "Eigenvalue #3 = :" + String(eigenValues[3])
        eigen_3.textColor = UIColor.greenColor()
        eigen_4.text = "Eigenvalue #4 = :" + String(eigenValues[4])
        eigen_4.textColor = UIColor.greenColor()
        self.view.addSubview(dataLabel)
        self.view.addSubview(eigen_0)
        self.view.addSubview(eigen_1)
        self.view.addSubview(eigen_2)
        self.view.addSubview(eigen_3)
        self.view.addSubview(eigen_4)
        
    }
    
    func numberToEmo(num: Int) -> String {
        switch num {
        case 0:
            return "Netraul"
        case 1:
            return "Happy"
        case 2:
            return "Sad"
        case 3:
            return "Surprised"
        case 4:
            return "Sleepy"
        case 5:
            return "Wink"
        default:
            return "Netural"
        }
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}


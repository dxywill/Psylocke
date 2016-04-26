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
    let dataLabel : UILabel = UILabel(frame: CGRectMake(30, 30, 300, 20))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
        var faceDetectorOptions : [String : AnyObject]?
        faceDetectorOptions = [CIDetectorAccuracy : CIDetectorAccuracyHigh]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: faceDetectorOptions)

        let opencvBridge = OpenCVBridge()
        opencvBridge.trainData()
        
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
                retClass = Int(opencvBridge.OpenCVFisherFaceClassifier(f, usingImage: imageInput))
                //update label
                dispatch_async(dispatch_get_main_queue(), {
                    //perform all UI stuff here
                    self.dataLabel.text = String(retClass)
                    self.dataLabel.font = self.dataLabel.font.fontWithSize(30)
                })
                return opencvBridge.OpenCVDrawAndReturnFaces(f, usingImage: imageInput)
            }
            return imageInput
        })
        
        psylocke?.beginFaceDetection()
        
        let cameraView = psylocke!.psylockeCameraView
        self.view.addSubview(cameraView)
        dataLabel.text = "hello world"
        self.view.addSubview(dataLabel)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}


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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.psylocke = Psylocke(cameraPosition: Psylocke.CameraDevice.FaceTimeCamera, optimizeFor: Psylocke.DetectorAccuracy.HigherPerformance)
        
        psylocke?.beginFaceDetection()
        
        let cameraView = psylocke!.psylockeCameraView
        self.view.addSubview(cameraView)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}


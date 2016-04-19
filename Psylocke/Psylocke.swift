//
//  Psylocke.swift
//  Psylocke
//
//  Created by Xinyi Ding on 3/14/16.
//  Copyright © 2016 Xinyi. All rights reserved.
//

import UIKit
import AVFoundation
import ImageIO
import CoreImage


typealias ProcessBlock = ( imageInput : CIImage ) -> (CIImage)

class Psylocke: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    enum DetectorAccuracy {
        case BatterySaving
        case HigherPerformance
    }
    
    enum CameraDevice {
        case ISightCamera
        case FaceTimeCamera
    }
    
    private var processBlock: ProcessBlock? = nil
    private var faceDetector : CIDetector?
    private var captureSession : AVCaptureSession = AVCaptureSession()
    private var captureDevice : AVCaptureDevice!
    private var deviceInput : AVCaptureDeviceInput?
    private var videoDataOutput : AVCaptureVideoDataOutput?
    private var videoDataOutputQueue : dispatch_queue_t?
    private var cameraPreviewLayer : AVCaptureVideoPreviewLayer?


    var psylockeCameraView : UIView = UIView()
    
    init(cameraPosition : CameraDevice, optimizeFor : DetectorAccuracy) {
        super.init()
        var faceDetectorOptions : [String : AnyObject]?
        self.captureSetup(AVCaptureDevicePosition.Front)
        
        faceDetectorOptions = [CIDetectorAccuracy : CIDetectorAccuracyHigh]
        self.faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: faceDetectorOptions)
    }
    
    func setProcessingBlock(newProcessBlock: ProcessBlock) {
        
        self.processBlock = newProcessBlock
    }
    
    func beginFaceDetection() {
        self.captureSession.startRunning()
    }
    
    func stopFaceDetection() {
        self.captureSession.stopRunning()
    }
    
    func captureSetup (position: AVCaptureDevicePosition) {
        var captureError : NSError?
        
        for device in AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) {
            if (device.position == position) {
                self.captureDevice = device as! AVCaptureDevice
                print("camera set up!")
            }
        }
        
        if (captureDevice == nil) {
            print("setup device error, using the default device")
            self.captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        }
        
        do {
            self.deviceInput = try AVCaptureDeviceInput(device: self.captureDevice)
        } catch let error as NSError {
            captureError = error
            self.deviceInput = nil
        }
        
        self.captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        if (captureError == nil) {
            if (self.captureSession.canAddInput(self.deviceInput)) {
                captureSession.addInput(self.deviceInput)
                print("add input")
            }
            self.videoDataOutput = AVCaptureVideoDataOutput()
            self.videoDataOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)]
            self.videoDataOutput!.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL)
            self.videoDataOutput!.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue!)
            
            if (self.captureSession.canAddOutput(self.videoDataOutput)) {
                self.captureSession.addOutput(self.videoDataOutput)
                print("add output")
            }
            
            self.psylockeCameraView.frame = UIScreen.mainScreen().bounds
            self.cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            self.cameraPreviewLayer!.frame = UIScreen.mainScreen().bounds
            self.psylockeCameraView.layer.addSublayer(self.cameraPreviewLayer!)
        }
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        print("in capture output")
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let opaqueBuffer = Unmanaged<CVImageBuffer>.passUnretained(imageBuffer!).toOpaque()
        let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(opaqueBuffer).takeUnretainedValue()
        let sourceImage = CIImage(CVPixelBuffer: pixelBuffer, options:nil)
        
        
        // run through a filter
        var filteredImage:CIImage! = nil;
        
        if(self.processBlock != nil){
            print("procesBlock detected, doing")
            filteredImage=self.processBlock!(imageInput: sourceImage)
        }
        
        let options = [CIDetectorSmile: true, CIDetectorEyeBlink: true, CIDetectorImageOrientation : 6]
        
        let features = self.faceDetector!.featuresInImage(sourceImage, options: options)
        
        if (features.count != 0) {
            print("detected faces")
            for feature in features as! [CIFaceFeature] {
                if (feature.hasSmile) {
                    print("Smile")
                }
                if (feature.leftEyeClosed) {
                    print("left eye closed")
                }
                if (feature.rightEyeClosed) {
                    print("right eye closed")
                }
            }
        } else {
            print("no face detected")
        }
    }
    
 }
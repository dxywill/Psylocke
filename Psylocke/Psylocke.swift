//
//  Psylocke.swift
//  Psylocke
//
//  Created by Xinyi Ding on 3/14/16.
//  Copyright © 2016 Xinyi. All rights reserved.
//

import UIKit
import GLKit
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
    
    private var window:UIWindow!
    private var videoPreviewView:GLKView!
    private var _eaglContext:EAGLContext!
    private var ciContext:CIContext!
    private var videoPreviewViewBounds:CGRect!
    private var processBlock: ProcessBlock? = nil
    private var faceDetector : CIDetector?
    private var captureSession : AVCaptureSession = AVCaptureSession()
    private var captureDevice : AVCaptureDevice!
    private var deviceInput : AVCaptureDeviceInput?
    private var videoDataOutput : AVCaptureVideoDataOutput?
    private var videoDataOutputQueue : dispatch_queue_t?
    //private var cameraPreviewLayer : AVCaptureVideoPreviewLayer?


    var psylockeCameraView : UIView = UIView()
    
    init(cameraPosition : CameraDevice, optimizeFor : DetectorAccuracy) {
        
        super.init()
        self.window = ((UIApplication.sharedApplication().delegate?.window)!)!
        _eaglContext = EAGLContext(API: EAGLRenderingAPI.OpenGLES2)
        var faceDetectorOptions : [String : AnyObject]?
        self.captureSetup(AVCaptureDevicePosition.Front)
        if _eaglContext != nil{
            videoPreviewView = GLKView(frame: window.bounds, context: _eaglContext)
            videoPreviewView.enableSetNeedsDisplay = false
            
            // because the native video image from the back camera is in UIDeviceOrientationLandscapeLeft (i.e. the home button is on the right), we need to apply a clockwise 90 degree transform so that we can draw the video preview as if we were in a landscape-oriented view; if you're using the front camera and you want to have a mirrored preview (so that the user is seeing themselves in the mirror), you need to apply an additional horizontal flip (by concatenating CGAffineTransformMakeScale(-1.0, 1.0) to the rotation transform)
            
            var transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
           // if devicePosition == AVCaptureDevicePosition.Front{
                transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(-1.0, 1.0))
            //}
            videoPreviewView.transform = transform
            videoPreviewView.frame = window.bounds
            
            // we make our video preview view a subview of the window, and send it to the back; this makes FHViewController's view (and its UI elements) on top of the video preview, and also makes video preview unaffected by device rotation
            //window.addSubview(videoPreviewView)
            //window.sendSubviewToBack(videoPreviewView)
            psylockeCameraView.addSubview(videoPreviewView)
            
            // create the CIContext instance, note that this must be done after _videoPreviewView is properly set up
            ciContext = CIContext(EAGLContext: _eaglContext)
            
            // bind the frame buffer to get the frame buffer width and height;
            // the bounds used by CIContext when drawing to a GLKView are in pixels (not points),
            // hence the need to read from the frame buffer's width and height;
            // in addition, since we will be accessing the bounds in another queue (_captureSessionQueue),
            // we want to obtain this piece of information so that we won't be
            // accessing _videoPreviewView's properties from another thread/queue
            videoPreviewView.bindDrawable()
            self.videoPreviewViewBounds = CGRectZero
            self.videoPreviewViewBounds.size.width = CGFloat(self.videoPreviewView.drawableWidth)
            self.videoPreviewViewBounds.size.height = CGFloat(self.videoPreviewView.drawableHeight)
        }
        
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
           // self.cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
           // self.cameraPreviewLayer!.frame = UIScreen.mainScreen().bounds
           // self.psylockeCameraView.layer.addSublayer(self.cameraPreviewLayer!)
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
        let sourceExtent:CGRect = sourceImage.extent
        
        let sourceAspect = sourceExtent.size.width / sourceExtent.size.height;
        let previewAspect = self.videoPreviewViewBounds.size.width  / self.videoPreviewViewBounds.size.height;
        
        // we want to maintain the aspect ratio of the screen size, so we clip the video image
        var drawRect = sourceExtent
        if (sourceAspect > previewAspect)
        {
            // use full height of the video image, and center crop the width
            drawRect.origin.x += (drawRect.size.width - drawRect.size.height * previewAspect) / 2.0;
            drawRect.size.width = drawRect.size.height * previewAspect;
        }
        else
        {
            // use full width of the video image, and center crop the height
            drawRect.origin.y += (drawRect.size.height - drawRect.size.width / previewAspect) / 2.0;
            drawRect.size.height = drawRect.size.width / previewAspect;
        }

        
        let options = [CIDetectorSmile: true, CIDetectorEyeBlink: true, CIDetectorImageOrientation : 6]
        
        let features = self.faceDetector!.featuresInImage(sourceImage, options: options)
        
        if (features.count != 0) {
            //self.ciContext.drawImage(sourceImage, inRect: orig_rect, fromRect: rect)
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
        
        //use GLK
        dispatch_async(dispatch_get_main_queue()){
        
            self.videoPreviewView.bindDrawable()
        
            if (self._eaglContext != EAGLContext.currentContext()){
                EAGLContext.setCurrentContext(self._eaglContext)
            }
        
            // clear eagl view to grey
            glClearColor(0.5, 0.5, 0.5, 1.0);
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
            // set the blend mode to "source over" so that CI will use that
            glEnable(GLenum(GL_BLEND))
            glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        
        
            if (filteredImage != nil){
                self.ciContext.drawImage(filteredImage, inRect:self.videoPreviewViewBounds, fromRect:drawRect)
            }
        
            self.videoPreviewView.display()
        }
    }
    
 }
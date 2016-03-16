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


class Psylocke: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum DetectorAccuracy {
        case BatterySaving
        case HigerPerformance
    }
    
    enum CameraDevice {
        case ISightCamera
        case FaceTimeCamera
    }
 }
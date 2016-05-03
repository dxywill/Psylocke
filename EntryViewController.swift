//
//  EntryViewController.swift
//  Psylocke
//
//  Created by Xinyi Ding on 5/3/16.
//  Copyright © 2016 Xinyi. All rights reserved.
//


import UIKit
import AVFoundation


class EntryViewController: UIViewController {
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func buttonTapped(sender: AnyObject) {
        print("GO GO GO !")
        // Instantiate SecondViewController
        let viewController = self.storyboard?.instantiateViewControllerWithIdentifier("captureView") as! ViewController
        
              // Take user to SecondViewController
        self.navigationController?.pushViewController(viewController, animated: true)
    }
}


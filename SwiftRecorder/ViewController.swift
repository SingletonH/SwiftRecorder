//
//  ViewController.swift
//  SwiftRecorder
//
//  Created by iOS on 2018/9/25.
//  Copyright © 2018 AidaHe. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let recorderManager = RecordManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func beganRecod(_ sender: Any) {
        recorderManager.beginRcord(recordType: .Caf)
    }
    
    @IBAction func stopRecod(_ sender: Any) {
        recorderManager.stopRecord()
    }
    
    @IBAction func playAction(_ sender: Any) {
        recorderManager.play(recordType: .Caf)
    }
    
    @IBAction func convertCafToMp3(_ sender: Any) {
        
    }
    

}


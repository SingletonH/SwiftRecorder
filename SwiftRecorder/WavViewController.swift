//
//  WavViewController.swift
//  SwiftRecorder
//
//  Created by iOS on 2018/9/25.
//  Copyright © 2018 AidaHe. All rights reserved.
//

import UIKit

class WavViewController: UIViewController {
    
    let recorderManager = RecordManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func beganRecod(_ sender: Any) {
        recorderManager.beginRcord(recordType: .Wav)
    }
    
    @IBAction func stopRecod(_ sender: Any) {
        recorderManager.stopRecord()
    }
    
    @IBAction func playAction(_ sender: Any) {
        recorderManager.play(recordType: .Wav)
    }
    
    @IBAction func convertWavToAmr(_ sender: Any) {
        recorderManager.convertWavToAmr()
    }
    
    @IBAction func convertAmrToWav(_ sender: Any) {
        recorderManager.convertAmrToWav()
    }
    
    @IBAction func playWav(_ sender: Any) {
        recorderManager.playWav()
    }
    
}

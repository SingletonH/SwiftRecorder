//
//  RecorderManager.swift
//  SwiftRecorder
//
//  Created by iOS on 2018/9/25.
//  Copyright © 2018 AidaHe. All rights reserved.
//

import UIKit
import AVFoundation

enum RecordType :String {
    case Caf = "caf"
    case Wav = "wav"
}

class RecordManager: NSObject {
    
    var recorder: AVAudioRecorder?
    var player: AVAudioPlayer?
    var recordName:String?
    
    func beginRcord(recordType:RecordType){
        let session = AVAudioSession.sharedInstance()
        //设置session类型
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord, mode: .default, options: .defaultToSpeaker)
        } catch let err{
            print("设置类型失败:\(err.localizedDescription)")
        }
        //设置session动作
        do {
            try session.setActive(true)
        } catch let err {
            print("初始化动作失败:\(err.localizedDescription)")
        }
       
        let recordSetting: [String: Any] = [
            AVSampleRateKey: NSNumber(value: 16000),//采样率
            AVEncoderBitRateKey:NSNumber(value: 16000),
            AVFormatIDKey: NSNumber(value: kAudioFormatLinearPCM),//音频格式
            AVNumberOfChannelsKey: NSNumber(value: 1),//通道数
            AVLinearPCMBitDepthKey:NSNumber(value: 16),
            AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.max.rawValue)//录音质量
        ];
        //开始录音
        do {
            let now = Date()
            let timeInterval:TimeInterval = now.timeIntervalSince1970
            let timeStamp = Int(timeInterval)
            recordName = "\(timeStamp)"
            let fileType = (recordType == RecordType.Caf) ? "caf" : "wav"
            let filePath = NSHomeDirectory() + "/Documents/\(recordName!).\(fileType)"
            let url = URL(fileURLWithPath: filePath)
            recorder = try AVAudioRecorder(url: url, settings: recordSetting)
            recorder!.prepareToRecord()
            recorder!.record()
            print("开始录音----")
        } catch let err {
            print("录音失败:\(err.localizedDescription)")
        }
    }
    
    //结束录音
    func stopRecord() {
        if let recorder = self.recorder {
            recorder.stop()
            print("停止录音----")
            self.recorder = nil
        }else {
            print("停止失败")
        }
    }
    
    //播放
    func play(recordType:RecordType) {
        do {
            let fileType = (recordType == RecordType.Caf) ? "caf" : "wav"
            let filePath = NSHomeDirectory() + "/Documents/\(recordName!).\(fileType)"
            player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: filePath))
            print("播放录音长度：\(player!.duration)")
            player!.play()
        } catch let err {
            print("播放失败:\(err.localizedDescription)")
        }
    }
    
    func convertCafToMp3(){
        let audioPath = NSHomeDirectory() + "/Documents/\(recordName!).caf"
        let mp3Path = NSHomeDirectory() + "/Documents/\(recordName!).mp3"
        ConvertMp3().audioPCMtoMP3(audioPath, mp3File: mp3Path)
        print("caf源文件:\(audioPath)")
        print("mp3文件:\(mp3Path)")
    }
    
    func convertWavToAmr(){
        let wavPath = NSHomeDirectory() + "/Documents/\(recordName!).wav"
        do {
            let wavData = try Data(contentsOf: URL(fileURLWithPath: wavPath))
            let amrData = convert16khzWaveToAmr(waveData: wavData)
            let amrPath = NSHomeDirectory() + "/Documents/\(recordName!).amr"
            try amrData?.write(to: URL(fileURLWithPath: amrPath))
            print("wav源文件：\(wavPath)")
            print("amr文件：\(amrPath)")
        }catch let err {
            print("转amr文件异常：\(err.localizedDescription)")
        }
        
    }
    
    func convertAmrToWav(){
        let amrPath = NSHomeDirectory() + "/Documents/\(recordName!).amr"
        do {
            let amrData = try Data(contentsOf: URL(fileURLWithPath: amrPath))
            let wavData = convertAmrWBToWave(data: amrData)
            let wavPath = NSHomeDirectory() + "/Documents/\(recordName!)_fromAmr.wav"
            try wavData?.write(to: URL(fileURLWithPath: wavPath))
            print("amr源文件：\(amrPath)")
            print("wav文件：\(wavPath)")
        }catch let err {
            print("转wav文件异常：\(err.localizedDescription)")
        }
    }
    
    func playWav(){
        do {
            let filePath = NSHomeDirectory() + "/Documents/\(recordName!)_fromAmr.wav"
            player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: filePath))
            print("播放录音长度：\(player!.duration)")
            player!.play()
        } catch let err {
            print("播放失败:\(err.localizedDescription)")
        }
    }
    
}

## 主体功能：(Swift版本)
### 1、将录制的caf格式音频转码mp3格式

### 2、wav格式与amr格式音频相互转码
![Mp3转码](https://upload-images.jianshu.io/upload_images/6695792-89df03aedb60a15a.jpeg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
![Amr与Wav互转](https://upload-images.jianshu.io/upload_images/6695792-0486228cd085084a.jpeg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
#### 申明：

核心转码功能非原创，摘录于各大博客平台。如有侵权，请联系删除。

#### 简介：

1、转mp3主要依赖于lame

2、wav与amr的转码应该注意录音(AVAudioRecorder)的参数设置，否则可能导致转码不成功eg:
```

let recordSetting: [String:Any] = [

            AVSampleRateKey:NSNumber(value:16000),//采样率

            AVEncoderBitRateKey:NSNumber(value: 16000),

            AVFormatIDKey: NSNumber(value: kAudioFormatLinearPCM),//音频格式

            AVNumberOfChannelsKey: NSNumber(value: 1),//通道数

            AVLinearPCMBitDepthKey:NSNumber(value: 16),

            AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.max.rawValue)//录音质量

        ];
```
#### 具体实现请看源码：

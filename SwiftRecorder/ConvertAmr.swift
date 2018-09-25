//
//  ConvertAmr.swift
//  SwiftRecorder
//
//  Created by iOS on 2018/9/25.
//  Copyright © 2018 AidaHe. All rights reserved.

import UIKit

public struct ChunkDWord : CustomStringConvertible {

    var c1 : Int8
    var c2 : Int8
    var c3 : Int8
    var c4 : Int8

    public var description : String {
        return "\(c1.asciiString)\(c2.asciiString)\(c3.asciiString)\(c4.asciiString)"
    }
}

/// Common chunk's prefixion, not include `data`
public struct ChunkHeader {
    var ckID : ChunkDWord
    var ckSize : UInt32
}

/// The "RIFF" chunk descriptor
public struct WaveHeader {
    var header : ChunkHeader // ckID is "RIFF"
    var ckFmt : ChunkDWord // Here is "WAVE"
}

/// `fmt` sub-chunk
public struct ChunkFmt {
    var header : ChunkHeader // ckID is "fmt"
    var audioFmt : UInt16
    var numChannels : UInt16
    var sampleRate : UInt32
    var byteRate : UInt32
    var blockAlign : UInt16
    var bitsPerSample : UInt16
}

/// Public funtions

/// Convert the wave data to amr.
/// The sampling frequency used in WAVE is 8000 Hz.
/// If the wave data using 2 channel, default only get left channel.
///
/// - Parameter data: wave raw data
/// - Returns: amr-nb data, 1 channel
public func convert8khzWaveToAmr(waveData data : Data) -> Data? {
    return convertWaveToAmr(isWB: false, data: data)
}

/// Convert the wave data to amr.
/// The sampling frequency used in WAVE is 16000 Hz.
/// If the wave data using 2 channel, default only get left channel.
///
/// - Parameter data: wave raw data
/// - Returns: amr-wb data, 1 channel
public func convert16khzWaveToAmr(waveData data : Data) -> Data? {
    return convertWaveToAmr(isWB: true, data: data)
}

/// Convert the amr-nb data to wave.
/// the wave data using 8000 hz sample rate, 1 channel, 16 bit depth.
///
/// - Parameter data: amr-nb data
/// - Returns: wave data
func convertAmrNBToWave(data : Data) -> Data? {
    return convertAmrToWave(isWB: false, data: data)
}

/// Convert the amr-wb data to wave.
/// the wave data using 16000 hz sample rate, 1 channel, 16 bit depth.
///
/// - Parameter data: amr-wb data
/// - Returns: wave data
func convertAmrWBToWave(data : Data) -> Data? {
    return convertAmrToWave(isWB: true, data: data)
}

/// Read wave data chunk structure, if the data format is unknown, return nil.
public func readWaveStructure(data : Data) -> (ckFmt : ChunkFmt, ckData : ChunkHeader, dataOffset : Int)? {

    guard let waveHeader = data.readWaveHeader(),
        waveHeader.header.ckID.description == "RIFF",
        waveHeader.ckFmt.description == "WAVE" else {
            return nil
    }

    var readOffset = 12
    var readFmt = false
    var fmt : ChunkFmt!

    // Ignore other sub chunks, only need fmt.
    while !readFmt {
        guard let header = data.readChunkHeader(offset: readOffset) else {
            // invalid header
            return nil
        }
        if header.ckID.description == "fmt " {
            guard let tempFmt = data.readChunkFmt(offset: readOffset) else {
                return nil
            }
            fmt = tempFmt
            readFmt = true
        }
        readOffset += 8 + Int(header.ckSize)
    }


    var dataChunkHeader : ChunkHeader!
    var readDataOffset = readOffset

    repeat {
        if let chunkHeader = data.readChunkHeader(offset: readDataOffset) {
            if chunkHeader.ckID.description == "data" {
                dataChunkHeader = chunkHeader
                break
            }
            else {
                readDataOffset += 8 + Int(chunkHeader.ckSize)
            }
        }
        else {
            return nil
        }
    } while true

    guard data.count >= (Int(dataChunkHeader.ckSize) + readDataOffset + 8) else {
        return nil
    }

    return (fmt, dataChunkHeader, readDataOffset + 8)
}

////////  Private functions

/// Convert wave data to amr
fileprivate func convertWaveToAmr(isWB : Bool, data : Data) -> Data? {

    guard let rlt = readWaveStructure(data: data) else {
        return nil
    }

    var amrData = Data()

    var offset = rlt.dataOffset
    let dtx : Int32 = 0
    var mode : Int32
    let frameSize = Int(Float(UInt32(rlt.ckFmt.numChannels * rlt.ckFmt.bitsPerSample/8) * rlt.ckFmt.sampleRate) * 0.02)
    var state : UnsafeMutableRawPointer

    if isWB {
        // Add amr-wb magic number.
        amrData.append("#!AMR-WB\n".data(using: .ascii)!)
        mode = 8 // 23.85kbps
        state = E_IF_init()
    }
    else {
        // Add amr-nb magic number.
        amrData.append("#!AMR\n".data(using: .ascii)!)
        mode = 7 // 12.2kbps
        state = Encoder_Interface_init(dtx)
    }

    repeat {
        if var speech = data.pcmFrame(numChannels: rlt.ckFmt.numChannels, bitsPerSample: rlt.ckFmt.bitsPerSample, frameSize: frameSize, offset: offset) {
            offset += frameSize

            var resultBytes : [UInt8]

            if isWB {
                let bytesNum = 61 // 1 + ceil(23.85 * 1000 * 0.02 / 8) = 61
                resultBytes = [UInt8](repeating: 0, count: bytesNum)
                E_IF_encode(state, mode, &speech, &resultBytes, dtx)
            }
            else {
                let bytesNum = 32 // 1 + ceil(12.2 * 1000 * 0.02 / 8) = 32
                resultBytes = [UInt8](repeating: 0, count: bytesNum)
                Encoder_Interface_Encode(state, Mode(rawValue: UInt32(mode)), &speech, &resultBytes, dtx)
            }

            let frameData = Data(bytes: &resultBytes, count: resultBytes.count)
            amrData.append(frameData)
        }
        else {
            break
        }
    } while true

    if isWB {
        E_IF_exit(state)
    }
    else {
        Encoder_Interface_exit(state)
    }

    print("Encode amr-\(isWB ? "wb" : "nb") data succeed!")
    print("wav size : \(data.count/1000)k\namr size : \(amrData.count/1000)k\n")

    return amrData
}

/// Generate wave data chunks header, not include pcm raw data.
fileprivate func waveHeaderData(sampleRate : UInt32, dataSize : UInt32) -> Data {

    // http://soundfile.sapp.org/doc/WaveFormat/

    // RIFF
    let riff = ChunkDWord(c1: 82, c2: 73, c3: 70, c4: 70)
    let wave = ChunkDWord(c1: 87, c2: 65, c3: 86, c4: 69)
    let waveHeader = WaveHeader(header: ChunkHeader(ckID: riff, ckSize: dataSize + 36), ckFmt: wave)

    // fmt
    let fmt = ChunkDWord(c1: 102, c2: 109, c3: 116, c4: 32)
    let fmtHeader = ChunkHeader(ckID: fmt, ckSize: 16)
    let ckFmt = ChunkFmt(header: fmtHeader, audioFmt: 1, numChannels: 1, sampleRate: sampleRate, byteRate: sampleRate*2, blockAlign: 2, bitsPerSample: 16)

    // data
    let dataDWord = ChunkDWord(c1: 100, c2: 97, c3: 116, c4: 97)
    let dataHeader = ChunkHeader(ckID: dataDWord, ckSize: dataSize)

    let waveHeaderData = withUnsafePointer(to: waveHeader) { (pointer) -> Data in
        return Data(bytes: UnsafeRawPointer(pointer), count: MemoryLayout.size(ofValue: waveHeader))
    }
    let ckFmtData = withUnsafePointer(to: ckFmt) { (pointer) -> Data in
        return Data(bytes: UnsafeRawPointer(pointer), count: MemoryLayout.size(ofValue: ckFmt))
    }
    let dataHeaderData = withUnsafePointer(to: dataHeader) { (pointer) -> Data in
        return Data(bytes: UnsafeRawPointer(pointer), count: MemoryLayout.size(ofValue: dataHeader))
    }

    var data = Data()
    data.append(waveHeaderData)
    data.append(ckFmtData)
    data.append(dataHeaderData)

    return data
}

/// Convert amr data to wave
fileprivate func convertAmrToWave(isWB : Bool, data : Data) -> Data? {
    let magicNumberCount = isWB ? 9 : 6
    let magicNumber = isWB ? "#!AMR-WB\n" : "#!AMR\n"
    guard data.count > magicNumberCount, data.starts(with: magicNumber.data(using: .ascii)!) else {
        return nil
    }

    let firstF = data.subdata(in: Range<Data.Index>(magicNumberCount...magicNumberCount)).first!
    let mode = Int((firstF>>3)&(0x0f))

    print("Amr frame type : \(mode)")

    let modeFrameSize = isWB ? amrwbModeFrameSize : amrnbModeFrameSize

    guard mode < modeFrameSize.count else {
        return nil
    }

    var wavData = Data()

    let frameSize = modeFrameSize[mode]

    var amrData = data.subdata(in: Range<Data.Index>(magicNumberCount..<data.count))

    var dataSize : UInt32 = 0
    var waveFrameSize : Int
    if isWB {
        waveFrameSize = 320 // 16000 * 0.02 (using 16000 Hz, 20 ms speech frame)
    }
    else {
        waveFrameSize = 160 // 8000 * 0.02 (using 8000 Hz, 20 ms speech frame)
    }

    var out = [Int16](repeating: 0, count: waveFrameSize)

    var state : UnsafeMutableRawPointer

    if isWB {
        state = D_IF_init()
    }
    else {
        state = Decoder_Interface_init()
    }

    repeat {
        if amrData.count >= Int(frameSize) {
            let frameRange = Range<Data.Index>(0..<Int(frameSize))
            let frameData = amrData.subdata(in: frameRange)
            let frameHeader = frameData.first!

            //            FT (4 bits): Frame type indicator, indicating the AMR or AMR-WB
            //            speech coding mode or comfort noise (SID) mode.
            //            Q (1 bit): The payload quality bit indicates, if not set, that the
            //            payload is severely damaged and the receiver should set the RX_TYPE,
            //            see [6], to SPEECH_BAD or SID_BAD depending on the frame type (FT).
            //            let FT = (frameHeader>>3) & (0x0f)
            let Q = (frameHeader>>2) & (0x01)
            //            print("FT(\(FT)) Q(\(Q))")

            if Q == 1 {

                var bytes = [UInt8](repeating: 0, count: frameData.count)
                frameData.copyBytes(to: &bytes, count: frameData.count)

                if isWB {
                    D_IF_decode(state, &bytes, &out, 0)
                }
                else {
                    Decoder_Interface_Decode(state, &bytes, &out, 0)
                }

                wavData.append(out.withUnsafeBufferPointer({ (pointer) -> Data in
                    return Data(buffer: pointer)
                }))

                dataSize += UInt32(waveFrameSize) * 2 // 16(Int16) is 2 * 8(Int8)
            }

            amrData.removeSubrange(frameRange)
        }
        else {
            break
        }
    } while true

    if isWB {
        D_IF_exit(state)
    }
    else {
        Decoder_Interface_exit(state)
    }

    wavData.insert(contentsOf: waveHeaderData(sampleRate : isWB ? 16000 : 8000, dataSize: dataSize), at: 0)

    print("Decode amr-\(isWB ? "wb" : "nb") data succeed!")
    print("amr size : \(data.count)\nwave size : \(wavData.count)\n")

    return wavData
}

// CMR Mode Frame size (bytes)
fileprivate let amrnbModeFrameSize = [13, 14, 16, 18, 20, 21, 27, 32]
fileprivate let amrwbModeFrameSize = [18, 24, 33, 37, 41, 47, 51, 59, 61]

/// Utils

fileprivate extension Data {

    // http://soundfile.sapp.org/doc/WaveFormat/

    func readWaveHeader() -> WaveHeader? {
        guard self.count > 12 else {
            return nil
        }
        return readData(range: Range<Data.Index>(0..<12), type: WaveHeader.self)
    }

    func readChunkFmt(offset : Int) -> ChunkFmt? {
        guard self.count > offset + 24 else {
            return nil
        }
        return readData(range: Range<Data.Index>(offset..<offset + 24), type: ChunkFmt.self)
    }

    func readChunkHeader(offset : Int) -> ChunkHeader? {
        guard self.count > offset + 8 else {
            return nil
        }
        return readData(range: Range<Data.Index>(offset..<(offset+8)), type: ChunkHeader.self)
    }

    func pcmFrame(numChannels : UInt16, bitsPerSample : UInt16, frameSize : Int, offset : Int) -> [Int16]? {

        var speech : [Int16]! = [Int16](repeating:0, count: frameSize/Int(numChannels)/Int(bitsPerSample/8))

        guard self.count > (offset + frameSize) else {
            return nil
        }

        //        http://blog.csdn.net/ce123_zhouwei/article/details/9358265

        // 1-channel 8-bit
        if numChannels == 1, bitsPerSample == 8 {
            let bytes = readBufferData(range: Range<Data.Index>(offset..<(offset+frameSize)), type: UInt8.self, capacity: frameSize)
            for (i, byte) in bytes.enumerated() {
                speech[i] = Int16(byte)<<7
            }
        }
            // 1-channel 16-bit
        else if numChannels == 1, bitsPerSample == 16 {
            let bytes = readBufferData(range: Range<Data.Index>(offset..<(offset+frameSize)), type: Int16.self, capacity: frameSize/2)

            for (i, byte) in bytes.enumerated() {
                speech[i] = Int16(byte)
            }
        }
            // 2-channel 8-bit
        else if numChannels == 2, bitsPerSample == 8 {
            let bytes = readBufferData(range: Range<Data.Index>(offset..<(offset+frameSize)), type: UInt8.self, capacity: frameSize)
            for (i, byte) in bytes.enumerated() {
                // left channel
                if i%2 == 0 {
                    speech[i/2] = Int16(byte)<<7
                }
                // right channel
                //                i%2 == 1
            }
        }
            // 2-channel 16-bit
        else if numChannels == 2, bitsPerSample == 16 {
            let bytes = readBufferData(range: Range<Data.Index>(offset..<(offset+frameSize)), type: Int16.self, capacity: frameSize/2)
            for (i, byte) in bytes.enumerated() {
                // left channel
                if i%2 == 0 {
                    speech[i/2] = byte
                }
            }
        }

        return speech
    }

    func readBufferData<Result>(range : Range<Data.Index>, type : Result.Type, capacity count: Int) -> [Result] {
        let subd = subdata(in: range)
        let buffer = subd.withUnsafeBytes { (bytes : UnsafePointer<UInt8>) -> UnsafeBufferPointer<Result> in
            return bytes.withMemoryRebound(to: Result.self, capacity: count, { (pointer : UnsafePointer<Result>) -> UnsafeBufferPointer<Result> in
                return UnsafeBufferPointer<Result>(start: pointer, count: count)
            })
        }
        var bytes = [Result]()
        for (_, b) in buffer.enumerated() {
            bytes.append(b)
        }
        return bytes
    }

    //    func readBufferData<Result>(range : Range<Data.Index>, type : Result.Type, capacity count: Int) -> UnsafeMutableBufferPointer<Result> {
    //        var subd = subdata(in: range)
    //        print(subd)
    //        return subd.withUnsafeMutableBytes { (bytes : UnsafeMutablePointer<UInt8>) -> UnsafeMutableBufferPointer<Result> in
    //            return bytes.withMemoryRebound(to: Result.self, capacity: count, { (pointer : UnsafeMutablePointer<Result>) -> UnsafeMutableBufferPointer<Result> in
    //                return UnsafeMutableBufferPointer<Result>(start: pointer, count: count)
    //            })
    //        }
    //    }

    func readData<Result>(range : Range<Data.Index>, type : Result.Type) -> Result {
        return self.subdata(in: range).withUnsafeBytes { (bytes : UnsafePointer<Int8>) -> Result in
            return bytes.withMemoryRebound(to: Result.self, capacity: 1, { (st : UnsafePointer<Result>) -> Result in
                return st.pointee
            })
        }
    }
}

fileprivate extension Int8 {
    var asciiString : String {
        return String(bytes: [UInt8(self)], encoding: .ascii) ?? ""
    }
}

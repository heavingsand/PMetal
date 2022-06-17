//
//  PCameraRecorder.swift
//  PanSwift
//
//  Created by Pan on 2022/6/14.
//

import Foundation
import AVFoundation

class PCameraRecorder {
    
    // MARK: - Property
    
    private var assetWriter: AVAssetWriter?
    
    private var assetWriterVideoInput: AVAssetWriterInput?
    
    private var assetWriterAudioInput: AVAssetWriterInput?
    
    private var videoTransform: CGAffineTransform
    
    private var videoSettings: [String: Any]

    private var audioSettings: [String: Any]

    private(set) var isRecording = false
    
    // MARK: - Life Cycle
    
    init(audioSettings: [String: Any], videoSettings: [String: Any], videoTransform: CGAffineTransform) {
        self.audioSettings = audioSettings
        self.videoSettings = videoSettings
        self.videoTransform = videoTransform
    }
    
    // MARK: - Method
    
    /// 开始录制
    func startRecording() {
        // Create an asset writer that records to a temporary file
        let outputFileName = NSUUID().uuidString
        let outputFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(outputFileName).appendingPathExtension("MOV")
        guard let assetWriter = try? AVAssetWriter(url: outputFileURL, fileType: .mov) else {
            print("写入容器创建失败")
            return
        }
        
        // Add an audio input
        let assetWriterAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        assetWriterAudioInput.expectsMediaDataInRealTime = true
        guard assetWriter.canAdd(assetWriterAudioInput) else {
            print("无法添加音频input")
            return
        }
        assetWriter.add(assetWriterAudioInput)
        
        // Add a video input
        let assetWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        assetWriterVideoInput.expectsMediaDataInRealTime = true
        assetWriterVideoInput.transform = videoTransform
        guard assetWriter.canAdd(assetWriterVideoInput) else {
            print("无法添加视频input")
            return
        }
        assetWriter.add(assetWriterVideoInput)
        
        self.assetWriter = assetWriter
        self.assetWriterAudioInput = assetWriterAudioInput
        self.assetWriterVideoInput = assetWriterVideoInput
        
        isRecording = true
    }
    
    /// 停止录制
    /// - Parameter completion: 结束回调
    func stopRecording(completion: @escaping (URL) -> Void) {
        guard let assetWriter = assetWriter else {
            print("停止录制失败, 写入容器为空")
            return
        }
        
        self.isRecording = false
        self.assetWriter = nil
        
        assetWriter.finishWriting {
            completion(assetWriter.outputURL)
        }
    }
    
    /// 录制视频
    func recordVideo(sampleBuffer: CMSampleBuffer) {
        guard isRecording, let assetWriter = assetWriter else {
            print("无法录制视频")
            return
        }
        
        if assetWriter.status == .unknown {
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        } else if assetWriter.status == .writing {
            if let input = assetWriterVideoInput, input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }
    
    /// 录制音频
    func recordAudio(sampleBuffer: CMSampleBuffer) {
        guard isRecording,
            let assetWriter = assetWriter,
            assetWriter.status == .writing,
            let input = assetWriterAudioInput,
            input.isReadyForMoreMediaData else {
            print("无法录制音频")
            return
        }
        
        input.append(sampleBuffer)
    }
    
}

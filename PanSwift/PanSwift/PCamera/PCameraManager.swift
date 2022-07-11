//
//  PCameraManager.swift
//  PanSwift
//
//  Created by Pan on 2022/1/21.
//

import UIKit
import AVFoundation

public protocol CameraManagerDelegate: AnyObject {
    
    /// 视频捕获输出
    /// - Parameters:
    ///   - sampleBuffer: buffer
    ///   - videoDataOutput: 视频output
    func videoCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput videoDataOutput: AVCaptureVideoDataOutput)
    
    /// 音频捕获输出
    /// - Parameters:
    ///   - sampleBuffer: buffer
    ///   - audioDataOutput: 音频output
    func audioCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput audioDataOutput: AVCaptureAudioDataOutput)
}

public extension CameraManagerDelegate {
    func videoCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput videoDataOutput: AVCaptureVideoDataOutput) {}
    
    func audioCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput audioDataOutput: AVCaptureAudioDataOutput) {}
}

public final class PCameraManager: NSObject {

    /// Session配置状态
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
        case unknown
    }
    
    // MARK: - Property
    public weak var delegate: CameraManagerDelegate?
    
    let session = AVCaptureSession()
    
    let sessionQueue = DispatchQueue(label: "com.pan.cameraManager.sessionQueue")
    
    var captureDevice: AVCaptureDevice!
    
    var videoDeviceInput: AVCaptureDeviceInput!
    
    let videoDataOutput = AVCaptureVideoDataOutput()
    
    var audioDataInput: AVCaptureDeviceInput!
    
    let audioDataOutput = AVCaptureAudioDataOutput()
    
    let dataOutputQueue = DispatchQueue(label: "com.pan.cameraManager.videoDataOutputQueue")
    
    private var setupResult: SessionSetupResult = .success
    
    private var isSessionRunning = false
    
    private var beginSessionConfigurationCount = 0;
    
    // MARK: - Life Cycle
    override init() {
        super .init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeErrorNoti(notification:)), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptitedNoti(notification:)), name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEndedNoti(notification:)), name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionDidStopRunningNoti(notification:)), name: NSNotification.Name.AVCaptureSessionDidStopRunning, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionDidStarRunningNoti(notification:)), name: NSNotification.Name.AVCaptureSessionDidStartRunning, object: session)
        
        sessionQueue.suspend()
        sessionQueue.async {
            self.configSession()
        }
    }
    
    deinit {
        HSLog("🤔🤔\(Self.self) deinit")
    }
    
    /// 准备
    /// @discussion 在startRunning之前执行
    func prepare() {
        PCameraAuthorization.requestAuthorization(with: .video) { success in
            if success {
                self.setupResult = .success
            }else {
                self.setupResult = .notAuthorized
            }
            // 执行队列任务
            self.sessionQueue.resume()
        }
    }
    
    /// 开始运行
    func startRunning() {
        guard setupResult == .success else {
            return
        }
        
        sessionQueue.async {
            self.session.startRunning()
        }
    }
    
    /// 停止运行
    func stopRunning() {
        guard setupResult == .success else {
            return
        }
        
        sessionQueue.async {
            self.session.stopRunning()
        }
    }
}

// MARK: - Private Method
extension PCameraManager {
    
    /// 配置session
    private func configSession() {
        guard setupResult == .success else {
            return
        }
        
        // 配置input
//        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera,
//                                                         .builtInTelephotoCamera,
//                                                         .builtInDualCamera,
//                                                         .builtInTrueDepthCamera,
//                                                         .builtInUltraWideCamera,
//                                                         .builtInDualWideCamera,
//                                                         .builtInTripleCamera
//        ]
//
//        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .unspecified)
        let defaultVideoDevice = AVCaptureDevice.default(for: .video)
        
        guard let videoDevice = defaultVideoDevice else {
            HSLog("🤔🤔Could not find any video device")
            setupResult = .configurationFailed
            return
        }
        
        captureDevice = videoDevice
        
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            HSLog("🤔🤔Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return
        }
        
        // Find the microphone
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("Could not find the microphone")
            return
        }
        
        do {
            audioDataInput = try AVCaptureDeviceInput(device: audioDevice)
        } catch {
            HSLog("🤔🤔Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return
        }
        
        // 配置output
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        
        audioDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        
        // 配置session
        beginConfiguration()
        
        session.sessionPreset = .iFrame1280x720
        
        // Add a video input
        guard session.canAddInput(videoDeviceInput) else {
            HSLog("🤔🤔Could not add video device input to the session")
            setupResult = .configurationFailed
            commitConfiguration()
            return
        }
        session.addInput(videoDeviceInput)
        
        // Add a audio input
        guard session.canAddInput(audioDataInput) else {
            HSLog("🤔🤔Could not add audio device input to the session")
            setupResult = .configurationFailed
            commitConfiguration()
            return
        }
        session.addInput(audioDataInput)
        
        // Add a video data output
        guard session.canAddOutput(videoDataOutput) else {
            HSLog("🤔🤔Could not add videoDataOutput to the session")
            setupResult = .configurationFailed
            commitConfiguration()
            return
        }
        session.addOutput(videoDataOutput)
        
        // Add a audio data output
        guard session.canAddOutput(audioDataOutput) else {
            HSLog("🤔🤔Could not add audioDataOutput to the session")
            setupResult = .configurationFailed
            commitConfiguration()
            return
        }
        session.addOutput(audioDataOutput)
        
//        if AVCaptureDevice.supportDolbyVision() {
//            for format in videoDevice.formats {
//                let description = format.formatDescription
//                if CMFormatDescriptionGetMediaSubType(description) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, format.isMultiCamSupported {
//                    do {
//                        try videoDevice.lockForConfiguration()
//                        videoDevice.activeFormat = format
//                        videoDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 30)
//                        videoDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 30)
//                        /// 重设颜色空间为最高支持
//                        if #available(iOS 10.0, *) {
//                            videoDevice.activeColorSpace = format.supportedColorSpaces.last!;
//                        }
//                        videoDevice.unlockForConfiguration()
//                        break
//                    } catch {
//                        print(error)
//                        return
//                    }
//                }
//            }
//        }
        
        let connection = session.connections.first
        if let newConnection = connection {
            newConnection.videoOrientation = .portrait
            print("sddss")
        }
        
        commitConfiguration()
    }
    
    /// 开始配置session
    private func beginConfiguration() {
        beginSessionConfigurationCount+=1
        if beginSessionConfigurationCount == 1 {
            session.beginConfiguration()
        }
    }
    
    /// 提交session配置
    private func commitConfiguration() {
        beginSessionConfigurationCount-=1
        if beginSessionConfigurationCount == 0 {
            session.commitConfiguration()
        }
    }
    
    /// 获取视频配置
    func videoSetting() -> [String: NSObject]? {
        guard let videoSettings = videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject] else {
            print("Could not get back camera video settings")
            return nil
        }
        
        return videoSettings
    }
    
    /// 获取音频设置
    func audioSetting() -> [String: NSObject]? {
        guard let audioSettings = audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject] else {
            print("Could not get back microphone audio settings")
            return nil
        }
        
        return audioSettings
    }
    
    /// 获取视频旋转角度
    func videoTransform() -> CGAffineTransform? {
        guard let videoConnection = videoDataOutput.connection(with: .video) else {
            print("Could not find the back and front camera video connections")
            return nil
        }
        
        let deviceOrientation = UIDevice.current.orientation
        let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation) ?? .portrait
        
        // Compute transforms from the back camera's video orientation to the device's orientation
        let backCameraTransform = videoConnection.videoOrientationTransform(relativeTo: videoOrientation)

        return backCameraTransform
    }

}

// MARK: - 通知
extension PCameraManager {
    /// Session运行时错误
    @objc private func sessionRuntimeErrorNoti(notification: Notification) {
//        HSLog("\(notification)")
    }
    
    /// Session中断
    @objc private func sessionInterruptitedNoti(notification: Notification) {
//        HSLog("\(notification)")
    }
    
    /// Session中断恢复
    @objc private func sessionInterruptionEndedNoti(notification: Notification) {
//        HSLog("\(notification)")
    }
    
    /// Session停止运行
    @objc private func sessionDidStopRunningNoti(notification: Notification) {
//        HSLog("\(notification)")
    }
    
    /// Session开始运行
    @objc private func sessionDidStarRunningNoti(notification: Notification) {
//        HSLog("\(notification)")
    }
}

// MARK: - VideoDataOutput代理
extension PCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        HSLog("🤔🤔\(sampleBuffer)")
        
        if let videoDataOutput = output as? AVCaptureVideoDataOutput {
            connection.videoOrientation = .portrait
            delegate?.videoCaptureOutput(didOutput: sampleBuffer, fromOutput: videoDataOutput)
        } else if let audioDataOutput = output as? AVCaptureAudioDataOutput {
            delegate?.audioCaptureOutput(didOutput: sampleBuffer, fromOutput: audioDataOutput)
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var reason: CMAttachmentMode = 0
        CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_DroppedFrameReason, attachmentModeOut: &reason)
        HSLog("🤔🤔\(String(describing: reason))丢帧了")
    }
}

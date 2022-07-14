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
    
    /// 视频和深度数据同步输出
    /// - Parameters:
    ///   - videoSampleBuffer: 视频数据
    ///   - depthPixelBuffer: 深度数据
    func videoOutputSynchronizer(didOutput videoSampleBuffer: CMSampleBuffer, depthPixelBuffer: CVPixelBuffer)
}

public extension CameraManagerDelegate {
    func videoCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput videoDataOutput: AVCaptureVideoDataOutput) {}
    
    func audioCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput audioDataOutput: AVCaptureAudioDataOutput) {}
    
    func videoOutputSynchronizer(didOutput videoSampleBuffer: CMSampleBuffer, depthPixelBuffer: CVPixelBuffer) {}
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
    
    /// 摄像头类型
    public var deviceType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera
    
    /// 摄像头位置
    public var devicePosition: AVCaptureDevice.Position = .back
    
    /// 当前使用的摄像头
    private var captureDevice: AVCaptureDevice!
    
    /// 设备管道
    private let session = AVCaptureSession()
    
    /// Session配置状态
    private var setupResult: SessionSetupResult = .success
    
    /// 用于记录配置的开始/提交
    private var beginSessionConfigurationCount = 0;
    
    /// 队列
    private let sessionQueue = DispatchQueue(label: "com.pan.cameraManager.sessionQueue")
    private let dataOutputQueue = DispatchQueue(label: "com.pan.cameraManager.videoDataOutputQueue")
    
    private var videoDeviceInput: AVCaptureDeviceInput!
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    private var audioDeviceInput: AVCaptureDeviceInput!
    private let audioDataOutput = AVCaptureAudioDataOutput()
    
    private let depthDataOutput = AVCaptureDepthDataOutput()
    
    /// 同步视频数据和深度数据的输出
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    
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
        
        beginConfiguration()
        defer {
            commitConfiguration()
        }
        
        /// 配置video
        guard let videoDevice = AVCaptureDevice.default(deviceType, for: .video, position: devicePosition) else {
            setupResult = .configurationFailed
            HSLog("🤔🤔Could not find any video device")
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

        guard session.canAddInput(videoDeviceInput) else {
            HSLog("🤔🤔Could not add video device input to the session")
            setupResult = .configurationFailed
            return
        }
        session.addInputWithNoConnections(videoDeviceInput)

        guard let backInputPort = videoDeviceInput.ports(for: .video, sourceDeviceType: videoDevice.deviceType, sourceDevicePosition: videoDevice.position).first else {
            HSLog("Could not find the back camera device input's video port")
            setupResult = .configurationFailed
            return
        }

        guard session.canAddOutput(videoDataOutput) else {
            HSLog("Could not add the back camera video data output")
            setupResult = .configurationFailed
            return
        }
        session.addOutputWithNoConnections(videoDataOutput)
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)

        let deviceConnection = AVCaptureConnection(inputPorts: [backInputPort], output: videoDataOutput)
        guard session.canAddConnection(deviceConnection) else {
            print("Could not add a connection to the back camera video data output")
            return
        }
        session.addConnection(deviceConnection)
        deviceConnection.videoOrientation = .portrait
        
        /// 配置audio
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("Could not find the microphone")
            return
        }
        
        do {
            audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
        } catch {
            HSLog("🤔🤔Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return
        }
        
        guard session.canAddInput(audioDeviceInput) else {
            HSLog("🤔🤔Could not add audio device input to the session")
            setupResult = .configurationFailed
            return
        }
        session.addInput(audioDeviceInput)
        
        guard session.canAddOutput(audioDataOutput) else {
            HSLog("🤔🤔Could not add audioDataOutput to the session")
            setupResult = .configurationFailed
            return
        }
        session.addOutput(audioDataOutput)
        audioDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        
        /// 配置深度通道
        let depthFormats = videoDevice.activeFormat.supportedDepthDataFormats
        let depth32formats = depthFormats.filter({
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat16
        })
        
        if depth32formats.isEmpty {
            print("Device does not support Float32 depth format")
            setupResult = .configurationFailed
            return
        }
        
        let selectedFormat = depth32formats.max(by: { first, second in
            CMVideoFormatDescriptionGetDimensions(first.formatDescription).width < CMVideoFormatDescriptionGetDimensions(second.formatDescription).width })
        
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.activeDepthDataFormat = selectedFormat
            videoDevice.unlockForConfiguration()
        } catch  {
            print("Could not lock device for configuration: \(error)")
            setupResult = .configurationFailed
            return
        }
        
        guard session.canAddOutput(depthDataOutput) else {
            print("Could not add depth data output to the session")
            setupResult = .configurationFailed
            return
        }
        session.addOutput(depthDataOutput)
        depthDataOutput.isFilteringEnabled = true
        depthDataOutput.connection(with: .depthData)?.isEnabled = true
        depthDataOutput.connection(with: .depthData)?.videoOrientation = .portrait
        
        /// 同步数据
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput])
        outputSynchronizer?.setDelegate(self, queue: dataOutputQueue)
        
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

// MARK: - Synchronizer代理
extension PCameraManager: AVCaptureDataOutputSynchronizerDelegate {
    public func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        // Read all outputs
        guard let syncedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData,
              let syncedVideoData = synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else {
            return
        }
        
        if syncedDepthData.depthDataWasDropped || syncedVideoData.sampleBufferWasDropped {
            return
        }
        
        delegate?.videoOutputSynchronizer(didOutput: syncedVideoData.sampleBuffer, depthPixelBuffer: syncedDepthData.depthData.depthDataMap)
    }
}

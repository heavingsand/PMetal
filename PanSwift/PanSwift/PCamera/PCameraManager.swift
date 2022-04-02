//
//  PCameraManager.swift
//  PanSwift
//
//  Created by Pan on 2022/1/21.
//

import UIKit
import AVFoundation

public protocol CameraManagerDelegate: AnyObject {
    
    /// 捕获输出
    /// - Parameter sampleBuffer: 缓冲池
    func captureOutput(didOutput sampleBuffer: CMSampleBuffer)
}

public extension CameraManagerDelegate {
    func captureOutput(didOutput sampleBuffer: CMSampleBuffer) {}
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
    
    let sessionQueue = DispatchQueue(label: "com.cameraManager.sessionQueue")
    
    var captureDevice: AVCaptureDevice!
    
    var videoDeviceInput: AVCaptureDeviceInput!
    
    let videoDataOutput = AVCaptureVideoDataOutput()
    
    let videoDataOutputQueue = DispatchQueue(label: "com.cameraManager.videoDataOutputQueue")
    
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
        
        // 配置output
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
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
        
        // Add a video data output
        guard session.canAddOutput(videoDataOutput) else {
            HSLog("🤔🤔Could not add videoDataOutput to the session")
            setupResult = .configurationFailed
            commitConfiguration()
            return
        }
        session.addOutput(videoDataOutput)
        
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
extension PCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        connection.videoOrientation = .portrait
//        HSLog("🤔🤔\(sampleBuffer)")
        
        delegate?.captureOutput(didOutput: sampleBuffer)
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var reason: CMAttachmentMode = 0
        CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_DroppedFrameReason, attachmentModeOut: &reason)
        HSLog("🤔🤔\(String(describing: reason))丢帧了")
    }
}

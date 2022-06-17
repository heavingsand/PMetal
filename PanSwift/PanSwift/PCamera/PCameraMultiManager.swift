//
//  PMultiCameraManager.swift
//  PanSwift
//
//  Created by Pan on 2022/6/10.
//

import UIKit
import AVFoundation

public protocol MultiCameraManagerDelegate: AnyObject {
    
    /// 视频捕获输出
    /// - Parameters:
    ///   - sampleBuffer: buffer
    ///   - videoDataOutput: 视频output
    ///   - isPip: 是否画中画
    func videoCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput videoDataOutput: AVCaptureVideoDataOutput, isPip: Bool)
    
    /// 音频捕获输出
    /// - Parameters:
    ///   - sampleBuffer: buffer
    ///   - audioDataOutput: 音频output
    func audioCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput audioDataOutput: AVCaptureAudioDataOutput)
}

public extension MultiCameraManagerDelegate {
    func videoCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput videoDataOutput: AVCaptureVideoDataOutput, isPip: Bool) {}
    
    func audioCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput audioDataOutput: AVCaptureAudioDataOutput) {}
}

public final class PCameraMultiManager: NSObject {
    
    /// Session配置状态
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
        case multiCamNotSupported
        case unknown
    }
    
    // MARK: - Property
    
    public weak var delegate: MultiCameraManagerDelegate?
    
    /// 多路捕获通道
    let session = AVCaptureMultiCamSession()
    
    let sessionQueue = DispatchQueue(label: "com.pan.multiCameraManager.sessionQueue")
    
    /// 后置视频
    var backVideoDeviceInput: AVCaptureDeviceInput!
    let backVideoDataOutput = AVCaptureVideoDataOutput()
    
    /// 前置视频
    var frontVideoDeviceInput: AVCaptureDeviceInput!
    let frontVideoDataOutput = AVCaptureVideoDataOutput()
    
    /// 音频
    var audioDeviceInput: AVCaptureDeviceInput!
    let backAudioDataOutput = AVCaptureAudioDataOutput()
    let frontAudioDataOutput = AVCaptureAudioDataOutput()
    
    let dataOutputQueue = DispatchQueue(label: "com.pan.multiCameraManager.videoDataOutputQueue")
    
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
    
    // MARK: - Public Method
    
    /// 准备
    /// @discussion 在startRunning之前执行
    func prepare() {
        PCameraAuthorization.requestAuthorization(with: .video) { success in
            if success {
                self.setupResult = .success
            } else {
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
    
    /// 获取视频配置
    func videoSetting() -> [String: NSObject]? {
        guard let backVideoSettings = backVideoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject] else {
            print("Could not get back camera video settings")
            return nil
        }
        
        guard let frontVideoSettings = frontVideoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject] else {
            print("Could not get front camera video settings")
            return nil
        }
        
        if backVideoSettings == frontVideoSettings {
            // The front and back camera video settings are equal, so return either one
            return backVideoSettings
        } else {
            print("Front and back camera video settings are not equal. Check your AVCaptureVideoDataOutput configuration.")
            return nil
        }
    }
    
    /// 获取音频设置
    func audioSetting() -> [String: NSObject]? {
        guard let backeAudioSettings = backAudioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject] else {
            print("Could not get back microphone audio settings")
            return nil
        }
        guard let frontAudioSettings = frontAudioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject] else {
            print("Could not get front microphone audio settings")
            return nil
        }
        
        if backeAudioSettings == frontAudioSettings {
            // The front and back microphone audio settings are equal, so return either one
            return backeAudioSettings
        } else {
            print("Front and back microphone audio settings are not equal. Check your AVCaptureAudioDataOutput configuration.")
            return nil
        }
    }
    
    /// 获取视频旋转角度
    func videoTransform() -> CGAffineTransform? {
        guard let backVideoConnection = backVideoDataOutput.connection(with: .video) else {
            print("Could not find the back and front camera video connections")
            return nil
        }
        
        let deviceOrientation = UIDevice.current.orientation
        let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation) ?? .portrait
        
        // Compute transforms from the back camera's video orientation to the device's orientation
        let backCameraTransform = backVideoConnection.videoOrientationTransform(relativeTo: videoOrientation)

        return backCameraTransform
    }
    
    /// 分配输出缓冲池
    func allocateOutputBufferPool(with inputFormatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int) -> (outputBufferPool: CVPixelBufferPool?, outputColorSpace: CGColorSpace?, outputFormatDescription: CMFormatDescription?) {
        let inputMediaSubType = CMFormatDescriptionGetMediaSubType(inputFormatDescription)
        if inputMediaSubType != kCVPixelFormatType_32BGRA {
            assertionFailure("Invalid input pixel buffer type \(inputMediaSubType)")
            return (nil, nil, nil)
        }
        
        let inputDimensions = CMVideoFormatDescriptionGetDimensions(inputFormatDescription)
        var pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: UInt(inputMediaSubType),
            kCVPixelBufferWidthKey as String: Int(inputDimensions.width),
            kCVPixelBufferHeightKey as String: Int(inputDimensions.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        // Get pixel buffer attributes and color space from the input format description
        var cgColorSpace: CGColorSpace? = CGColorSpaceCreateDeviceRGB()
        if let inputFormatDescriptionExtension = CMFormatDescriptionGetExtensions(inputFormatDescription) as Dictionary? {
            let colorPrimaries = inputFormatDescriptionExtension[kCVImageBufferColorPrimariesKey]
            
            if let colorPrimaries = colorPrimaries {
                var colorSpaceProperties: [String: AnyObject] = [kCVImageBufferColorPrimariesKey as String: colorPrimaries]
                
                if let yCbCrMatrix = inputFormatDescriptionExtension[kCVImageBufferYCbCrMatrixKey] {
                    colorSpaceProperties[kCVImageBufferYCbCrMatrixKey as String] = yCbCrMatrix
                }
                
                if let transferFunction = inputFormatDescriptionExtension[kCVImageBufferTransferFunctionKey] {
                    colorSpaceProperties[kCVImageBufferTransferFunctionKey as String] = transferFunction
                }
                
                pixelBufferAttributes[kCVBufferPropagatedAttachmentsKey as String] = colorSpaceProperties
            }
            
            if let cvColorspace = inputFormatDescriptionExtension[kCVImageBufferCGColorSpaceKey],
                CFGetTypeID(cvColorspace) == CGColorSpace.typeID {
                cgColorSpace = (cvColorspace as! CGColorSpace)
            } else if (colorPrimaries as? String) == (kCVImageBufferColorPrimaries_P3_D65 as String) {
                cgColorSpace = CGColorSpace(name: CGColorSpace.displayP3)
            }
        }
        
        // Create a pixel buffer pool with the same pixel attributes as the input format description.
        let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey as String: outputRetainedBufferCountHint]
        var cvPixelBufferPool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes as NSDictionary?, pixelBufferAttributes as NSDictionary?, &cvPixelBufferPool)
        guard let pixelBufferPool = cvPixelBufferPool else {
            assertionFailure("Allocation failure: Could not allocate pixel buffer pool.")
            return (nil, nil, nil)
        }
        
        preallocateBuffers(pool: pixelBufferPool, allocationThreshold: outputRetainedBufferCountHint)
        
        // Get the output format description
        var pixelBuffer: CVPixelBuffer?
        var outputFormatDescription: CMFormatDescription?
        let auxAttributes = [kCVPixelBufferPoolAllocationThresholdKey as String: outputRetainedBufferCountHint] as NSDictionary
        CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pixelBufferPool, auxAttributes, &pixelBuffer)
        if let pixelBuffer = pixelBuffer {
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                         imageBuffer: pixelBuffer,
                                                         formatDescriptionOut: &outputFormatDescription)
        }
        pixelBuffer = nil
        
        return (pixelBufferPool, cgColorSpace, outputFormatDescription)
    }
    
    /// 预分配缓冲区
    private func preallocateBuffers(pool: CVPixelBufferPool, allocationThreshold: Int) {
        var pixelBuffers = [CVPixelBuffer]()
        var error: CVReturn = kCVReturnSuccess
        let auxAttributes = [kCVPixelBufferPoolAllocationThresholdKey as String: allocationThreshold] as NSDictionary
        var pixelBuffer: CVPixelBuffer?
        while error == kCVReturnSuccess {
            error = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, auxAttributes, &pixelBuffer)
            if let pixelBuffer = pixelBuffer {
                HSLog("成功创建次数")
                pixelBuffers.append(pixelBuffer)
            }
            pixelBuffer = nil
        }
        pixelBuffers.removeAll()
    }

}

// MARK: - Private Method
extension PCameraMultiManager {
    
    /// 配置session
    private func configSession() {
        guard setupResult == .success else {
            return
        }
        
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            HSLog("MultiCam not supported on this device")
            setupResult = .multiCamNotSupported
            return
        }
        
        // 配置session
        beginConfiguration()
        defer {
            commitConfiguration()
            if setupResult == .success {
                
            }
        }
        
        // 配置后置相机
        guard configBackCamera() else {
            setupResult = .configurationFailed
            return
        }
        
        // 配置前置相机
        guard configFrontCamera() else {
            setupResult = .configurationFailed
            return
        }
        
        // 配置麦克风
        guard configAudio() else {
            setupResult = .configurationFailed
            return
        }
    }
    
    /// 配置后置镜头
    /// - Returns: 是否成功
    private func configBackCamera() -> Bool {
        beginConfiguration()
        defer {
            commitConfiguration()
        }
        
        // Find the back camera
        guard let backCamera = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) else {
            setupResult = .configurationFailed
            HSLog("Could not find the back camera")
            return false
        }
        
        // Add the back camera input to the session
        do {
            backVideoDeviceInput = try AVCaptureDeviceInput(device: backCamera)
        } catch {
            HSLog("🤔🤔Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return false
        }
        
        guard session.canAddInput(backVideoDeviceInput) else {
            HSLog("🤔🤔Could not add video device input to the session")
            setupResult = .configurationFailed
            return false
        }
        session.addInputWithNoConnections(backVideoDeviceInput)
        
        // Find the back camera device input's video port
        guard let backInputPort = backVideoDeviceInput.ports(for: .video, sourceDeviceType: backCamera.deviceType, sourceDevicePosition: backCamera.position).first else {
            HSLog("Could not find the back camera device input's video port")
            setupResult = .configurationFailed
            return false
        }
        
        // Add the back camera video data output
        guard session.canAddOutput(backVideoDataOutput) else {
            HSLog("Could not add the back camera video data output")
            setupResult = .configurationFailed
            return false
        }
        session.addOutputWithNoConnections(backVideoDataOutput)
        backVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        backVideoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        
        // Connect the back camera device input to the back camera video data output
        let backCameraConnection = AVCaptureConnection(inputPorts: [backInputPort], output: backVideoDataOutput)
        guard session.canAddConnection(backCameraConnection) else {
            print("Could not add a connection to the back camera video data output")
            return false
        }
        session.addConnection(backCameraConnection)
        backCameraConnection.videoOrientation = .portrait
        
        return true
    }
    
    /// 配置前置镜头
    /// - Returns: 是否成功
    private func configFrontCamera() -> Bool {
        beginConfiguration()
        defer {
            commitConfiguration()
        }
        
        // Find the back camera
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            setupResult = .configurationFailed
            HSLog("Could not find the back camera")
            return false
        }
        
        // Add the back camera input to the session
        do {
            frontVideoDeviceInput = try AVCaptureDeviceInput(device: frontCamera)
        } catch {
            HSLog("🤔🤔Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return false
        }
        
        guard session.canAddInput(frontVideoDeviceInput) else {
            HSLog("🤔🤔Could not add video device input to the session")
            setupResult = .configurationFailed
            return false
        }
        session.addInputWithNoConnections(frontVideoDeviceInput)
        
        // Find the back camera device input's video port
        guard let frontInputPort = frontVideoDeviceInput.ports(for: .video, sourceDeviceType: frontCamera.deviceType, sourceDevicePosition: frontCamera.position).first else {
            HSLog("Could not find the back camera device input's video port")
            setupResult = .configurationFailed
            return false
        }
        
        // Add the back camera video data output
        guard session.canAddOutput(frontVideoDataOutput) else {
            HSLog("Could not add the back camera video data output")
            setupResult = .configurationFailed
            return false
        }
        session.addOutputWithNoConnections(frontVideoDataOutput)
        frontVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        frontVideoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        
        // Connect the back camera device input to the back camera video data output
        let frontCameraConnection = AVCaptureConnection(inputPorts: [frontInputPort], output: frontVideoDataOutput)
        guard session.canAddConnection(frontCameraConnection) else {
            print("Could not add a connection to the back camera video data output")
            return false
        }
        session.addConnection(frontCameraConnection)
        frontCameraConnection.videoOrientation = .portrait
        frontCameraConnection.automaticallyAdjustsVideoMirroring = false
        frontCameraConnection.isVideoMirrored = true
        
        return true
    }
    
    /// 配置音频
    /// - Returns: 是否成功
    private func configAudio() -> Bool {
        beginConfiguration()
        defer {
            commitConfiguration()
        }
        
        // Find the microphone
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("Could not find the microphone")
            return false
        }
        
        // Add the microphone input to the session
        do {
            audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            
            guard let audioDeviceInput = audioDeviceInput, session.canAddInput(audioDeviceInput) else {
                print("Could not add microphone device input")
                return false
            }
            session.addInputWithNoConnections(audioDeviceInput)
        } catch {
            print("Could not create microphone input: \(error)")
            return false
        }
        
        // Find the audio device input's back audio port
        guard let backMicrophonePort = audioDeviceInput.ports(for: .audio,
                                                              sourceDeviceType: audioDevice.deviceType,
                                                              sourceDevicePosition: .back).first else {
            print("Could not find the back camera device input's audio port")
            return false
        }
        
        // Find the audio device input's front audio port
        guard let frontMicrophonePort = audioDeviceInput.ports(for: .audio,
                                                               sourceDeviceType: audioDevice.deviceType,
                                                               sourceDevicePosition: .front).first else {
            print("Could not find the front camera device input's audio port")
            return false
        }
        
        // Add the back microphone audio data output
        guard session.canAddOutput(backAudioDataOutput) else {
            print("Could not add the back microphone audio data output")
            return false
        }
        session.addOutputWithNoConnections(backAudioDataOutput)
        backAudioDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        
        // Add the front microphone audio data output
        guard session.canAddOutput(frontAudioDataOutput) else {
            print("Could not add the front microphone audio data output")
            return false
        }
        session.addOutputWithNoConnections(frontAudioDataOutput)
        frontAudioDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        
        // Connect the back microphone to the back audio data output
        let backAudioDataOutputConnection = AVCaptureConnection(inputPorts: [backMicrophonePort], output: backAudioDataOutput)
        guard session.canAddConnection(backAudioDataOutputConnection) else {
            print("Could not add a connection to the back microphone audio data output")
            return false
        }
        session.addConnection(backAudioDataOutputConnection)
        
        // Connect the front microphone to the back audio data output
        let frontAudioDataOutputConnection = AVCaptureConnection(inputPorts: [frontMicrophonePort], output: frontAudioDataOutput)
        guard session.canAddConnection(frontAudioDataOutputConnection) else {
            print("Could not add a connection to the front microphone audio data output")
            return false
        }
        session.addConnection(frontAudioDataOutputConnection)
        
        return true
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
extension PCameraMultiManager {
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
extension PCameraMultiManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        HSLog("🤔🤔\(sampleBuffer)")
        
        if let videoDataOutput = output as? AVCaptureVideoDataOutput {
            connection.videoOrientation = .portrait
            delegate?.videoCaptureOutput(didOutput: sampleBuffer, fromOutput: videoDataOutput, isPip: backVideoDataOutput == output ? false : true)
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

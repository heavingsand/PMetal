//
//  MetalMultiCameraVC.swift
//  PanSwift
//
//  Created by Pan on 2022/6/9.
//

import UIKit
import CoreMedia
import MetalKit
import Photos

class MetalMultiCameraVC: MetalBasicVC {
    
    // MARK: - Property
    
    let cameraManager = PCameraMultiManager()
    
    /// 顶点缓冲区
    private var vertexBuffer: MTLBuffer?
    
    /// 渲染管道状态
    private var pipelineState: MTLRenderPipelineState!
    
    /// 并行计算管道状态
    private var computePipelineState: MTLComputePipelineState!
    
    /// 采样状态
    private var samplerState: MTLSamplerState!
    
    /// 图片纹理
    private var texture: MTLTexture?
    
    /// 录制按钮
    lazy var recordButton: UIButton = {
        let recordButton = UIButton()
        self.view.addSubview(recordButton)
        recordButton.snp.makeConstraints { make in
            make.bottom.equalTo(-40)
            make.centerX.equalToSuperview()
            make.size.equalTo(CGSize(width: 60, height: 60))
        }
        recordButton.backgroundColor = .red
        recordButton.setTitle("录制", for: .normal)
        recordButton.layer.cornerRadius = 30
        return recordButton
    }()
    
    private let recordQueue = DispatchQueue(label: "com.pkh.recordQueue")
    
    private var cameraRecorder: PCameraRecorder?
    
    /** -----------画中画相关属性------------*/
    
    /// 表示画中画相对于全屏视频预览的位置和大小的归一化CGRect
    var pipFrame = CGRect.zero
    
    private(set) var isPrepared = false
    
    private(set) var inputFormatDescription: CMFormatDescription?
    
    private(set) var outputFormatDescription: CMFormatDescription?
    
    /// 像素缓冲池
    private var outputPixelBufferPool: CVPixelBufferPool?
    
    private var videoTrackSourceFormatDescription: CMFormatDescription?
    
    private var currentPiPSampleBuffer: CVImageBuffer?

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView.frame = CGRect(x: 0,
                               y: 44,
                               width: UIScreen.main.bounds.size.width,
                               height: UIScreen.main.bounds.size.width / 9.0 * 16.0)
        mtkView.delegate = self

        cameraManager.delegate = self
        cameraManager.prepare()
        
        setupMetal()
        
        recordButton.addTarget(self, action: #selector(recordClick), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        cameraManager.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        cameraManager.stopRunning()
    }
    
    @objc func recordClick(_ sender: UIButton) {
        sender.isEnabled = false
        
        recordQueue.async {
            defer {
                DispatchQueue.main.async {
                    sender.isEnabled = true
                    
                    if let recorder = self.cameraRecorder {
                        sender.setTitle(recorder.isRecording ? "停止" : "录制", for: .normal)
                    }
                }
            }
            
            let isRecording = self.cameraRecorder?.isRecording ?? false
            if !isRecording {
                guard let audioSettings = self.cameraManager.audioSetting() else {
                    print("Could not create audio settings")
                    return
                }
                
                guard let videoSettings = self.cameraManager.videoSetting() else {
                    print("Could not create video settings")
                    return
                }
                
                guard let videoTransform = self.cameraManager.videoTransform() else {
                    print("Could not create video transform")
                    return
                }
                
                self.cameraRecorder = PCameraRecorder(audioSettings: audioSettings, videoSettings: videoSettings, videoTransform: videoTransform)
                self.cameraRecorder?.startRecording()
            } else {
                self.cameraRecorder?.stopRecording(completion: { movieURL in
                    self.saveMovieToPhotoLibrary(movieURL)
                })
            }
        }
    }

    // MARK: - Method
    
    /// metal配置
    func setupMetal() {
        setupVertex()
        setupPipeline()
        setupSampler()
    }
    
    /// 设置顶点
    func setupVertex() {
        // 顶点坐标x、y、z、w
        let vertexData: [Float] = [
            -1.0, -1.0, 0.0,
            -1.0, 1.0, 0.0,
            1.0, -1.0, 0.0,
            1.0, 1.0, 0.0,
        ]
        
        // 创建顶点缓冲区
        vertexBuffer = metalContext.device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: .storageModeShared)
    }
    
    /// 设置渲染管道
    func setupPipeline() {
        let library = metalContext.library
        // 顶点shader，texture_vertex_main是函数名
        let vertexFuction = library?.makeFunction(name: "texture_vertex_main")
        // 片元shader，texture_fragment_main是函数名
        let fragmentFunction = library?.makeFunction(name: "texture_fragment_main")
        
        let pipelineDes = MTLRenderPipelineDescriptor()
        pipelineDes.vertexFunction = vertexFuction
        pipelineDes.fragmentFunction = fragmentFunction
        pipelineDes.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        guard let pipelineState = try? metalContext.device.makeRenderPipelineState(descriptor: pipelineDes) else {
            HSLog("管道状态异常!")
            return
        }
        
        self.pipelineState = pipelineState
        
        // 并行计算函数
        guard let kernelFunction = library?.makeFunction(name: "pipMixer") else {
            HSLog("并行函数创建异常!")
            assertionFailure("并行函数创建异常!")
            return
        }
        
        guard let computePipelineState = try? metalContext.device.makeComputePipelineState(function: kernelFunction) else {
            HSLog("并行管道状态异常!")
            return
        }
        self.computePipelineState = computePipelineState
    }
    
    /// 设置采样状态
    func setupSampler() {
        let samplerDes = MTLSamplerDescriptor()
        samplerDes.sAddressMode = .clampToEdge
        samplerDes.tAddressMode = .clampToEdge
        samplerDes.minFilter = .nearest
        samplerDes.magFilter = .linear
        samplerDes.mipFilter = .linear
        
        guard let samplerState = metalContext.device.makeSamplerState(descriptor: samplerDes) else {
            HSLog("采样状态异常!")
            return
        }
        self.samplerState = samplerState
    }
    
    /// 准备画中画
    func preparePipMixer(with videoFormatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int) {
        (outputPixelBufferPool, _, outputFormatDescription) = cameraManager.allocateOutputBufferPool(with: videoFormatDescription,
                                                                                                     outputRetainedBufferCountHint: outputRetainedBufferCountHint)
        
        if outputPixelBufferPool == nil {
            HSLog("像素缓冲池创建失败")
            return
        }
        
        isPrepared = true
    }
    
    struct MixerParameters {
        var pipPosition: SIMD2<Float>
        var pipSize: SIMD2<Float>
    }
    
    func mix(fullScreenPixelBuffer: CVPixelBuffer, pipPixelBuffer: CVPixelBuffer, fullScreenPixelBufferIsFrontCamera: Bool) -> CVPixelBuffer? {
        guard isPrepared,
            let outputPixelBufferPool = outputPixelBufferPool else {
                assertionFailure("Invalid state: Not prepared")
                return nil
        }
        
        var newPixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, outputPixelBufferPool, &newPixelBuffer)
        guard let outputPixelBuffer = newPixelBuffer else {
            print("Allocation failure: Could not get pixel buffer from pool (\(self.description))")
            return nil
        }
        
        guard let outputTexture = metalContext.makeTextureFromCVPixelBuffer(pixelBuffer: outputPixelBuffer),
              let fullScreenTexture = metalContext.makeTextureFromCVPixelBuffer(pixelBuffer: fullScreenPixelBuffer),
              let pipTexture = metalContext.makeTextureFromCVPixelBuffer(pixelBuffer: pipPixelBuffer) else {
                return nil
        }
        
        let pipPosition = SIMD2(Float(pipFrame.origin.x) * Float(fullScreenTexture.width), Float(pipFrame.origin.y) * Float(fullScreenTexture.height))
        let pipSize = SIMD2(Float(pipFrame.size.width) * Float(pipTexture.width), Float(pipFrame.size.height) * Float(pipTexture.height))
        var parameters = MixerParameters(pipPosition: pipPosition, pipSize: pipSize)
        
        // Set up command queue, buffer, and encoder
        guard let commandQueue = metalContext.commandQueue,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeComputeCommandEncoder(),
            let computePipelineState = computePipelineState else {
                print("Failed to create Metal command encoder")
                
            if let textureCache = metalContext.textureCache {
                CVMetalTextureCacheFlush(textureCache, 0)
            }
                
            return nil
        }
        
        commandEncoder.label = "pip Video Mixer"
        commandEncoder.setComputePipelineState(computePipelineState)
        commandEncoder.setTexture(fullScreenTexture, index: 0)
        commandEncoder.setTexture(pipTexture, index: 1)
        commandEncoder.setTexture(outputTexture, index: 2)
        commandEncoder.setBytes(UnsafeMutableRawPointer(&parameters), length: MemoryLayout<MixerParameters>.size, index: 0)
        
        // Set up thread groups as described in https://developer.apple.com/reference/metal/mtlcomputecommandencoder
        let width = computePipelineState.threadExecutionWidth
        let height = computePipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerThreadgroup = MTLSizeMake(width, height, 1)
        let threadgroupsPerGrid = MTLSize(width: (fullScreenTexture.width + width - 1) / width,
                                          height: (fullScreenTexture.height + height - 1) / height,
                                          depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        commandEncoder.endEncoding()
        commandBuffer.commit()
        
        texture = outputTexture
        
        return outputPixelBuffer
    }
    
    /// CVPixelBuffer转CMSampleBuffer
    private func createVideoSampleBufferWithPixelBuffer(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) -> CMSampleBuffer? {
        guard let videoTrackSourceFormatDescription = videoTrackSourceFormatDescription else {
            return nil
        }
        
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: presentationTime, decodeTimeStamp: .invalid)
        
        let err = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                     imageBuffer: pixelBuffer,
                                                     dataReady: true,
                                                     makeDataReadyCallback: nil,
                                                     refcon: nil,
                                                     formatDescription: videoTrackSourceFormatDescription,
                                                     sampleTiming: &timingInfo,
                                                     sampleBufferOut: &sampleBuffer)
        if sampleBuffer == nil {
            print("Error: Sample buffer creation failed (error code: \(err))")
        }
        
        return sampleBuffer
    }
    
    /// 渲染
    /// - Parameter texture: 纹理对象
    func render(with texture: MTLTexture) {
        // 获取当前帧的可绘制内容
        guard let drawble = mtkView.currentDrawable else {
            HSLog("drawable get fail")
            return
        }
        
        // 获取命令缓冲区
        guard let commandBuffer = metalContext.commandQueue.makeCommandBuffer() else {
            HSLog("CommandBuffer make fail")
            return
        }
        
        // 获取过程描述符, MTLRenderPassDescriptor描述一系列attachments的值，类似GL的FrameBuffer；同时也用来创建MTLRenderCommandEncoder
        guard let passDescriptor = mtkView.currentRenderPassDescriptor else {
            HSLog("passDescriptor get fail")
            return
        }
        
        // 配置编码渲染命令
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            HSLog("RenderEncoder make fail")
            return
        }
        // 设置渲染管道，以保证顶点和片元两个shader会被调用
        renderEncoder.setRenderPipelineState(pipelineState)
        // 设置顶点缓存
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        // 设置片段纹理
        renderEncoder.setFragmentTexture(texture, index: 0)
        // 设置片段采样状态
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        // 绘制显示区域
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        // 完成向渲染命令编码器发送命令并完成帧
        renderEncoder.endEncoding()
        
        // 显示
        commandBuffer.present(drawble)
        // 提交
        commandBuffer.commit()
    }
    
    /// 保存视频到相册
    private func saveMovieToPhotoLibrary(_ movieURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                // Save the movie file to the photo library and clean up.
                PHPhotoLibrary.shared().performChanges({
                    let options = PHAssetResourceCreationOptions()
                    options.shouldMoveFile = true
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .video, fileURL: movieURL, options: options)
                }, completionHandler: { success, error in
                    if !success {
                        print("\(Bundle.main.applicationName) couldn't save the movie to your photo library: \(String(describing: error))")
                    } else {
                        // Clean up
                        if FileManager.default.fileExists(atPath: movieURL.path) {
                            do {
                                try FileManager.default.removeItem(atPath: movieURL.path)
                            } catch {
                                print("Could not remove file at url: \(movieURL)")
                            }
                        }
                    }
                })
            } else {
                DispatchQueue.main.async {
                    let alertMessage = "Alert message when the user has not authorized photo library access"
                    let message = NSLocalizedString("\(Bundle.main.applicationName) does not have permission to access the photo library", comment: alertMessage)
                    let alertController = UIAlertController(title: Bundle.main.applicationName, message: message, preferredStyle: .alert)
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
}

// MARK: - 相机代理
extension MetalMultiCameraVC: MultiCameraManagerDelegate {
    
    func videoCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput videoDataOutput: AVCaptureVideoDataOutput, isPip: Bool) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        if videoTrackSourceFormatDescription == nil {
            videoTrackSourceFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        }
        
        if isPip {
            currentPiPSampleBuffer = pixelBuffer
        } else {
            guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                return
            }
            
            guard let pipPixelBuffer = currentPiPSampleBuffer else {
                return
            }
            
            if !isPrepared {
                preparePipMixer(with: formatDescription, outputRetainedBufferCountHint: 3)
            }
            
            pipFrame = CGRect(x: 0.7, y: 0.7, width: 0.25, height: 0.25)
            
            // Mix the full screen pixel buffer with the pip pixel buffer
            // When the PIP is the back camera, the primaryPixelBuffer is the front camera
            guard let mixedPixelBuffer = mix(fullScreenPixelBuffer: pixelBuffer,
                                             pipPixelBuffer: pipPixelBuffer,
                                             fullScreenPixelBufferIsFrontCamera: !isPip) else {
                                                            print("Unable to combine video")
                                                            return
            }
            
            if let recorder = cameraRecorder, recorder.isRecording {
                guard let finalVideoSampleBuffer = createVideoSampleBufferWithPixelBuffer(mixedPixelBuffer,
                                                                                          presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) else {
                    print("Error: Unable to create sample buffer from pixelbuffer")
                    return
                }
                
                recorder.recordVideo(sampleBuffer: finalVideoSampleBuffer)
            }
        }
    }
    
    func audioCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput audioDataOutput: AVCaptureAudioDataOutput) {
        
    }
    
}

// MARK: - MTKView代理
extension MetalMultiCameraVC: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("MTKView size: \(size)")
    }

    
    func draw(in view: MTKView) {
        guard let texture = self.texture else { return }

        render(with: texture)
    }
}


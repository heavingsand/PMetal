//
//  MetalCameraVC.swift
//  PanSwift
//
//  Created by Pan on 2022/1/21.
//

import UIKit
import MetalKit
import CoreMedia
import Photos

class MetalCameraVC: MetalBasicVC {
    
    // MARK: - Property
    let cameraManager = PCameraManager()
    
    /// 顶点缓冲区
    private var vertexBuffer: MTLBuffer?
    
    /// 渲染管道状态
    private var renderpipelineState: MTLRenderPipelineState!
    
    /// 计算管道状态
    private var computePipelineState: MTLComputePipelineState!
    
    /// 采样状态
    private var samplerState: MTLSamplerState!
    
    /// 图片纹理
    private var texture: MTLTexture?
    
    /// 是否已经准备好渲染
    private var isPrepared = false
    
    /// 像素缓冲池
    private var outputPixelBufferPool: CVPixelBufferPool?
    
    /// 视频描述对象
    private var videoTrackSourceFormatDescription: CMFormatDescription?
    
    /// 录制按钮
    lazy var recordButton: UIButton = {
        let recordButton = UIButton()
        self.view.addSubview(recordButton)
        recordButton.snp.makeConstraints { make in
            make.bottom.equalTo(-80)
            make.left.equalTo(10)
            make.size.equalTo(CGSize(width: 60, height: 60))
        }
        recordButton.backgroundColor = .red
        recordButton.setTitle("录制", for: .normal)
        recordButton.layer.cornerRadius = 30
        return recordButton
    }()
    
    private let recordQueue = DispatchQueue(label: "com.pkh.recordQueue")
    
    private var cameraRecorder: PCameraRecorder?

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
    
    // MARK: - Event
    
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
                    PCameraUtils.saveMovieToPhotoLibrary(movieURL)
                })
            }
        }
    }
    
    // MARK: - Method
    
    /// Metal配置
    func setupMetal() {
        setupVertex()
        setupPipeline()
        setupSampler()
    }
    
    /// 设置顶点
    func setupVertex() {
        /// 顶点坐标x、y、z、w
        let vertextData:[Float] = [
            -1.0, -1.0, 0.0,
            -1.0, 1.0, 0.0,
            1.0, -1.0, 0.0,
            1.0, 1.0, 0.0,
        ]
        
        // 创建顶点缓冲区
        vertexBuffer = metalContext.device.makeBuffer(bytes: vertextData, length: vertextData.count * MemoryLayout<Float>.size, options: .storageModeShared)
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
        
        self.renderpipelineState = pipelineState
        
        guard let kernelFunction = library?.makeFunction(name: "lut_texture_kernel") else {
            HSLog("计算函数创建异常!")
            return
        }
        
        guard let computePipelineState = try? metalContext.device.makeComputePipelineState(function: kernelFunction) else {
            HSLog("管道状态异常!")
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
    
    /// 准备渲染
    func prepareRender(with videoFormatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int) {
        (outputPixelBufferPool, _, _) = PCameraUtils.allocateOutputBufferPool(with: videoFormatDescription,
                                                                                                    outputRetainedBufferCountHint: outputRetainedBufferCountHint)
        
        if outputPixelBufferPool == nil {
            HSLog("像素缓冲池创建失败")
            return
        }
        
        isPrepared = true
    }
    
    /// 旋转渲染
    func rotationRender(with pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        guard isPrepared, let outputPixelBufferPool = outputPixelBufferPool else {
            assertionFailure("Invalid state: Not prepared")
            return nil
        }
        
        var newPixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, outputPixelBufferPool, &newPixelBuffer)
        guard let outputPixelBuffer = newPixelBuffer else {
            print("Allocation failure: Could not get pixel buffer from pool (\(self.description))")
            return nil
        }
        
        guard let inputTexture = metalContext.makeTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer),
              let outputTexture = metalContext.makeTextureFromCVPixelBuffer(pixelBuffer: outputPixelBuffer)else {
            return nil
        }
        
        // 获取命令缓冲区
        guard let commandBuffer = metalContext.commandQueue.makeCommandBuffer() else {
            HSLog("CommandBuffer make fail")
            return nil
        }
        
        // 计划在GPU上并行执行的线程数
        let width = computePipelineState.threadExecutionWidth;
        // 每个线程组的总线程数除以线程执行宽度
        let height = computePipelineState.maxTotalThreadsPerThreadgroup / width
        // 网格大小
        let threadsPerGroup = MTLSizeMake(width, height, 1)
        let threadsPerGrid = MTLSize(width: (inputTexture.width + width - 1) / width,
                                     height: (inputTexture.height + height - 1) / height,
                                     depth: 1)
        
        // 配置编码渲染命令
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            HSLog("RenderEncoder make fail")
            return nil
        }
        encoder.label = "filter encoder"
        encoder.pushDebugGroup("lut-filter")
        encoder.setComputePipelineState(computePipelineState)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        encoder.setSamplerState(samplerState, index: 0)
        encoder.dispatchThreadgroups(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.popDebugGroup()
        encoder.endEncoding()
        
        return outputPixelBuffer
    }
    
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
        renderEncoder.setRenderPipelineState(renderpipelineState)
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
}

// MARK: - 相机代理
extension MetalCameraVC: CameraManagerDelegate {
    
    func videoCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput videoDataOutput: AVCaptureVideoDataOutput) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        texture = metalContext.makeTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer)
        
        if !isPrepared {
            guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                return
            }
            prepareRender(with: formatDescription, outputRetainedBufferCountHint: 3)
        }
        
        if let recorder = cameraRecorder, recorder.isRecording, let videoTrackSourceFormatDescription = videoTrackSourceFormatDescription {
            guard let finalVideoSampleBuffer = PCameraUtils.videoSampleBufferWithPixelBuffer(with: pixelBuffer,
                                                                                             videoTrackSourceFormatDescription: videoTrackSourceFormatDescription,
                                                                                             presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) else {
                print("Error: Unable to create sample buffer from pixelbuffer")
                return
            }
            
            recorder.recordVideo(sampleBuffer: finalVideoSampleBuffer)
        }
    }
    
    func audioCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput audioDataOutput: AVCaptureAudioDataOutput) {
        
    }
    
}

// MARK: - MTKView代理
extension MetalCameraVC: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("MTKView size: \(size)")
    }

    
    func draw(in view: MTKView) {
        guard let texture = self.texture else { return }
        
        render(with: texture)
    }
}

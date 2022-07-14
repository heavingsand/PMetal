//
//  MetalDepthCameraVC.swift
//  PanSwift
//
//  Created by Pan on 2022/7/13.
//

import UIKit
import CoreMedia
import MetalKit
import AVFoundation
import MetalPerformanceShaders

class MetalDepthCameraVC: MetalBasicVC {
    
    // MARK: - Property
    
    /// 相机管理类
    private let cameraManager = PCameraManager()
    
    /// 顶点缓冲区
    private var vertexBuffer: MTLBuffer?
    
    /// 管道渲染状态
    private var pipelineState: MTLRenderPipelineState!
    
    /// 并行计算管道状态
    private var computePipelineState: MTLComputePipelineState!
    
    /// 采样状态
    private var samplerState: MTLSamplerState!
    
    /// 图片纹理
    private var texture: MTLTexture?
    
    /// 毛玻璃纹理
    private var blurTexture: MTLTexture?
    
    /// 深度纹理
    private var depthTexture: MTLTexture?

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView.frame = CGRect(x: 0,
                               y: 44,
                               width: UIScreen.main.bounds.size.width,
                               height: UIScreen.main.bounds.size.width / 9.0 * 16.0)
        mtkView.delegate = self
        
        cameraManager.delegate = self
        cameraManager.deviceType = .builtInTrueDepthCamera
        cameraManager.devicePosition = .front
        cameraManager.prepare()
        
        setupMetal()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        cameraManager.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        cameraManager.stopRunning()
    }
    
    // MARK: - Method
    
    /// metal配置
    func setupMetal() {
        setupVertex()
        setupPipeline()
        setupSampler()
    }
    
    func setupVertex() {
        let vertexData: [Float] = [
            -1.0, -1.0, 0.0,
            -1.0, 1.0, 0.0,
            1.0, -1.0, 0.0,
            1.0, 1.0, 0.0
        ]
        
        // 创建顶点缓冲区
        vertexBuffer = metalContext.device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: .storageModeShared)
    }
    
    /// 设置渲染管道
    func setupPipeline() {
        let library = metalContext.library
        // 顶点shader，texture_vertex_main是函数名
        let vertexFuction = library?.makeFunction(name: "depth_texture_vertex")
        // 片元shader，texture_fragment_main是函数名
        let fragmentFunction = library?.makeFunction(name: "depth_texture_fragment")
        
        // 设置渲染管道
        let pipelineDes = MTLRenderPipelineDescriptor()
        pipelineDes.vertexFunction = vertexFuction
        pipelineDes.fragmentFunction = fragmentFunction
        pipelineDes.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        guard let pipelineState = try? metalContext.device.makeRenderPipelineState(descriptor: pipelineDes) else {
            HSLog("管道状态异常!")
            return
        }
        self.pipelineState = pipelineState
        
        // 设置计算管道
        guard let kernelFunction = library?.makeFunction(name: "pipMixer") else {
            HSLog("并行函数创建异常!")
            return
        }
        
        guard let computePipelineState = try? metalContext.device.makeComputePipelineState(function: kernelFunction) else {
            HSLog("创建并行管道状态异常!")
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
    
    /// 渲染
    func render() {
        guard let texture = texture, let depthTexture = depthTexture else {
            print("无效纹理")
            return
        }
        
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
        
        /// 创建毛玻璃纹理
        let blurTextureDes = MTLTextureDescriptor()
        blurTextureDes.pixelFormat = .bgra8Unorm
        blurTextureDes.width = texture.width
        blurTextureDes.height = texture.height
        blurTextureDes.usage = [.shaderRead, .shaderWrite]
        
        guard let blurTexture = metalContext.device.makeTexture(descriptor: blurTextureDes) else {
            HSLog("毛玻璃纹理创建失败")
            return
        }
        
        let gaussianBlur = MPSImageGaussianBlur(device: metalContext.device, sigma: 30)
        gaussianBlur.encode(commandBuffer: commandBuffer, sourceTexture: texture, destinationTexture: blurTexture)
        
        // 获取过程描述符, MTLRenderPassDescriptor描述一系列attachments的值，类似GL的FrameBuffer, 同时也用来创建MTLRenderCommandEncoder
        guard let passDescriptor = mtkView.currentRenderPassDescriptor else {
            HSLog("passDescriptor get fail")
            return
        }
        
        // 配置渲染编码器
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            HSLog("RenderEncoder make fail")
            return
        }
        // 设置渲染管道，以保证顶点和片元两个shader会被调用
        renderEncoder.setRenderPipelineState(pipelineState)
        // 设置顶点缓存
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        // 设置视频纹理
        renderEncoder.setFragmentTexture(texture, index: 0)
        // 设置毛玻璃纹理
        renderEncoder.setFragmentTexture(blurTexture, index: 1)
        // 设置深度纹理
        renderEncoder.setFragmentTexture(depthTexture, index: 2)
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
extension MetalDepthCameraVC: CameraManagerDelegate {
    
    func videoOutputSynchronizer(didOutput videoSampleBuffer: CMSampleBuffer, depthPixelBuffer: CVPixelBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(videoSampleBuffer) else { return }
        
        self.texture = metalContext.makeTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer)
        self.depthTexture = metalContext.makeTextureFromCVPixelBuffer(pixelBuffer: depthPixelBuffer, pixelFormat: .r16Float)
    }
    
}

// MARK: - MTKView代理
extension MetalDepthCameraVC: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("MTKView size: \(size)")
    }

    
    func draw(in view: MTKView) {
        render()
    }
}

//
//  MetalCameraVC.swift
//  PanSwift
//
//  Created by Pan on 2022/1/21.
//

import UIKit
import MetalKit
import CoreMedia

class MetalCameraVC: MetalBasicVC {
    
    // MARK: - Property
    let cameraManager = PCameraManager()
    
    /// 顶点缓冲区
    private var vertexBuffer: MTLBuffer?
    
    /// 渲染管道状态
    private var pipelineState: MTLRenderPipelineState!
    
    /// 采样状态
    private var samplerState: MTLSamplerState!
    
    /// 图片纹理
    private var texture: MTLTexture!
    

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMetal()
        cameraManager.delegate = self
        cameraManager.prepare()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
//        mtkView = MTKView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height), device: metalContext.device)
        mtkView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height)
//        mtkView.center = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height / 2)
        cameraManager.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        cameraManager.stopRunning()
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
        
        self.pipelineState = pipelineState
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
}

// MARK: - 相机代理
extension MetalCameraVC: CameraManagerDelegate {
    
    func captureOutput(didOutput sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        guard let texture = metalContext.makeTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer) else { return }
        
        render(with: texture)
    }
    
}

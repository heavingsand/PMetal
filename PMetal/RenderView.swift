//
//  RenderView.swift
//  PMetal
//
//  Created by Pan on 2022/7/26.
//

import Foundation
import MetalKit

public class RenderView: MTKView {
    
    // MARK: - Property
    
    /// 顶点缓冲区
    private var vertexBuffer: MTLBuffer?
    
    /// 渲染管道状态
    private var pipelineState: MTLRenderPipelineState?
    
    private var samplerState: MTLSamplerState?
    
    /// 图片纹理
    private var texture: MTLTexture?
    
    /// metal资源
    private let resources: Resources = Resources.share()
    
    // MARK: - Life Cycle
    public override init(frame frameRect: CGRect, device: MTLDevice?) {
        super .init(frame: frameRect, device: resources.device)
        delegate = self
        setupVertex()
        setupPipeline()
//        setupSampler()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

// MARK: - Public Method
extension RenderView {
    public func pushBuffer(with pixelBuffer: CVPixelBuffer) {
        texture = resources.makeTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer, pixelFormat: .bgra8Unorm)
    }
}

// MARK: - Private Method
extension RenderView {
    
    /// 设置顶点
    private func setupVertex() {
        // 顶点坐标x、y、z、w
        let vertexData:[Float] = [
            -1.0, -1.0, 0.0, 1.0, 0.0, 1.0,
             -1.0, 1.0, 0.0, 1.0, 0.0, 0.0,
             1.0, -1.0, 0.0, 1.0, 1.0, 1.0,
             1.0, 1.0, 0.0, 1.0, 1.0, 0.0,
        ]
        
        // 创建顶点缓冲区
        vertexBuffer = resources.device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: .storageModeShared)
    }
    
    /// 设置渲染管道
    func setupPipeline() {
        let pipelineDes = MTLRenderPipelineDescriptor()
        pipelineDes.vertexFunction = resources.function(with: "render_vertex")
        pipelineDes.fragmentFunction = resources.function(with: "render_fragment")
        pipelineDes.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        guard let pipelineState = try? resources.device.makeRenderPipelineState(descriptor: pipelineDes) else {
            print("管道状态异常!")
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
        
        guard let samplerState = resources.device.makeSamplerState(descriptor: samplerDes) else {
            print("采样状态异常!")
            return
        }
        self.samplerState = samplerState
    }
}

// MARK: - MTKViewDelegate
extension RenderView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    public func draw(in view: MTKView) {
        guard let texture = self.texture else {
            return
        }
        
        guard let pipelineState = self.pipelineState else {
            return
        }
        
        // 获取当前帧的可绘制内容
        guard let drawble = currentDrawable else {
            print("drawable get fail")
            return
        }

        // 获取命令缓冲区
        guard let commandBuffer = resources.commandQueue.makeCommandBuffer() else {
            print("CommandBuffer make fail")
            return
        }

        // 获取过程描述符, MTLRenderPassDescriptor描述一系列attachments的值，类似GL的FrameBuffer；同时也用来创建MTLRenderCommandEncoder
        guard let passDescriptor = currentRenderPassDescriptor else {
            print("passDescriptor get fail")
            return
        }

        // 配置编码渲染命令
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            print("RenderEncoder make fail")
            return
        }
        
        // 设置渲染管道，以保证顶点和片元两个shader会被调用
        renderEncoder.setRenderPipelineState(pipelineState)
        // 设置顶点缓存
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        // 设置片段纹理
        renderEncoder.setFragmentTexture(texture, index: 0)
        // 设置片段采样状态
//        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
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

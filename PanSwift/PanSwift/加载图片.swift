//
//  加载图片.swift
//  PanSwift
//
//  Created by Pan on 2021/12/29.
//

import UIKit
import MetalKit

class MetalLoadImageVC: MetalBasicVC {
    
    /// 顶点缓冲区
    private var vertexBuffer: MTLBuffer?
    
    /// 渲染管道状态
    private var pipelineState: MTLRenderPipelineState!
    
    /// 采样状态
    private var samplerState: MTLSamplerState!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMetal()
        render()
    }
    
    func setupMetal() {
        let vertexData:[Float] = [
             -1.0, -1.0, 0.0,
             -1.0, 1.0, 0.0,
             1.0, -1.0, 0.0,
             1.0, 1.0, 0.0,
        ]
        
        vertexBuffer = metalContext.device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: .storageModeShared)
        
        let defaultLibrary = metalContext.device.makeDefaultLibrary()
        let vertexFunction = defaultLibrary?.makeFunction(name: "texture_vertex_main")
        let fragmentFunction = defaultLibrary?.makeFunction(name: "texture_fragment_main")
        
        let pipelineDes = MTLRenderPipelineDescriptor()
        pipelineDes.vertexFunction = vertexFunction
        pipelineDes.fragmentFunction = fragmentFunction
        pipelineDes.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        guard let pipelineState = try? metalContext.device.makeRenderPipelineState(descriptor: pipelineDes) else {
            HSLog("管道状态异常!")
            return
        }
        self.pipelineState = pipelineState
        
        // 配置
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

    func render() {
        // 获取可用的绘制纹理
        guard let drawable = mtkView.currentDrawable else {
            HSLog("drawable get fail")
            return
        }
        
        // 使用MTKTextureLoader加载图像数据
        let textureLoader = MTKTextureLoader(device: metalContext.device)
        let options = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.renderTarget.rawValue), // 设置纹理的用途是读写和用于渲染
            MTKTextureLoader.Option.SRGB: false, // 设置是否使用SRGB像素
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue) // 纹理只在GPU应用
        ]
        // 创建图片纹理
        guard let imageTexture = try? textureLoader.newTexture(name: "eye", scaleFactor: 1.0, bundle: nil, options: options) else {
            HSLog("imageTexture assignment failed")
            return
        }
        
        // 创建渲染过程描述符
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = drawable.texture
        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1)
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].loadAction = .clear

        // 获取命令缓冲区
        guard let commandBuffer = metalContext.commandQueue.makeCommandBuffer() else {
            HSLog("CommandBuffer make fail")
            return
        }

        // 配置编码渲染命令
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            HSLog("RenderEncoder make fail")
            return
        }
        // 设置显示区域
//        renderEncoder.setViewport(MTLViewport(originX: 0, originY: 0, width: 1417, height: 1417, znear: -1.0, zfar: 1.0))
        // 设置渲染管道，以保证顶点和片元两个shader会被调用
        renderEncoder.setRenderPipelineState(pipelineState)
        // 设置顶点缓存
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        // 设置片段纹理
        renderEncoder.setFragmentTexture(imageTexture, index: 0)
        // 设置片段采样状态
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        // 绘制
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        // 完成向渲染命令编码器发送命令并完成帧
        renderEncoder.endEncoding()
        
        // 显示
        commandBuffer.present(drawable)
        // 提交
        commandBuffer.commit()
    }
}

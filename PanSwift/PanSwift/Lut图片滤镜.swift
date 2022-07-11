//
//  MetalRenderImageVC.swift
//  PanSwift
//
//  Created by Pan on 2022/1/5.
//

import UIKit
import MetalKit

class MetalRenderImageVC: MetalBasicVC {
    
    /// 顶点缓冲区
    private var vertexBuffer: MTLBuffer?
    
    /// 渲染管道状态
    private var pipelineState: MTLRenderPipelineState!
    
    /// 采样状态
    private var samplerState: MTLSamplerState!
    
    /// 图片纹理
    private var imageTexture: MTLTexture!
    
    /// lut纹理
    private var lutTexture: MTLTexture!
    
    /// 顶点纹理
    struct TextureVertex {
        let position: SIMD4<Float>
        let texCoords: SIMD2<Float>
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMetal()
        render()
    }
    
    /// Metal配置
    func setupMetal() {
        setupVertex()
        setupPipeline()
        setupSampler()
        setupImageTexture()
        setupLutTexture()
    }
    
    /// 设置顶点
    func setupVertex() {
        // 顶点坐标: x、y、z、w 纹理坐标: x、y
        let vertexData:[Float] = [
            -1.0, -1.0, 0.0, 1.0, 0.0, 1.0,
             -1.0, 1.0, 0.0, 1.0, 0.0, 0.0,
             1.0, -1.0, 0.0, 1.0, 1.0, 1.0,
             1.0, 1.0, 0.0, 1.0, 1.0, 0.0,
        ]
        
//        let vertexData:[TextureVertex] = [
//            TextureVertex(position: simd_make_float4(-1.0, -1.0, 0.0, 1.0), texCoords: simd_make_float2(0.0, 1.0)),
//            TextureVertex(position: simd_make_float4(-1.0, 1.0, 0.0, 1.0), texCoords: simd_make_float2(0.0, 0.0)),
//            TextureVertex(position: simd_make_float4(1.0, -1.0, 0.0, 1.0), texCoords: simd_make_float2(1.0, 1.0)),
//            TextureVertex(position: simd_make_float4(1.0, 1.0, 0.0, 1.0), texCoords: simd_make_float2(1.0, 0.0)),
//        ]
        
        // 创建顶点缓冲区
        vertexBuffer = metalContext.device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: .storageModeShared)
    }
    
    /// 设置渲染管道
    func setupPipeline() {
        let defaultLibrary = metalContext.library
        // 顶点shader，texture_vertex_main是函数名
        let vertexFunction = defaultLibrary?.makeFunction(name: "lut_texture_vertex")
        // 片元shader，texture_fragment_main是函数名
        let fragmentFunction = defaultLibrary?.makeFunction(name: "lut_texture_fragment")
        
        let pipelineDes = MTLRenderPipelineDescriptor()
        pipelineDes.vertexFunction = vertexFunction
        pipelineDes.fragmentFunction = fragmentFunction
        pipelineDes.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // 创建图形渲染管道，耗性能操作不宜频繁调用
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
    
    /// 设置图片纹理
    func setupImageTexture() {
        // 使用MTKTextureLoader加载图像数据
        let textureLoader = MTKTextureLoader(device: metalContext.device)
        // 获取图片路径
        let imgPath = Bundle.main.path(forResource: "face.png", ofType: nil)
        let textureUrl = URL(fileURLWithPath: imgPath!)
        // 创建图片纹理
        /**
         使用MTKTextureLoader加载颜色查找表（Lookup Table）图像时，默认情况下它生成sRGB颜色范围的纹理，即使图像元数据中并不声明sRGB。如果这影响了滤镜的表现，将MTKTextureLoaderOptionSRGB设置为false让MTKTextureLoader按图像原始色彩空间加载即可
         */
        let options = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.renderTarget.rawValue), // 设置纹理的用途是读写和用于渲染
            MTKTextureLoader.Option.SRGB: false, // 设置是否使用SRGB像素
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue) // 纹理只在GPU应用
        ]
        guard let imageTexture = try? textureLoader.newTexture(URL: textureUrl, options: options) else {
            HSLog("diffuseTexture assignment failed")
            return
        }
        self.imageTexture = imageTexture
        
        // 获取图片
//        let imgPath = Bundle.main.path(forResource: "face.png", ofType: nil)
//        guard let image = UIImage(contentsOfFile: imgPath!) else {
//            print("图片加载失败")
//            return
//        }
//
//        // 创建纹理描述符
//        let textureDes = MTLTextureDescriptor()
//        textureDes.pixelFormat = .bgra8Unorm
//        textureDes.width = Int(image.size.width)
//        textureDes.height = Int(image.size.height)
//        textureDes.usage = .shaderRead
//
//        if (imageTexture == nil) {
//            imageTexture = metalContext.device.makeTexture(descriptor: textureDes)
//        }
//
//        let region = MTLRegionMake2D(0, 0, Int(image.size.width), Int(image.size.height))
//        let data = loadImage(with: image)
//        imageTexture?.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: 4 * Int(image.size.width))
//        data.deallocate()
    }
    
    /// 设置LUT纹理
    func setupLutTexture() {
        // 使用MTKTextureLoader加载图像数据
        let textureLoader = MTKTextureLoader(device: metalContext.device)
        // 创建图片纹理
        let options = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.renderTarget.rawValue), // 设置纹理的用途是读写和用于渲染
            MTKTextureLoader.Option.SRGB: false, // 设置是否使用SRGB像素
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue) // 纹理只在GPU应用
        ]
        guard let lutTexture = try? textureLoader.newTexture(name: "lut2", scaleFactor: 1, bundle: nil, options: options) else {
            HSLog("diffuseTexture assignment failed")
            return
        }
        
        self.lutTexture = lutTexture
    }

    /// 渲染
    func render() {
        // 获取可用的绘制纹理
        guard let drawable = mtkView.currentDrawable else {
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
        
        // lut参数配置
//        var params = LutFilterParameters(clipOriginX: 0,
//                                         clipOriginY: 0,
//                                         clipSizeX: UInt32(imageTexture.width),
//                                         clipSizeY: UInt32(imageTexture.height),
//                                         saturation: 1,
//                                         changeColor: 1,
//                                         changeCoord: 0)
        
        // 设置渲染管道，以保证顶点和片元两个shader会被调用
        renderEncoder.setRenderPipelineState(pipelineState)
        // 设置顶点缓存
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        // 设置片段纹理
        renderEncoder.setFragmentTexture(imageTexture, index: 0)
        // 设置lut纹理
        renderEncoder.setFragmentTexture(lutTexture, index: 1)
        // 设置片段采样状态
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        // 设置配置信息
//        renderEncoder.setFragmentBytes(&params, length: MemoryLayout.size(ofValue: params), index: 0)
        // 绘制显示区域
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        // 完成向渲染命令编码器发送命令并完成帧
        renderEncoder.endEncoding()
        
        // 显示
        commandBuffer.present(drawable)
        // 提交
        commandBuffer.commit()
    }
    
}

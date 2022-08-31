//
//  PMetalLutFilter.swift
//  PanSwift
//
//  Created by Pan on 2022/2/22.
//

import UIKit
import MetalPerformanceShaders

/// Lut滤镜参数配置
struct LutFilterParameters {
    let clipOriginX: UInt32
    let clipOriginY: UInt32
    let clipSizeX: UInt32
    let clipSizeY: UInt32
    let saturation: Float32
    let changeColor: UInt16
    let changeCoord: UInt16
}

class PMetalLutFilter: MPSUnaryImageKernel {

    // MARK: - Property
    
    // lut图片
    var lutImage: UIImage {
        get {
            return _lutImage
        }
        set {
            _lutImage = newValue
            
//            guard let cgImage = lutImage.cgImage else {
//                print("没有获取到图片的cgImage")
//                return
//            }
//
//            let width = cgImage.width
//            let height = cgImage.height
//
//            guard let data = calloc(width * height * 4, MemoryLayout<UInt8>.size) else {
//                print("data创建失败")
//                return
//            }
//
//            let context = CGContext(data: data,
//                                    width: width,
//                                    height: height,
//                                    bitsPerComponent: 8,
//                                    bytesPerRow: width * 4,
//                                    space: CGColorSpaceCreateDeviceRGB(),
//                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
//            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
//
//            let region = MTLRegionMake2D(0, 0, Int(lutImage.size.width), Int(lutImage.size.height))
//            lutTexture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: 4 * Int(lutImage.size.width))
//            data.deallocate()
            
            if lutTexture == nil {
                // 创建纹理描述符
                let textureDes = MTLTextureDescriptor()
                textureDes.pixelFormat = .bgra8Unorm
                textureDes.width = Int(_lutImage.size.width)
                textureDes.height = Int(_lutImage.size.height)
                textureDes.usage = .shaderRead
                
                lutTexture = device.makeTexture(descriptor: textureDes)
            }
            
            let region = MTLRegionMake2D(0, 0, Int(_lutImage.size.width), Int(_lutImage.size.height))
            let data = PCameraUtils.loadImageBytes(with: _lutImage)
            lutTexture?.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: 4 * Int(_lutImage.size.width))
            data.deallocate()
        }
    }
    
    private var _lutImage: UIImage = UIImage()
    
    // 滤镜强度
    var saturation: Float32 = 1.0
    
    // 滤镜范围
    var rect: CGRect = CGRect(x: 0, y: 0, width: 0, height: 0)
    
    // trans coord Y = 1 - Y
    var needCoordTrans: Bool = true
    
    // trans color R -> B / B -> R
    var needColorTrans: Bool = false
    
    // 渲染管道状态
    private var pipelineState: MTLComputePipelineState!
    
    // 采样状态
    private var samplerState: MTLSamplerState!

    // 纹理
    private var lutTexture: MTLTexture?
    
    override init(device: MTLDevice) {
        super .init(device: device)
        
        edgeMode = .clamp
        
        // 初始化渲染管道状态
        let library = device.makeDefaultLibrary()
        guard let function = library?.makeFunction(name: "lut_texture_kernel") else { return }
        guard let pipelineState = try? device.makeComputePipelineState(function: function) else { return }
        self.pipelineState = pipelineState

        // 初始化lut纹理
//        let textureDes = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 512, height: 512, mipmapped: false)
//        guard let lutTexture = device.makeTexture(descriptor: textureDes) else { return }
//        self.lutTexture = lutTexture
        
        // 初始化采样状态
        let samplerDes = MTLSamplerDescriptor()
        samplerDes.magFilter = .linear
        samplerDes.minFilter = .linear
        samplerDes.rAddressMode = .clampToEdge
        samplerDes.sAddressMode = .clampToEdge
        samplerDes.tAddressMode = .clampToEdge
        samplerDes.normalizedCoordinates = false
        guard let samplerState = device.makeSamplerState(descriptor: samplerDes) else { return }
        self.samplerState = samplerState
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {
        // 初始化lut参数
        var params = LutFilterParameters(clipOriginX: UInt32(floor(rect.origin.x)),
                                         clipOriginY: UInt32(floor(rect.origin.y)),
                                         clipSizeX: UInt32(floor(rect.size.width)),
                                         clipSizeY: UInt32(floor(rect.size.height)),
                                         saturation: saturation,
                                         changeColor: UInt16(1),
                                         changeCoord: UInt16(1))
        
        // 计划在GPU上并行执行的线程数
        let width = pipelineState.threadExecutionWidth;
        // 每个线程组的总线程数除以线程执行宽度
        let height = pipelineState.maxTotalThreadsPerThreadgroup / width
        // 网格大小
        let threadsPerGroup = MTLSizeMake(width, height, 1)
        let threadsPerGrid = MTLSize(width: (sourceTexture.width + width - 1) / width,
                                     height: (sourceTexture.height + height - 1) / height,
                                     depth: 1)
        
        // 配置编码渲染命令
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            HSLog("RenderEncoder make fail")
            return
        }
        encoder.label = "filter encoder"
        encoder.pushDebugGroup("lut-filter")
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(sourceTexture, index: 0)
        encoder.setTexture(lutTexture, index: 1)
        encoder.setTexture(destinationTexture, index: 2)
        encoder.setSamplerState(samplerState, index: 0)
        encoder.setBytes(&params, length: MemoryLayout.size(ofValue: params), index: 0)
        encoder.dispatchThreadgroups(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.popDebugGroup()
        encoder.endEncoding()
    }
    
}

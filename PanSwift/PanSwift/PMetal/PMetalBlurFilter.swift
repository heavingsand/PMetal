//
//  PMetalBlurFilter.swift
//  PanSwift
//
//  Created by Pan on 2022/7/14.
//

import Foundation
import MetalPerformanceShaders

class PMetalBlurFilter: MPSImageGaussianBlur {
    
//    // MARK: - Property
//
//    /// 计算管道
//    private var computePipelineState: MTLComputePipelineState!
//
//    /// 采样器
//    private var samplerState: MTLSamplerState!
//
//    // MARK: - Life Cycle
//
//    override init(device: MTLDevice, sigma: Float) {
//        super .init(device: device, sigma: sigma)
//
//        // 初始化计算管道
//        let library = device.makeDefaultLibrary()
//        guard let function = library?.makeFunction(name: "lut_texture_kernel") else { return }
//        guard let computePipelineState = try? device.makeComputePipelineState(function: function) else { return }
//        self.computePipelineState = computePipelineState
//
//        // 初始化采样器
//        let samplerDes = MTLSamplerDescriptor()
//        samplerDes.magFilter = .linear
//        samplerDes.minFilter = .linear
//        samplerDes.rAddressMode = .clampToEdge
//        samplerDes.sAddressMode = .clampToEdge
//        samplerDes.tAddressMode = .clampToEdge
//        samplerDes.normalizedCoordinates = false
//        guard let samplerState = device.makeSamplerState(descriptor: samplerDes) else { return }
//        self.samplerState = samplerState
//    }
//
//    required init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture, depth)
//
//    override func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {
//        // 计划在GPU上并行执行的线程数
//        let width = computePipelineState.threadExecutionWidth;
//        // 每个线程组的总线程数除以线程执行宽度
//        let height = computePipelineState.maxTotalThreadsPerThreadgroup / width
//        // 网格大小
//        let threadsPerGroup = MTLSizeMake(width, height, 1)
//        let threadsPerGrid = MTLSize(width: (sourceTexture.width + width - 1) / width, height: (sourceTexture.height + height - 1) / height, depth: 1)
//
//        // 配置计算编码器
//        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
//            HSLog("RenderEncoder make fail")
//            return
//        }
//        encoder.label = "blur encoder"
//        encoder.setComputePipelineState(computePipelineState)
//        encoder.setTexture(<#T##texture: MTLTexture?##MTLTexture?#>, index: <#T##Int#>)
//    }
    
}

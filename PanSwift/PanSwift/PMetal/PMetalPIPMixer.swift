//
//  PMetalPIPMixer.swift
//  PanSwift
//
//  Created by Pan on 2022/6/13.
//

import CoreMedia
import MetalKit

class PMetalPIPMixer: NSObject {
    
    struct MixerParameters {
        var pipPosition: SIMD2<Float>
        var pipSize: SIMD2<Float>
    }
    
    // MARK: - Property
    
    /// 表示画中画相对于全屏视频预览的位置和大小的归一化CGRect
    var pipFrame = CGRect.zero
    
    /// 计算管道
    private var computePipelineState: MTLComputePipelineState!
    
    init(with device: MTLDevice) {
        super .init()
        
        // 初始化计算管道状态
        let library = device.makeDefaultLibrary()
        guard let kernelFunction = library?.makeFunction(name: "pipMixer") else {
            assertionFailure("并行函数创建异常!")
            return
        }
        
        guard let computePipelineState = try? device.makeComputePipelineState(function: kernelFunction) else {
            assertionFailure("并行计算管道创建异常!")
            return
        }
        self.computePipelineState = computePipelineState
    }
    
    func encode(commandBuffer: MTLCommandBuffer, fullTexture: MTLTexture, pipTexture: MTLTexture, outputTexture: MTLTexture) {
        
        // 画中画位置参数
        let pipPosition = SIMD2(Float(pipFrame.origin.x) * Float(fullTexture.width), Float(pipFrame.origin.y) * Float(fullTexture.height))
        let pipSize = SIMD2(Float(pipFrame.size.width) * Float(pipTexture.width), Float(pipFrame.size.height) * Float(pipTexture.height))
        var parameters = MixerParameters(pipPosition: pipPosition, pipSize: pipSize)
        
        // 计划在GPU上并行执行的线程数
        let width = computePipelineState.threadExecutionWidth;
        // 每个线程组的总线程数除以线程执行宽度
        let height = computePipelineState.maxTotalThreadsPerThreadgroup / width
        // 网格大小
        let threadsPerGroup = MTLSizeMake(width, height, 1)
        let threadsPerGrid = MTLSize(width: (fullTexture.width + width - 1) / width, height: (fullTexture.height + height - 1) / height, depth: 1)
        
        // 配置计算编码器
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            HSLog("RenderEncoder make fail")
            return
        }
        encoder.label = "pipMix encoder"
        encoder.setComputePipelineState(computePipelineState)
        encoder.setTexture(fullTexture, index: 0)
        encoder.setTexture(pipTexture, index: 1)
        encoder.setTexture(outputTexture, index: 2)
        encoder.setBytes(&parameters, length: MemoryLayout.size(ofValue: parameters), index: 0)
        encoder.dispatchThreadgroups(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
    }
}



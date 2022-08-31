//
//  PMetalGrayFilter.swift
//  PanSwift
//
//  Created by Pan on 2022/7/21.
//

import UIKit
import Metal

class PMetalGrayFilter: NSObject {
    
    /// 计算管道
    private var computePipelineState: MTLComputePipelineState!
    
    init(with device: MTLDevice) {
        super .init()
        
        // 初始化计算管道状态
        let library = device.makeDefaultLibrary()
        guard let kernelFunction = library?.makeFunction(name: "grayKernel") else {
            assertionFailure("并行函数创建异常!")
            return
        }
        
        guard let computePipelineState = try? device.makeComputePipelineState(function: kernelFunction) else {
            assertionFailure("并行计算管道创建异常!")
            return
        }
        self.computePipelineState = computePipelineState
    }
    
    func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destTexture: MTLTexture) {
        // 计划在GPU上并行执行的线程数
        let width = computePipelineState.threadExecutionWidth;
        // 每个线程组的总线程数除以线程执行宽度
        let height = computePipelineState.maxTotalThreadsPerThreadgroup / width
        // 网格大小
        let threadsPerGroup = MTLSizeMake(width, height, 1)
        let threadsPerGrid = MTLSize(width: (sourceTexture.width + width - 1) / width,
                                     height: (sourceTexture.height + height - 1) / height,
                                     depth: 1)
        
        // 配置计算编码器
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            HSLog("RenderEncoder make fail")
            return
        }
        encoder.label = "gray encoder"
        encoder.setComputePipelineState(computePipelineState)
        encoder.setTexture(sourceTexture, index: 0)
        encoder.setTexture(destTexture, index: 1)
        encoder.dispatchThreadgroups(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
    }

}

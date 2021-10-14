//
//  PMetalContext.swift
//  PanSwift
//
//  Created by Pan on 2021/10/11.
//

import Foundation
import MetalKit

class PMetalContext {
    
    // MARK: - Property
    
    // GPU设备
    private(set) var device: MTLDevice!
    
    private(set) var library: MTLLibrary!
    
    private(set) var commandQueue: MTLCommandQueue!
    
    private(set) var textureCache: CVMetalTextureCache!
    
    init() {
        configMetal()
    }
    
    /// Metal基本配置
    private func configMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError()
        }
        self.device = device
        
        guard let library = device.makeDefaultLibrary() else {
            fatalError()
        }
        self.library = library
        
        /** 命令队列创建开销很昂贵, 最好创建一次, 命令缓冲区对象很便宜, 可以多次创建*/
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError()
        }
        self.commandQueue = commandQueue
        
        var textureCache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache) == kCVReturnSuccess,
              let newTextureCache = textureCache else {
            fatalError()
        }
        self.textureCache = newTextureCache
    }
    
    /// CVPixelBuffer转换Metal纹理
    func makeTextureFromCVPixelBuffer(pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Create a Metal texture from the image buffer
        var tmpTextureOut: CVMetalTexture?
        // 如果MTLPixelFormatBGRA8Unorm和摄像头采集时设置的颜色格式不一致，则会出现图像异常的情况
        let status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &tmpTextureOut)
        guard status == kCVReturnSuccess,
              let textureOut = tmpTextureOut,
              let texture = CVMetalTextureGetTexture(textureOut)
        else {
            HSLog("Video failed to create texture")
            CVMetalTextureCacheFlush(textureCache, 0)
            return nil
        }
        
        return texture
    }
    
}

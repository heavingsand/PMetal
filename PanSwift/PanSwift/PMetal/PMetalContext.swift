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
    
    /// GPU设备
    private(set) var device: MTLDevice!
    
    /// 资源库, 用于去寻找shader函数
    private(set) var library: MTLLibrary!
    
    /// 命令队列
    private(set) var commandQueue: MTLCommandQueue!
    
    /// 纹理缓存
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
        HSLog("🤔🤔DeviceGPUName: \(device.name)")
        
        // 取系统默认资源库
        guard let library = device.makeDefaultLibrary() else {
            fatalError()
        }
        self.library = library
        
        /** 命令队列创建开销很昂贵, 最好创建一次, 命令缓冲区对象开销小, 可以多次创建*/
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError()
        }
        self.commandQueue = commandQueue
        
        // 新建纹理缓存
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

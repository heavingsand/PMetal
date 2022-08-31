//
//  Resources.swift
//  PMetal
//
//  Created by Pan on 2022/7/26.
//

import Foundation
import Metal
import AVFoundation

public class Resources {
    
    // MARK: - Property
    
    /// GPU设备
    public let device: MTLDevice
    
    public let library: MTLLibrary
    
    public let commandQueue: MTLCommandQueue
    
    public let textureCache: CVMetalTextureCache
    
    private static let resources = Resources()
    
    // MARK: - Life Cycle
    
    public static func share() -> Resources {
        return Resources.resources
    }
    
    public init() {
        // 获取GPU设备
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError()
        }
        self.device = device
        print("🤔🤔DeviceGPUName: \(device.name)")
        
        // 加载资源库
        do {
            let frameworkBundle = Bundle(for: Resources.self)
            let metalLibraryPath = frameworkBundle.path(forResource: "default", ofType: "metallib")!
            self.library = try device.makeLibrary(filepath:metalLibraryPath)
        } catch {
            fatalError("Could not load library")
        }
        
        // 命令队列创建开销很昂贵, 最好创建一次, 命令缓冲区对象开销小, 可以多次创建
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
    
    // MARK: - Public Method
    
    /// 获取着色器函数的对象
    /// - Parameter name: 函数名
    /// - Returns: 公共着色器函数的对象
    public func function(with name: String) -> MTLFunction? {
        return library.makeFunction(name: name)
    }
    
    /// CVPixelBuffer转换Metal纹理
    public func makeTextureFromCVPixelBuffer(pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat?) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Create a Metal texture from the image buffer
        var tmpTextureOut: CVMetalTexture?
        // 如果MTLPixelFormatBGRA8Unorm和摄像头采集时设置的颜色格式不一致，则会出现图像异常的情况
        let status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                               textureCache,
                                                               pixelBuffer,
                                                               nil,
                                                               pixelFormat ?? .bgra8Unorm,
                                                               width,
                                                               height,
                                                               0,
                                                               &tmpTextureOut)
        
        guard status == kCVReturnSuccess,
              let textureOut = tmpTextureOut,
              let texture = CVMetalTextureGetTexture(textureOut)
        else {
            print("Video failed to create texture")
            CVMetalTextureCacheFlush(textureCache, 0)
            return nil
        }
        
        return texture
    }
    
    // MARK: - Private Method
    
    /// 分配输出缓冲池
    private func allocateOutputBufferPool(with inputFormatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int) -> (outputBufferPool: CVPixelBufferPool?, outputColorSpace: CGColorSpace?, outputFormatDescription: CMFormatDescription?) {
        
        let set: Set<CMFormatDescription> = []
        set.contains(inputFormatDescription)
//        set.insert(<#T##newMember: CMFormatDescription##CMFormatDescription#>)
//        let ss = set.flatMap(<#T##transform: (CMFormatDescription) throws -> Sequence##(CMFormatDescription) throws -> Sequence#>)
        for format in set {
            if format == inputFormatDescription {
                let ss = format;
            }
        }
        
        let array: Array<CMFormatDescription> = []
        
        let inputMediaSubType = CMFormatDescriptionGetMediaSubType(inputFormatDescription)
        if inputMediaSubType != kCVPixelFormatType_32BGRA {
            assertionFailure("Invalid input pixel buffer type \(inputMediaSubType)")
            return (nil, nil, nil)
        }
        
        let inputDimensions = CMVideoFormatDescriptionGetDimensions(inputFormatDescription)
        var pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: UInt(inputMediaSubType),
            kCVPixelBufferWidthKey as String: Int(inputDimensions.width),
            kCVPixelBufferHeightKey as String: Int(inputDimensions.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        // Get pixel buffer attributes and color space from the input format description
        var cgColorSpace: CGColorSpace? = CGColorSpaceCreateDeviceRGB()
        if let inputFormatDescriptionExtension = CMFormatDescriptionGetExtensions(inputFormatDescription) as Dictionary? {
            let colorPrimaries = inputFormatDescriptionExtension[kCVImageBufferColorPrimariesKey]
            
            if let colorPrimaries = colorPrimaries {
                var colorSpaceProperties: [String: AnyObject] = [kCVImageBufferColorPrimariesKey as String: colorPrimaries]
                
                if let yCbCrMatrix = inputFormatDescriptionExtension[kCVImageBufferYCbCrMatrixKey] {
                    colorSpaceProperties[kCVImageBufferYCbCrMatrixKey as String] = yCbCrMatrix
                }
                
                if let transferFunction = inputFormatDescriptionExtension[kCVImageBufferTransferFunctionKey] {
                    colorSpaceProperties[kCVImageBufferTransferFunctionKey as String] = transferFunction
                }
                
                pixelBufferAttributes[kCVBufferPropagatedAttachmentsKey as String] = colorSpaceProperties
            }
            
            if let cvColorspace = inputFormatDescriptionExtension[kCVImageBufferCGColorSpaceKey],
                CFGetTypeID(cvColorspace) == CGColorSpace.typeID {
                cgColorSpace = (cvColorspace as! CGColorSpace)
            } else if (colorPrimaries as? String) == (kCVImageBufferColorPrimaries_P3_D65 as String) {
                cgColorSpace = CGColorSpace(name: CGColorSpace.displayP3)
            }
        }
        
        // Create a pixel buffer pool with the same pixel attributes as the input format description.
        let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey as String: outputRetainedBufferCountHint]
        var cvPixelBufferPool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes as NSDictionary?, pixelBufferAttributes as NSDictionary?, &cvPixelBufferPool)
        guard let pixelBufferPool = cvPixelBufferPool else {
            assertionFailure("Allocation failure: Could not allocate pixel buffer pool.")
            return (nil, nil, nil)
        }
        
        preAllocateBuffers(pool: pixelBufferPool, allocationThreshold: outputRetainedBufferCountHint)
        
        // Get the output format description
        var pixelBuffer: CVPixelBuffer?
        var outputFormatDescription: CMFormatDescription?
        let auxAttributes = [kCVPixelBufferPoolAllocationThresholdKey as String: outputRetainedBufferCountHint] as NSDictionary
        CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pixelBufferPool, auxAttributes, &pixelBuffer)
        if let pixelBuffer = pixelBuffer {
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                         imageBuffer: pixelBuffer,
                                                         formatDescriptionOut: &outputFormatDescription)
        }
        pixelBuffer = nil
        
        return (pixelBufferPool, cgColorSpace, outputFormatDescription)
    }
    
    /// 预分配缓冲区
    private func preAllocateBuffers(pool: CVPixelBufferPool, allocationThreshold: Int) {
        var pixelBuffers = [CVPixelBuffer]()
        var error: CVReturn = kCVReturnSuccess
        let auxAttributes = [kCVPixelBufferPoolAllocationThresholdKey as String: allocationThreshold] as NSDictionary
        var pixelBuffer: CVPixelBuffer?
        while error == kCVReturnSuccess {
            error = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, auxAttributes, &pixelBuffer)
            if let pixelBuffer = pixelBuffer {
                print("成功创建次数")
                pixelBuffers.append(pixelBuffer)
            }
            pixelBuffer = nil
        }
        pixelBuffers.removeAll()
    }
}

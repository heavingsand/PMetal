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
    var lutImage: UIImage
    
    // 滤镜范围
    var rect: CGRect
    
    // trans coord Y = 1 - Y
    var needCoordTrans: Bool = true
    
    // trans color R -> B / B -> R
    var needColorTrans: Bool = false
    
    private var lutTexture: MTLTexture?
    
    init(device: MTLDevice, lutImage: UIImage, rect: CGRect) {
        self.lutImage = lutImage
        self.rect = rect
        super .init(device: device)
        
        edgeMode = .clamp
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

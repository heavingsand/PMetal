//
//  PMetalLayer.swift
//  PanSwift
//
//  Created by Pan on 2021/10/11.
//

import Foundation
import QuartzCore

class PMetalLayer: CAMetalLayer {
    
    init(with context: PMetalContext) {
        super .init()

        device = context.device
        pixelFormat = .bgra8Unorm
        framebufferOnly = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

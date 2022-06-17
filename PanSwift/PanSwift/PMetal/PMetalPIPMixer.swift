//
//  PMetalPIPMixer.swift
//  PanSwift
//
//  Created by Pan on 2022/6/13.
//

import CoreMedia
import CoreVideo

class PMetalPIPMixer {
    
    // MARK: - Property
    
    var description = "Video Mixer"
    
    private(set) var isPrepared = false
    
    /// 表示画中画相对于全屏视频预览的位置和大小的归一化CGRect
    var pipFrame = CGRect.zero
    
    private(set) var inputFormatDescription: CMFormatDescription?
    
    private(set) var outputFormatDescription: CMFormatDescription?
    
    private var outputPixelBufferPool: CVPixelBufferPool?
    
    
}



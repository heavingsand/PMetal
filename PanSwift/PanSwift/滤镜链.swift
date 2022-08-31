//
//  MetalFilterChainVC.swift
//  PanSwift
//
//  Created by Pan on 2022/7/15.
//

import UIKit
import MetalKit
import AVFoundation
import PMetal

class MetalFilterChainVC: MetalBasicVC {
    
    // MARK: - Property
    
    /// 相机管理类
    private let cameraManager = PCameraManager()

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cameraManager.delegate = self
        cameraManager.prepare()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        cameraManager.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        cameraManager.stopRunning()
    }

}

// MARK: - 相机代理
extension MetalFilterChainVC: CameraManagerDelegate {
    
    func videoCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput videoDataOutput: AVCaptureVideoDataOutput) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        mtkView.pushBuffer(with: pixelBuffer)
    }
    
}

//
//  MetalHSVVC.swift
//  PanSwift
//
//  Created by Pan on 2022/9/19.
//

import UIKit
import MetalKit
import PMetal
import simd

class MetalHSVVC: UIViewController {

    // MARK: - Property
    var resources = Resources.share()
    
    // 顶点缓冲区
    private var vertexBuffer: MTLBuffer?
    
    // 渲染管道状态
    private var pipelineState: MTLRenderPipelineState!
    
    // 渲染视图
    var mtkView: MTKView!
    
    // 圆形顶点
    private var circleVertices = [simd_float2]()

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        setupUI()
        setupMetal()
        render()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    func setupUI() {
        mtkView = MTKView(frame: CGRect(x: 0,
                                        y: 0,
                                        width: UIScreen.main.bounds.size.width,
                                        height: UIScreen.main.bounds.size.width),
                              device: resources.device)
        mtkView.center = CGPoint(x: UIScreen.main.bounds.size.width / 2, y: UIScreen.main.bounds.size.height / 2)
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.addSubview(mtkView)
    }
    
    // MARK: - Metal
    
    /// 配置metal
    func setupMetal() {
        setupVertex()
        setupPipeline()
    }
    
    /// 设置顶点
    func setupVertex() {
        let vertexData:[Float] = [
            -1.0, -1.0,
            -1.0, 1.0,
            1.0, -1.0,
            1.0, 1.0,
        ]

        vertexBuffer = resources.device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: .storageModeShared)
    }
    
    /// 设置渲染管道
    func setupPipeline() {
        let defaultLibrary = resources.device.makeDefaultLibrary()
        let vertexFunction = defaultLibrary?.makeFunction(name: "hsv_vertex")
        let fragmentFunction = defaultLibrary?.makeFunction(name: "hsv_fragment")
        
        // 渲染管道配置
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        guard let pipelineState = try? resources.device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
            fatalError("Failed to create pipeline state")
        }
        self.pipelineState = pipelineState
    }

    func render() {
        // 获取可用的绘制纹理
        guard let drawable = mtkView.currentDrawable else {
            HSLog("drawable get fail")
            return
        }
        
        // 渲染过程配置
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = drawable.texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        
        // 获取命令缓冲区
        guard let commandBuffer = resources.commandQueue.makeCommandBuffer() else {
            HSLog("commandBuffer make fail")
            return
        }
        
        // 配置编码渲染命令
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
        renderEncoder?.setRenderPipelineState(pipelineState)
        renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder?.endEncoding()
        
        // 显示
        commandBuffer.present(drawable)
        // 提交
        commandBuffer.commit()
    }

}

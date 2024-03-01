//
//  MetalHSIVC.swift
//  PanSwift
//
//  Created by Pan on 2022/9/19.
//

import UIKit
import MetalKit
import PMetal
import simd

class MetalHSIVC: UIViewController {
    
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
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    func setupUI() {
        mtkView = MTKView(frame: CGRect(x: 0,
                                        y: 0,
                                        width: UIScreen.main.bounds.size.width,
                                        height: UIScreen.main.bounds.size.width),
                          device: resources.device)
        mtkView.center = CGPoint(x: UIScreen.main.bounds.size.width / 2, y: (UIScreen.main.bounds.size.height - kNavHeight) / 2)
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
        createVertexPoints()
        vertexBuffer = resources.device.makeBuffer(bytes: circleVertices, length: circleVertices.count * MemoryLayout<simd_float2>.stride, options: [])
    }
    
    /// 添加圆形顶点
    fileprivate func createVertexPoints() {
        
        // 根据角度求弧度
        func rads(forDegree d: Float) -> Float32 {
            return (Float.pi * d) / 180
        }
        
        // 圆心坐标
        let origin = simd_float2(0, 0)
        
        for i in 0...720 {
            
            let radian = rads(forDegree: Float(Float(i / 2)))
            let position : simd_float2 = [cos(radian), sin(radian)]
            circleVertices.append(position)
            
            // 添加圆心坐标
            if (i + 1) % 2 == 0 {
                circleVertices.append(origin)
            }
            
//            let atan2 = atan2(position.y, position.x)
//            let degree = atan2 * 180.0 / Float.pi
//            let newRadian = rads(forDegree: Float(degree))
//
//            print("index:\(i) 弧度: \(radian), 坐标: \(position.x), \(position.y), atan值: \(atan2), 角度: \(degree), 新弧度: \(newRadian)")
        }
    }
    
    /// 设置渲染管道
    func setupPipeline() {
        let defaultLibrary = resources.device.makeDefaultLibrary()
        let vertexFunction = defaultLibrary?.makeFunction(name: "hsi_vertex")
        let fragmentFunction = defaultLibrary?.makeFunction(name: "hsi_fragment")
        
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
        renderEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: circleVertices.count)
        renderEncoder?.endEncoding()
        
        // 显示
        commandBuffer.present(drawable)
        // 提交
        commandBuffer.commit()
    }

}

//
//  MetalBasicThreeVC.swift
//  PanSwift
//
//  Created by Pan on 2021/10/11.
//

import UIKit

class MetalBasicThreeVC: UIViewController {
    
    // MARK: - Property
    var metalContext = PMetalContext()
    
    var metalLayer: PMetalLayer!
    
    // 顶点缓冲区
    private var vertexBuffer: MTLBuffer?
    
    // 顶点颜色缓冲区
    private var vertexColorBuffer: MTLBuffer?
    
    // 渲染管道状态
    private var pipelineState: MTLRenderPipelineState!
    
    // 渲染计时器
    private var timer: CADisplayLink?

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupMetal()
        
//        timer = CADisplayLink(target: self, selector: #selector(gameLoop))
//        timer?.add(to: RunLoop.main, forMode: .default)
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
        view.backgroundColor = .black
        
        self.metalLayer = PMetalLayer(with: metalContext)
        metalLayer.frame = view.layer.frame
        view.layer.addSublayer(metalLayer)
        
        let backBtn = UIButton(type: .custom)
        view.addSubview(backBtn)
        backBtn.snp.makeConstraints { make in
            make.left.equalTo(25)
            make.top.equalTo(kStatusHeight + 5)
            make.size.equalTo(CGSize(width: 40, height: 40))
        }
        backBtn.setTitle("返回", for: .normal)
        backBtn.setTitleColor(.white, for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
    }
    
    
    @objc func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Method
    func setupMetal() {
        /// 三角形顶点数据, 顶点坐标分辨是x, y, z (绘制两个三角形可以是6个顶点也可以4个顶点)
//        let vertexData:[Float] = [
//            -0.5, 0.5, 0.0,
//            -0.5, -0.5, 0.0,
//            0.5, -0.5, 0.0,
//            -0.5, 0.5, 0.0,
//            0.5, -0.5, 0.0,
//            0.5, 0.5, 0.0,
//        ]
        
        let vertexData:[Float] = [
            -0.8, -0.8, 0.0,
            -0.8, 0.8, 0.0,
            0.8, -0.8, 0.0,
            0.8, 0.8, 0.0,
        ]
        
        vertexBuffer = metalContext.device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout.size(ofValue: vertexData[0]), options: .storageModeShared)
        
        let vertexColorData:[Float] = [
            0.0, 0.0, 0.0, 1.0,
            0.1, 0.3, 0.4, 1.0,
            1.0, 1.0, 1.0, 1.0,
            0.1, 0.2, 0.3, 1.0,
            0.4, 0.5, 0.6, 1.0,
            0.7, 0.8, 0.9, 1.0,
        ]
        
        vertexColorBuffer = metalContext.device.makeBuffer(bytes: vertexColorData, length: vertexColorData.count * MemoryLayout.size(ofValue: vertexColorData[0]), options: .storageModeShared)
        
        let defaultLibrary = metalContext.device.makeDefaultLibrary()
        let vertexFunction = defaultLibrary?.makeFunction(name: "vertex_basic")
        let fragmentFunction = defaultLibrary?.makeFunction(name: "fragment_basic")
        
        // 渲染管道配置
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        guard let pipelineState = try? metalContext.device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
            fatalError("Failed to create pipeline state")
        }
        self.pipelineState = pipelineState
    }
    
    func render() {
        // 渲染过程配置
        let passDescriptor = MTLRenderPassDescriptor()
        /** 先获取可用的绘制纹理*/
        guard let drawable = metalLayer.nextDrawable() else { return }
        passDescriptor.colorAttachments[0].texture = drawable.texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 211/255.0, green: 211/255.0, blue: 211/255.0, alpha: 1.0)
        
        /** 获取命令缓冲区*/
        guard let commandBuffer = metalContext.commandQueue.makeCommandBuffer() else {
            HSLog("commandBuffer make fail")
            return
        }
        
        // 配置编码渲染命令
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
        renderEncoder?.setRenderPipelineState(pipelineState)
        renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder?.setVertexBuffer(vertexColorBuffer, offset: 0, index: 1)
        // 绘制三角形
//        renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        // 绘制三角形并
        renderEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        /** 完成向渲染命令编码器发送命令并完成帧 */
        renderEncoder?.endEncoding()
        
        // 显示
        commandBuffer.present(drawable)
        // 提交
        commandBuffer.commit()
    }
    
    @objc func gameLoop() {
        autoreleasepool {
            self.render()
        }
    }
}

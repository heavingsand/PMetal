//
//  MetalColorCoordinateVC.swift
//  PanSwift
//
//  Created by Pan on 2022/8/31.
//

import UIKit
import MetalKit
import PMetal
import simd

/// 色域类型
enum ColorGamut: Int {
    case REC709 = 0
    case DCIP3 = 1
    case BT2020 = 2
}

class MetalColorCoordinateVC: UIViewController {
    
    // MARK: - Property
    var resources = Resources.share()
    
    // 顶点缓冲区
    private var vertexBuffer: MTLBuffer?
    
    // 顶点颜色缓冲区
    private var vertexColorBuffer: MTLBuffer?
    
    // 渲染管道状态
    private var pipelineState: MTLRenderPipelineState!
    
    // 渲染视图
    var mtkView: MTKView!
    
    // 色带纹理
    private var colorLineTexture: MTLTexture?
    
    // 马蹄图纹理
    private var CIETexture: MTLTexture?
    
    /// 色域类型
    private var _colorGamut: ColorGamut = .REC709
    /// 色域类型
    var colorGamut: ColorGamut {
        get {
           return _colorGamut
        }
        set {
            _colorGamut = newValue
        }
    }

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        
        setupUI()
        setupMetal()
//        render()
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
        mtkView.delegate = self;
//        mtkView.framebufferOnly = false;
//        mtkView.layer.shouldRasterize = true
//        mtkView.layer.contentsScale = UIScreen.main.scale
        view.addSubview(mtkView)
    }
    
    // MARK: - Method
    
    /// 配置metal
    func setupMetal() {
        setupVertex()
        setupPipeline()
        setCIETexture()
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
        
        let vertexColorData:[Float] = [
            1.0, 1.0, 1.0, 1.0,
            1.0, 0.0, 0.0, 1.0,
            0.9, 0.0, 0.0, 1.0,
        ]
        
        vertexColorBuffer = resources.device.makeBuffer(bytes: vertexColorData, length: vertexColorData.count * MemoryLayout.size(ofValue: vertexColorData[0]), options: .storageModeShared)
    }
    
    /// 设置渲染管道
    func setupPipeline() {
        let defaultLibrary = resources.device.makeDefaultLibrary()
        let vertexFunction = defaultLibrary?.makeFunction(name: "cie_vertex")
        let fragmentFunction = defaultLibrary?.makeFunction(name: "cie_fragment")
        
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
    
    /// 设置色带纹理
    func setColorLineTexture() {
        let imgPath = Bundle.main.path(forResource: "specline.png", ofType: nil)
        guard let imgPath = imgPath else {
            print("路径获取失败")
            return
        }
        
        let image = UIImage(contentsOfFile: imgPath)
        guard let image = image else {
            print("图片加载失败")
            return
        }
        
        // 创建纹理描述符
        let textureDes = MTLTextureDescriptor()
        textureDes.pixelFormat = .bgra8Unorm
        textureDes.width = Int(image.size.width)
        textureDes.height = Int(image.size.height)
        textureDes.usage = .shaderRead
        
        colorLineTexture = resources.device.makeTexture(descriptor: textureDes)
        
        let region = MTLRegionMake2D(0, 0, Int(image.size.width), Int(image.size.height))
        let data = PCameraUtils.loadImageBytes(with: image)
        colorLineTexture?.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: 4 * Int(image.size.width))
        data.deallocate()
    }
    
    func setCIETexture() {
        let imgPath = Bundle.main.path(forResource: "cie.png", ofType: nil)
        guard let imgPath = imgPath else {
            print("路径获取失败")
            return
        }
        
        let image = UIImage(contentsOfFile: imgPath)
        guard let image = image else {
            print("图片加载失败")
            return
        }
        
        // 创建纹理描述符
        let textureDes = MTLTextureDescriptor()
        textureDes.pixelFormat = .bgra8Unorm
        textureDes.width = Int(image.size.width)
        textureDes.height = Int(image.size.height)
        textureDes.usage = .shaderRead
        
        CIETexture = resources.device.makeTexture(descriptor: textureDes)
        
        let region = MTLRegionMake2D(0, 0, Int(image.size.width), Int(image.size.height))
        let data = PCameraUtils.loadImageBytes(with: image)
        CIETexture?.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: 4 * Int(image.size.width))
        data.deallocate()
    }

    func render() {
        // 渲染过程配置
        let passDescriptor = MTLRenderPassDescriptor()
        /** 先获取可用的绘制纹理*/
        // 获取可用的绘制纹理
        guard let drawable = mtkView.currentDrawable else {
            HSLog("drawable get fail")
            return
        }
        passDescriptor.colorAttachments[0].texture = drawable.texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        
        /** 获取命令缓冲区*/
        guard let commandBuffer = resources.commandQueue.makeCommandBuffer() else {
            HSLog("commandBuffer make fail")
            return
        }
        
        // 配置编码渲染命令
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
        renderEncoder?.setRenderPipelineState(pipelineState)
        renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder?.setFragmentTexture(CIETexture, index: 0)
        var colorGamut: Int = colorGamut.rawValue
        renderEncoder?.setFragmentBytes(&colorGamut, length: MemoryLayout<Int>.size, index: 0)
        // 绘制三角形并
        renderEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        // 完成向渲染命令编码器发送命令并完成帧
        renderEncoder?.endEncoding()
        
        // 显示
        commandBuffer.present(drawable)
        // 提交
        commandBuffer.commit()
    }
}

extension MetalColorCoordinateVC: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        //not worried about this
    }
    
    func draw(in view: MTKView) {
        // 获取命令缓冲区
        guard let commandBuffer = resources.commandQueue.makeCommandBuffer() else {return}
        
        // 渲染过程配置
        guard let renderDescriptor = view.currentRenderPassDescriptor else {return}
        renderDescriptor.colorAttachments[0].loadAction = .clear
        renderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        
        // 配置编码渲染命令
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderDescriptor) else { return }
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(CIETexture, index: 0)
        var colorGamut: Int = colorGamut.rawValue
        renderEncoder.setFragmentBytes(&colorGamut, length: MemoryLayout<Int>.size, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        // 显示
        commandBuffer.present(view.currentDrawable!)
        // 提交
        commandBuffer.commit()
    }
}

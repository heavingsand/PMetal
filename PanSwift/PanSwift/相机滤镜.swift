//
//  MetalRenderCameraVC.swift
//  PanSwift
//
//  Created by Pan on 2022/2/17.
//

import UIKit
import MetalKit
import CoreMedia
import CoreGraphics

/// Lut滤镜参数配置
//struct LutFilterParameters {
//    let clipOriginX: UInt32
//    let clipOriginY: UInt32
//    let clipSizeX: UInt32
//    let clipSizeY: UInt32
//    let saturation: Float32
//    let changeColor: UInt16
//    let changeCoord: UInt16
//}

class MetalRenderCameraVC: MetalBasicVC {
    
    // MARK: - Property
    let cameraManager = PCameraManager()
    
    /// 顶点缓冲区
    private var vertexBuffer: MTLBuffer?
    
    /// 渲染管道状态
    private var pipelineState: MTLRenderPipelineState!
    
    /// 采样状态
    private var samplerState: MTLSamplerState!
    
    /// 图片纹理
    private var texture: MTLTexture?
    
    /// lut纹理
    private var lutTexture: MTLTexture?
    
    /// lut数组
    private let lutData = ["lut0", "lut1", "lut2", "lut3", "lut4", "lut5", "lut6", "lut7", "blup", "lookupTable"]
    
    /// 滤镜渲染的宽度
    private var clipSizeX: CGFloat = kScreenWidth / 2
    
    /// 滤镜强度
    private var saturation: Float32 = 1.0
    
    /// 滤镜视图
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 40, height: 40)
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumLineSpacing = 10
        layout.scrollDirection = .horizontal
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        self.view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.left.right.equalTo(0)
            make.height.equalTo(40)
            make.bottom.equalTo(-35)
        }
        collectionView.register(LutCell.self, forCellWithReuseIdentifier: NSStringFromClass(LutCell.self))
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .black
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        return collectionView
    }()
    
    lazy var slider: UISlider = {
        let slider = UISlider()
        self.view.addSubview(slider)
        slider.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(collectionView.snp.top).offset(-5)
            make.size.equalTo(CGSize(width: 120, height: 40))
        }
        slider.minimumValue = 0;
        slider.maximumValue = 1;
        slider.addTarget(self, action: #selector(sliderValueChange(_:)), for: .valueChanged)
        return slider
    }()
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView.frame = CGRect(x: 0,
                               y: 44,
                               width: UIScreen.main.bounds.size.width,
                               height: UIScreen.main.bounds.size.width / 9.0 * 16.0)
        mtkView.delegate = self
        
        cameraManager.delegate = self
        cameraManager.prepare()
        setupMetal()
        
        collectionView.reloadData()
        slider.value = 1;
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        cameraManager.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        cameraManager.stopRunning()
    }
    
    // MARK: - Event
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        guard let point = touches.first?.location(in: view) else {
            print("没有获取到point")
            return
        }
        clipSizeX = point.x
    }
    
    @objc func sliderValueChange(_ sender: UISlider) {
        saturation = slider.value
    }
    
    // MARK: - Method
    
    /// Metal配置
    func setupMetal() {
        setupVertex()
        setupPipeline()
        setupSampler()
        setupLutTexture(with: "lut0")
    }
    
    /// 设置顶点
    func setupVertex() {
        /// 顶点坐标x、y、z、w
        let vertextData:[Float] = [
            -1.0, -1.0, 0.0, 1.0, 0.0, 1.0,
             -1.0, 1.0, 0.0, 1.0, 0.0, 0.0,
             1.0, -1.0, 0.0, 1.0, 1.0, 1.0,
             1.0, 1.0, 0.0, 1.0, 1.0, 0.0,
        ]
        
        // 创建顶点缓冲区
        vertexBuffer = metalContext.device.makeBuffer(bytes: vertextData, length: vertextData.count * MemoryLayout<Float>.size, options: .storageModeShared)
    }
    
    /// 设置渲染管道
    func setupPipeline() {
        let library = metalContext.library
        // 顶点shader，texture_vertex_main是函数名
        let vertexFuction = library?.makeFunction(name: "lut_texture_vertex")
        // 片元shader，texture_fragment_main是函数名
        let fragmentFunction = library?.makeFunction(name: "lut_texture_fragment_two")
        
        let pipelineDes = MTLRenderPipelineDescriptor()
        pipelineDes.vertexFunction = vertexFuction
        pipelineDes.fragmentFunction = fragmentFunction
        pipelineDes.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        guard let pipelineState = try? metalContext.device.makeRenderPipelineState(descriptor: pipelineDes) else {
            HSLog("管道状态异常!")
            return
        }
        
        self.pipelineState = pipelineState
    }
    
    /// 设置采样状态
    func setupSampler() {
        let samplerDes = MTLSamplerDescriptor()
        samplerDes.sAddressMode = .clampToEdge
        samplerDes.tAddressMode = .clampToEdge
        samplerDes.minFilter = .nearest
        samplerDes.magFilter = .linear
        samplerDes.mipFilter = .linear
        
        guard let samplerState = metalContext.device.makeSamplerState(descriptor: samplerDes) else {
            HSLog("采样状态异常!")
            return
        }
        self.samplerState = samplerState
    }
    
    /// 设置LUT纹理
    func setupLutTexture(with imageName: String) {
//        // 使用MTKTextureLoader加载图像数据
//        let textureLoader = MTKTextureLoader(device: metalContext.device)
//        // 创建图片纹理
//        let options = [
//            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.renderTarget.rawValue), // 设置纹理的用途是读写和用于渲染
//            MTKTextureLoader.Option.SRGB: false, // 设置是否使用SRGB像素
//            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue) // 纹理只在GPU应用
//        ]
//        lutTexture = try? textureLoader.newTexture(name: imageName, scaleFactor: 1, bundle: nil, options: options)
        
        // 获取图片
        guard let image = UIImage(named: imageName) else {
            print("图片加载失败")
            return
        }

        // 创建纹理描述符
        let textureDes = MTLTextureDescriptor()
        textureDes.pixelFormat = .bgra8Unorm
        textureDes.width = Int(image.size.width)
        textureDes.height = Int(image.size.height)
        textureDes.usage = .shaderRead

        if (lutTexture == nil) {
            lutTexture = metalContext.device.makeTexture(descriptor: textureDes)
        }

        let region = MTLRegionMake2D(0, 0, Int(image.size.width), Int(image.size.height))
        let data = loadImage(with: image)
        lutTexture?.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: 4 * Int(image.size.width))
        data.deallocate()
    }
    
    /// 渲染
    func render(with texture: MTLTexture) {
        // 获取当前帧的可绘制内容
        guard let drawble = mtkView.currentDrawable else {
            HSLog("drawable get fail")
            return
        }
        
        // 获取命令缓冲区
        guard let commandBuffer = metalContext.commandQueue.makeCommandBuffer() else {
            HSLog("CommandBuffer make fail")
            return
        }
        
        // 获取过程描述符, MTLRenderPassDescriptor描述一系列attachments的值，类似GL的FrameBuffer；同时也用来创建MTLRenderCommandEncoder
        guard let passDescriptor = mtkView.currentRenderPassDescriptor else {
            HSLog("passDescriptor get fail")
            return
        }
        
        // 配置编码渲染命令
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            HSLog("RenderEncoder make fail")
            return
        }
        
        // lut参数配置
        var params = LutFilterParameters(clipOriginX: 0,
                                         clipOriginY: 0,
                                         clipSizeX: UInt32(clipSizeX / view.frame.width * CGFloat(texture.width)),
                                         clipSizeY: UInt32(texture.height),
                                         saturation: saturation,
                                         changeColor: 1,
                                         changeCoord: 0)
        
        // 设置渲染管道，以保证顶点和片元两个shader会被调用
        renderEncoder.setRenderPipelineState(pipelineState)
        // 设置顶点缓存
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        // 设置片段纹理
        renderEncoder.setFragmentTexture(texture, index: 0)
        // 设置lut纹理
        renderEncoder.setFragmentTexture(lutTexture, index: 1)
        // 设置片段采样状态
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        // 设置配置信息
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout.size(ofValue: params), index: 0)
        // 绘制显示区域
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        // 完成向渲染命令编码器发送命令并完成帧
        renderEncoder.endEncoding()
        
        // 显示
        commandBuffer.present(drawble)
        // 提交
        commandBuffer.commit()
    }
    
    // MARK: - Private Method
    
    /// 获取图片数据
    func loadImage(with image: UIImage) -> UnsafeMutableRawPointer {
        
        guard let cgImage = image.cgImage else {
            print("没有获取到图片的cgImage")
            return UnsafeMutableRawPointer.allocate(byteCount: 0, alignment: 0)
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let data = calloc(width * height * 4, MemoryLayout<UInt8>.size) else {
            print("data创建失败")
            return UnsafeMutableRawPointer.allocate(byteCount: 0, alignment: 0)
        }
        
        let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return data
    }

}

// MARK: - 相机代理
extension MetalRenderCameraVC: CameraManagerDelegate {
    
    func captureOutput(didOutput sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        texture = metalContext.makeTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer)
    }
    
}

// MARK: - MTKView代理
extension MetalRenderCameraVC: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("MTKView size: \(size)")
    }

    
    func draw(in view: MTKView) {
        guard let texture = self.texture else { return }
        
        render(with: texture)
    }
}

// MARK: - UICollectionView代理
extension MetalRenderCameraVC: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return lutData.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NSStringFromClass(LutCell.self), for: indexPath) as! LutCell
        cell.reloadImage(with: lutData[indexPath.row])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        setupLutTexture(with: lutData[indexPath.row])
    }
    
}

class LutCell: UICollectionViewCell {
    
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        self.contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalTo(0)
        }
        return imageView
    }()
    
    override init(frame: CGRect) {
        super .init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reloadImage(with imageName: String) {
        guard let image = UIImage(named: imageName) else {
            print("图片加载失败")
            return
        }
        
        imageView.image = image
    }
}

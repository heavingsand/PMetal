//
//  MetalLutObjCameraVC.swift
//  PanSwift
//
//  Created by Pan on 2022/4/2.
//

import UIKit
import MetalKit
import CoreMedia
import CoreGraphics

class MetalLutObjCameraVC: MetalBasicVC {
    
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
    
    /// lut滤镜对象
    private var lutFilter: PMetalLutFilter?
    
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
        mtkView.framebufferOnly = false
        mtkView.isPaused = true
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
        // 获取图片
        guard let image = UIImage(named: imageName) else {
            print("图片加载失败")
            return
        }
        
        lutFilter = PMetalLutFilter(device: metalContext.device)
        lutFilter?.lutImage = image
    }
    
    /// 渲染
    func render(with texture: MTLTexture) {
        guard let metalLayer = mtkView.layer as? CAMetalLayer else {
            HSLog("metalLayer get fail")
            return
        }

        guard let drawable = metalLayer.nextDrawable() else {
            HSLog("drawable get fail")
            return
        }
        
        // 获取命令缓冲区
        guard let commandBuffer = metalContext.commandQueue.makeCommandBuffer() else {
            HSLog("CommandBuffer make fail")
            return
        }
        
        lutFilter?.rect = CGRect(x: 0, y: 0, width: Int(clipSizeX / view.frame.width * CGFloat(texture.width)), height: texture.height)
        lutFilter?.encode(commandBuffer: commandBuffer, sourceTexture: texture, destinationTexture: drawable.texture)
        
        // 显示
        commandBuffer.present(drawable)
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
extension MetalLutObjCameraVC: CameraManagerDelegate {
    
    func captureOutput(didOutput sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        texture = metalContext.makeTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer)
        
//        DispatchQueue.main.async {
            self.mtkView.draw()
//        }
    }
    
}

// MARK: - MTKView代理
extension MetalLutObjCameraVC: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("MTKView size: \(size)")
    }

    
    func draw(in view: MTKView) {
        guard let texture = self.texture else { return }
        
        DispatchQueue.main.async {
            self.render(with: texture)
        }
    }
    
}

// MARK: - UICollectionView代理
extension MetalLutObjCameraVC: UICollectionViewDelegate, UICollectionViewDataSource {
    
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

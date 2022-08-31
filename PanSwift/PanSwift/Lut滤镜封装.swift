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
import Photos

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
    
    /// 是否已经准备好渲染
    private var isPrepared = false
    
    /// 像素缓冲池
    private var outputPixelBufferPool: CVPixelBufferPool?
    
    /// 视频描述对象
    private var videoTrackSourceFormatDescription: CMFormatDescription?
    
    private var viewWidth: CGFloat = 0
    private var viewHeight: CGFloat = 0
    
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
    
    /// 录制按钮
    lazy var recordButton: UIButton = {
        let recordButton = UIButton()
        self.view.addSubview(recordButton)
        recordButton.snp.makeConstraints { make in
            make.bottom.equalTo(-80)
            make.left.equalTo(10)
//            make.centerX.equalToSuperview()
            make.size.equalTo(CGSize(width: 60, height: 60))
        }
        recordButton.backgroundColor = .red
        recordButton.setTitle("录制", for: .normal)
        recordButton.layer.cornerRadius = 30
        return recordButton
    }()
    
    private let recordQueue = DispatchQueue(label: "com.pkh.recordQueue")
    
    private var cameraRecorder: PCameraRecorder?

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        mtkView.frame = CGRect(x: 0,
                               y: 44,
                               width: UIScreen.main.bounds.size.width,
                               height: UIScreen.main.bounds.size.width / 9.0 * 16.0)
//        mtkView.framebufferOnly = false
//        mtkView.isPaused = true
        mtkView.delegate = self
        
        collectionView.reloadData()
        slider.value = 1;
        
        cameraManager.delegate = self
        cameraManager.prepare()
        setupMetal()
        
        recordButton.addTarget(self, action: #selector(recordClick), for: .touchUpInside)
        
        viewWidth = UIScreen.main.bounds.size.width
        viewHeight = UIScreen.main.bounds.size.width / 9.0 * 16.0
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
    
    @objc func recordClick(_ sender: UIButton) {
        sender.isEnabled = false
        
        recordQueue.async {
            defer {
                DispatchQueue.main.async {
                    sender.isEnabled = true
                    
                    if let recorder = self.cameraRecorder {
                        sender.setTitle(recorder.isRecording ? "停止" : "录制", for: .normal)
                    }
                }
            }
            
            let isRecording = self.cameraRecorder?.isRecording ?? false
            if !isRecording {
                guard let audioSettings = self.cameraManager.audioSetting() else {
                    print("Could not create audio settings")
                    return
                }
                
                guard let videoSettings = self.cameraManager.videoSetting() else {
                    print("Could not create video settings")
                    return
                }
                
                guard let videoTransform = self.cameraManager.videoTransform() else {
                    print("Could not create video transform")
                    return
                }
                
                self.cameraRecorder = PCameraRecorder(audioSettings: audioSettings, videoSettings: videoSettings, videoTransform: videoTransform)
                self.cameraRecorder?.startRecording()
            } else {
                self.cameraRecorder?.stopRecording(completion: { movieURL in
                    PCameraUtils.saveMovieToPhotoLibrary(movieURL)
                })
            }
        }
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
//        let vertexData:[Float] = [
//            -1.0, -1.0, 0.0,
//             -1.0, 1.0, 0.0,
//             1.0, -1.0, 0.0,
//             1.0, 1.0, 0.0,
//        ]
        
//        let vertexData:[TextureVertex] = [
//            TextureVertex(position: simd_make_float4(-1.0, -1.0, 0.0, 1.0), texCoords: simd_make_float2(0.0, 1.0)),
//            TextureVertex(position: simd_make_float4(-1.0, 1.0, 0.0, 1.0), texCoords: simd_make_float2(0.0, 0.0)),
//            TextureVertex(position: simd_make_float4(1.0, -1.0, 0.0, 1.0), texCoords: simd_make_float2(1.0, 1.0)),
//            TextureVertex(position: simd_make_float4(1.0, 1.0, 0.0, 1.0), texCoords: simd_make_float2(1.0, 0.0)),
//        ]
        
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
        let vertexFuction = library?.makeFunction(name: "texture_vertex_main_one")
        // 片元shader，texture_fragment_main是函数名
        let fragmentFunction = library?.makeFunction(name: "texture_fragment_main")
        
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
    
    /// 准备渲染
    func prepareRender(with videoFormatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int) {
        (outputPixelBufferPool, _, _) = PCameraUtils.allocateOutputBufferPool(with: videoFormatDescription,
                                                                                                    outputRetainedBufferCountHint: outputRetainedBufferCountHint)
        
        if outputPixelBufferPool == nil {
            HSLog("像素缓冲池创建失败")
            return
        }
        
        isPrepared = true
    }
    
    /// 滤镜渲染
    func lutRender(with pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        guard isPrepared, let outputPixelBufferPool = outputPixelBufferPool else {
            assertionFailure("Invalid state: Not prepared")
            return nil
        }
        
        var newPixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, outputPixelBufferPool, &newPixelBuffer)
        guard let outputPixelBuffer = newPixelBuffer else {
            print("Allocation failure: Could not get pixel buffer from pool (\(self.description))")
            return nil
        }
        
        guard let inputTexture = metalContext.makeTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer),
              let outputTexture = metalContext.makeTextureFromCVPixelBuffer(pixelBuffer: outputPixelBuffer)else {
            return nil
        }
        
        // 获取命令缓冲区
        guard let commandBuffer = metalContext.commandQueue.makeCommandBuffer() else {
            HSLog("CommandBuffer make fail")
            return nil
        }
        
        lutFilter?.rect = CGRect(x: 0, y: 0, width: Int(clipSizeX / viewWidth * CGFloat(inputTexture.width)), height: inputTexture.height)
        lutFilter?.encode(commandBuffer: commandBuffer, sourceTexture: inputTexture, destinationTexture: outputTexture)
        
        // 提交
        commandBuffer.commit()
        
        texture = outputTexture
        
        return outputPixelBuffer
    }
    
    /// 渲染
    func render(with texture: MTLTexture) {
//        guard let metalLayer = mtkView.layer as? CAMetalLayer else {
//            HSLog("metalLayer get fail")
//            return
//        }
//
//        guard let drawable = metalLayer.nextDrawable() else {
//            HSLog("drawable get fail")
//            return
//        }
        
        guard let drawable = mtkView.currentDrawable else {
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
        // 设置渲染管道，以保证顶点和片元两个shader会被调用
        renderEncoder.setRenderPipelineState(pipelineState)
        // 设置顶点缓存
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        // 设置片段纹理
        renderEncoder.setFragmentTexture(texture, index: 0)
        // 设置片段采样状态
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        // 绘制显示区域
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        // 完成向渲染命令编码器发送命令并完成帧
        renderEncoder.endEncoding()
        
        // 显示
        commandBuffer.present(drawable)
        // 提交
        commandBuffer.commit()
    }

}

// MARK: - 相机代理
extension MetalLutObjCameraVC: CameraManagerDelegate {
    
    func videoCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput videoDataOutput: AVCaptureVideoDataOutput) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        if videoTrackSourceFormatDescription == nil {
            videoTrackSourceFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        }
        
        if !isPrepared {
            guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                return
            }
            prepareRender(with: formatDescription, outputRetainedBufferCountHint: 3)
        }
        
        guard let lutPixelBuffer = lutRender(with: pixelBuffer) else {
            print("Unable to combine video")
            return
        }
        
        if let recorder = cameraRecorder, recorder.isRecording, let videoTrackSourceFormatDescription = videoTrackSourceFormatDescription {
            guard let finalVideoSampleBuffer = PCameraUtils.videoSampleBufferWithPixelBuffer(with: lutPixelBuffer,
                                                                                             videoTrackSourceFormatDescription: videoTrackSourceFormatDescription,
                                                                                             presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) else {
                print("Error: Unable to create sample buffer from pixelbuffer")
                return
            }
            
            recorder.recordVideo(sampleBuffer: finalVideoSampleBuffer)
        }
        
    }
    
    func audioCaptureOutput(didOutput sampleBuffer: CMSampleBuffer, fromOutput audioDataOutput: AVCaptureAudioDataOutput) {
        
    }
    
}

// MARK: - MTKView代理
extension MetalLutObjCameraVC: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("MTKView size: \(size)")
    }

    
    func draw(in view: MTKView) {
        guard let texture = self.texture else { return }
        
        self.render(with: texture)
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

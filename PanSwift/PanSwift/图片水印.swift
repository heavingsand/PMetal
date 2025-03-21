//
//  MetalImageWatermarkVC.swift
//  PanSwift
//
//  Created by 潘柯宏 on 2024/8/21.
//

import UIKit
import MetalKit
import Combine

// MARK: - Lazy队列

struct InfiniteEvenNumbers: LazySequenceProtocol, IteratorProtocol, Decodable {
    private var current: Int = 0

    mutating func next() -> Int? {
        current += 2
        return current
    }
}

// MARK: - 属性包装器

@propertyWrapper
struct ObservableValue<T> {
    
    private let subject: CurrentValueSubject<T, Never>
    
    var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }
    
    var wrappedValue: T {
        get {
            subject.value
        }
        
        nonmutating set {
            self.subject.send(newValue)
        }
    }
    
    init(wrappedValue: T) {
        subject = CurrentValueSubject(wrappedValue)
    }
    
}

/// 水印参数
struct WatermarkParameters {
    var position: SIMD2<Float>  // 水印位置
    var size: SIMD2<Float>       // 水印大小
}

class MetalImageWatermarkVC: UIViewController {
    
    // MARK: - Property
    
    /// metal上下文
    var metalContext = PMetalContext()
    
    /// 顶点缓冲区
    private var vertexBuffer: MTLBuffer?
    
    /// 渲染管道状态
    private var pipelineState: MTLRenderPipelineState!
    
    /// 图片纹理
    private var imageTexture: MTLTexture!
    
    /// 水印纹理
    private var watermarkTexture: MTLTexture!
    
    private var slider: UISlider!
    private var label: UILabel!
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        setupMetal()
        render()
        
        let processingQueue = DispatchQueue(label: "com.example.concurrentQueue", attributes: .concurrent)
        // 数据分片处理
        for i in 0..<5 {
            processingQueue.async {
                print("处理分片数据 \(i)")
                Thread.sleep(forTimeInterval: 1)
            }
        }

        // 栅栏任务聚合结果
        processingQueue.async(flags: .barrier) {
            print("所有分片数据处理完成，执行结果聚合")
        }

        let evenNumbers = InfiniteEvenNumbers()
        for number in evenNumbers.prefix(10) {
            print(number) // 输出前 10 个偶数
        }
        
        var lazyVar = 1
        let lazyCapture = {
            print("Lazy Capture: \(lazyVar)")
        }
        lazyVar = 2
        lazyCapture()
        
        var eagerVar = 1
        let eagerCapture = { [eagerVar] in
            print("Eager Capture: \(eagerVar)")
        }
        eagerVar = 2
        eagerCapture()
        
//        let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1")!
//        URLSession.shared.dataTaskPublisher(for: url)
//            .map(\.data)
//            .decode(type: InfiniteEvenNumbers.self, decoder: JSONDecoder())
//            .sink { completion in
//                switch completion {
//                case .failure(let error):
//                    print(error)
//                case .finished:
//                    print("请求成功")
//                }
//            } receiveValue: { infiniteEvenNumbers in
//                print(infiniteEvenNumbers)
//            }
//            .store(in: &cancellables)
        
        slider = UISlider(frame: CGRect(x: 20, y: 100, width: 280, height: 40))
        label = UILabel(frame: CGRect(x: 20, y: 150, width: 280, height: 40))
        view.addSubview(slider)
        view.addSubview(label)
        
//        slider.valuePublisher
        
        slider.publisher(for: \.value)
            .map({ value in
                print("Slider value change: \(value)")
                return String(format: "%.2f", value)
            })
            .sink(receiveValue: { [weak self] string in
                self?.label.text = string
            })
//            .assign(to: \.text, on: label)
            .store(in: &cancellables)
        
//        Timer.publish(every: 1.0, on: .main, in: .common)
//            .autoconnect() // 自动开始
//            .map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .medium) }
//            .assign(to: \.text, on: label) // 将时间绑定到 label.text
//            .store(in: &cancellables)
        
        let people = [
            WatermarkParameters(position: SIMD2(0, 0), size: SIMD2(0, 0)),
            WatermarkParameters(position: SIMD2(0, 0), size: SIMD2(0, 0)),
            WatermarkParameters(position: SIMD2(0, 0), size: SIMD2(0, 0)),
        ]

        people.map { $0.position }
        people.map(\.position)
        people.filter({ $0.position.x > 0 })
        
        let keyPath = \WatermarkParameters.position
        
        Task {
            await loadData()
        }
        
        // 创建手柄视图
        let joystickView = JoystickView(frame: .zero)
        view.addSubview(joystickView)
        
        joystickView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 200, height: 200))
        }
    }
    
    func loadData() async {
        print("开始任务，线程：\(Thread.current)")
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                print("后台处理，线程：\(Thread.current)")
                continuation.resume()
            }
        }
        
        print("收到数据，线程：\(Thread.current)")
    }
    
    // MARK: - Method
    
    /// Metal配置
    func setupMetal() {
        setupVertex()
        setupPipeline()
        setupImageTexture()
        setupWatermarkTexture()
    }
    
    /// 设置顶点
    func setupVertex() {
        // 顶点坐标x、y、z、w
        let vertexData: [Float] = [
            -1.0, -1.0, 0.0,
            -1.0, 1.0, 0.0,
            1.0, -1.0, 0.0,
            1.0, 1.0, 0.0,
        ]
        
        // 创建顶点缓冲区
        vertexBuffer = metalContext.device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: .storageModeShared)
    }
    
    /// 设置渲染管道
    func setupPipeline() {
        let defaultLibrary = metalContext.library
        // 顶点shader，texture_vertex_main是函数名
        let vertexFunction = defaultLibrary?.makeFunction(name: "texture_vertex_main")
        // 片元shader，texture_fragment_main是函数名
        let fragmentFunction = defaultLibrary?.makeFunction(name: "watermark_fragment")
        
        let pipelineDes = MTLRenderPipelineDescriptor()
        pipelineDes.vertexFunction = vertexFunction
        pipelineDes.fragmentFunction = fragmentFunction
        pipelineDes.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // 创建图形渲染管道，耗性能操作不宜频繁调用
        guard let pipelineState = try? metalContext.device.makeRenderPipelineState(descriptor: pipelineDes) else {
            HSLog("管道状态异常!")
            return
        }
        self.pipelineState = pipelineState
    }
    
    /// 设置图片纹理
    func setupImageTexture() {
        // 使用MTKTextureLoader加载图像数据
        let textureLoader = MTKTextureLoader(device: metalContext.device)
        // 获取图片路径
        let imgPath = Bundle.main.path(forResource: "face.png", ofType: nil)
        let textureUrl = URL(fileURLWithPath: imgPath!)
        // 创建图片纹理
        /**
         使用MTKTextureLoader加载颜色查找表（Lookup Table）图像时，默认情况下它生成sRGB颜色范围的纹理，即使图像元数据中并不声明sRGB。如果这影响了滤镜的表现，将MTKTextureLoaderOptionSRGB设置为false让MTKTextureLoader按图像原始色彩空间加载即可
         */
        let options = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.renderTarget.rawValue), // 设置纹理的用途是读写和用于渲染
            MTKTextureLoader.Option.SRGB: false, // 设置是否使用SRGB像素
//            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue) // 纹理只在GPU应用
        ]
        guard let imageTexture = try? textureLoader.newTexture(URL: textureUrl, options: options) else {
            HSLog("diffuseTexture assignment failed")
            return
        }
        self.imageTexture = imageTexture
    }
    
    /// 设置LUT纹理
    func setupWatermarkTexture() {
        // 使用MTKTextureLoader加载图像数据
        let textureLoader = MTKTextureLoader(device: metalContext.device)
        
        let imgPath = Bundle.main.path(forResource: "face.png", ofType: nil)
        let textureUrl = URL(fileURLWithPath: imgPath!)
        // 创建图片纹理
        let options = [
//            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.renderTarget.rawValue), // 设置纹理的用途是读写和用于渲染
            MTKTextureLoader.Option.SRGB: false, // 设置是否使用SRGB像素
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue) // 纹理只在GPU应用
        ]
        guard let watermarkTexture = try? textureLoader.newTexture(name: "lut0", scaleFactor: 1, bundle: nil, options: options) else {
            HSLog("diffuseTexture assignment failed")
            return
        }
        
//        guard let watermarkTexture = try? textureLoader.newTexture(URL: textureUrl, options: options) else {
//            HSLog("diffuseTexture assignment failed")
//            return
//        }
        
        self.watermarkTexture = watermarkTexture
    }
    
    
    /// 创建渲染过程描述符
    /// - Parameter texture: 渲染纹理
    /// - Returns: 描述符
    func createRenderPassDescriptor(texture: MTLTexture) -> MTLRenderPassDescriptor? {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        return renderPassDescriptor
    }
    
    /// 渲染
    func render() {
        // 获取可用的绘制纹理
//        guard let drawable = mtkView.currentDrawable else {
//            HSLog("drawable get fail")
//            return
//        }
        
        // 获取命令缓冲区
        guard let commandBuffer = metalContext.commandQueue.makeCommandBuffer() else {
            HSLog("CommandBuffer make fail")
            return
        }
        
        // 获取过程描述符, MTLRenderPassDescriptor描述一系列attachments的值，类似GL的FrameBuffer；同时也用来创建MTLRenderCommandEncoder
        guard let passDescriptor = createRenderPassDescriptor(texture: imageTexture) else {
            HSLog("passDescriptor get fail")
            return
        }
        
        // 获取过程描述符, MTLRenderPassDescriptor描述一系列attachments的值，类似GL的FrameBuffer；同时也用来创建MTLRenderCommandEncoder
//        guard let passDescriptor = mtkView.currentRenderPassDescriptor else {
//            HSLog("passDescriptor get fail")
//            return
//        }
        
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
        renderEncoder.setFragmentTexture(imageTexture, index: 0)
        // 设置lut纹理
        renderEncoder.setFragmentTexture(watermarkTexture, index: 1)
        
        let position = SIMD2(Float(0.75) * Float(imageTexture.width), Float(0.75) * Float(imageTexture.height))
        let size = SIMD2(Float(0.8) * Float(watermarkTexture.width), Float(0.8) * Float(watermarkTexture.height))
        var params = WatermarkParameters(position: position, size: size)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<WatermarkParameters>.stride, index: 1)
        // 绘制显示区域
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        // 完成向渲染命令编码器发送命令并完成帧
        renderEncoder.endEncoding()
        
        // 提交
        commandBuffer.commit()
//        commandBuffer.waitUntilCompleted()
        commandBuffer.addCompletedHandler { [weak self] finishCommandBuffer in
            guard let strongSelf = self else { return }
            // 将渲染后的纹理转换为 UIImage
            let outputImage = strongSelf.textureToImage(texture: strongSelf.imageTexture)
            DispatchQueue.main.async {
                strongSelf.imageView.image = outputImage
            }
        }
        
        
        // 将渲染后的纹理转换为 UIImage
//        let outputImage = textureToImage(texture: imageTexture)
//        imageView.image = outputImage
    }
    
//    func textureToImage(texture: MTLTexture) -> UIImage? {
//        let width = texture.width
//        let height = texture.height
//        let rowBytes = width * 4
//        let data = UnsafeMutableRawPointer.allocate(byteCount: rowBytes * height, alignment: 4)
//        texture.getBytes(data, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
//        
//        let colorSpace = CGColorSpaceCreateDeviceRGB()
//        let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: rowBytes, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
//        
//        guard let cgImage = context?.makeImage() else {
//            data.deallocate()
//            return nil
//        }
//        
//        let outputImage = UIImage(cgImage: cgImage)
//        data.deallocate()
//        return outputImage
//    }
    
    func textureToImage(texture: MTLTexture) -> UIImage? {
        let width = texture.width
        let height = texture.height
        let rowBytes = width * 4
        var imageBytes = [UInt8](repeating: 0, count: Int(rowBytes * height))
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.getBytes(&imageBytes, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)

        // Convert BGRA to RGBA
        for i in stride(from: 0, to: imageBytes.count, by: 4) {
            let b = imageBytes[i]
            imageBytes[i] = imageBytes[i + 2]  // B -> R
            imageBytes[i + 2] = b              // R -> B
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &imageBytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: rowBytes, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)

        if let cgImage = context?.makeImage() {
            return UIImage(cgImage: cgImage)
        } else {
            return nil
        }
    }
    
    // MARK: - Lazyload
    
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .lightGray
        return imageView
    }()

}

extension UISlider {
    // 自定义 Publisher 类型
    struct ValueChangedPublisher: Publisher {
        typealias Output = Float
        typealias Failure = Never

        private let slider: UISlider

        init(slider: UISlider) {
            self.slider = slider
        }

        func receive<S>(subscriber: S) where S : Subscriber, S.Input == Float, S.Failure == Never {
            let subscription = Subscription(subscriber: subscriber, slider: slider)
            subscriber.receive(subscription: subscription)
        }

        // 定义订阅类来处理事件
        private final class Subscription<S: Subscriber>: Combine.Subscription where S.Input == Float {
            private var subscriber: S?
            private weak var slider: UISlider?

            init(subscriber: S, slider: UISlider) {
                self.subscriber = subscriber
                self.slider = slider
                slider.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
            }

            func request(_ demand: Subscribers.Demand) {}

            func cancel() {
                subscriber = nil
            }

            @objc private func valueChanged() {
                guard let slider = slider else { return }
                _ = subscriber?.receive(slider.value) // 发送 slider.value 给订阅者
            }
        }
    }

    // 提供一个便捷的方法来使用自定义 Publisher
    func publisher(for event: UIControl.Event) -> ValueChangedPublisher {
        return ValueChangedPublisher(slider: self)
    }
}

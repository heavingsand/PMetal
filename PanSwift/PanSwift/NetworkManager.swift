import Foundation
import Network

/// UDP网络管理器，用于实现局域网设备发现功能
/// 支持UDP广播发送和接收，可用于设备扫描和服务发现
class NetworkManager {
    // MARK: - Properties
    
    /// 用于发送UDP广播的连接
    private var broadcastConnection: NWConnection?
    /// 用于接收UDP消息的连接
    private var receiveConnection: NWConnection?
    /// UDP广播使用的端口号
    private let broadcastPort: UInt16 = 8888
    /// 接收消息的串行队列
    private let receiveQueue = DispatchQueue(label: "com.udp.receive")
    /// 发送广播的串行队列
    private let broadcastQueue = DispatchQueue(label: "com.udp.broadcast")
    
    /// 设备发现回调
    /// - Parameters:
    ///   - message: 接收到的消息内容
    ///   - endpoint: 发送方的网络端点信息
    var deviceFoundHandler: ((String, NWEndpoint) -> Void)?
    
    // MARK: - Initialization
    
    /// 初始化网络管理器并设置UDP接收器
    init() {
        setupReceiver()
    }
    
    // MARK: - Private Methods
    
    /// 设置UDP接收器
    /// - Note: 配置UDP参数并启动接收连接
    private func setupReceiver() {
        // 创建UDP连接参数
        let parameters = NWParameters.udp
        // 允许端口重用，这样多个应用可以监听同一端口
        parameters.allowLocalEndpointReuse = true
        
        // 创建接收端点，使用"0.0.0.0"监听所有网络接口
        let receiveEndpoint = NWEndpoint.hostPort(host: "0.0.0.0", port: NWEndpoint.Port(integerLiteral: broadcastPort))
        receiveConnection = NWConnection(to: receiveEndpoint, using: parameters)
        
        // 设置连接状态处理
        receiveConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("UDP receiver ready")
                self?.startReceiving()
            case .failed(let error):
                print("UDP receiver failed: \(error)")
            default:
                break
            }
        }
        
        // 在接收队列上启动连接
        receiveConnection?.start(queue: receiveQueue)
    }
    
    /// 开始接收UDP消息
    /// - Note: 使用递归调用持续接收消息
    private func startReceiving() {
        receiveConnection?.receiveMessage { [weak self] content, contentContext, isComplete, error in
            if let error = error {
                print("Receive error: \(error)")
                return
            }
            
            // 解析接收到的消息和发送方信息
            if let content = content,
               let message = String(data: content, encoding: .utf8),
               let endpoint = self?.receiveConnection?.currentPath?.remoteEndpoint {
                print("Received message: \(message)")
                self?.deviceFoundHandler?(message, endpoint)
            }
            
            // 继续接收下一个消息
            self?.startReceiving()
        }
    }
    
    // MARK: - Public Methods
    
    /// 开始广播扫描
    /// - Parameter message: 要广播的消息内容
    /// - Note: 会持续发送广播直到调用stopScanning
    func startBroadcastScanning(message: String) {
        // 创建UDP广播参数
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true
        
        // 配置IPv4广播选项
        if let broadcastOption = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            broadcastOption.version = .v4
            broadcastOption.hopLimit = 255  // 设置最大跳数
        }
        
        // 创建广播端点，使用广播地址255.255.255.255
        let broadcastEndpoint = NWEndpoint.hostPort(host: "255.255.255.255", port: NWEndpoint.Port(integerLiteral: broadcastPort))
        broadcastConnection = NWConnection(to: broadcastEndpoint, using: parameters)
        
        // 设置广播连接状态处理
        broadcastConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Broadcast connection ready")
                self?.sendBroadcast(message: message)
            case .failed(let error):
                print("Broadcast connection failed: \(error)")
            default:
                break
            }
        }
        
        // 在广播队列上启动连接
        broadcastConnection?.start(queue: broadcastQueue)
    }
    
    /// 发送广播消息
    /// - Parameter message: 要发送的消息内容
    private func sendBroadcast(message: String) {
        guard let data = message.data(using: .utf8) else { return }
        
        // 发送UDP广播消息
        broadcastConnection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("Send error: \(error)")
                return
            }
            
            // 1秒后重新发送广播
            self?.broadcastQueue.asyncAfter(deadline: .now() + 1.0) {
                self?.sendBroadcast(message: message)
            }
        })
    }
    
    /// 停止扫描
    /// - Note: 取消所有活动的连接并清理资源
    func stopScanning() {
        broadcastConnection?.cancel()
        broadcastConnection = nil
        receiveConnection?.cancel()
        receiveConnection = nil
    }
    
    /// 析构函数
    /// - Note: 确保在对象销毁时停止所有网络活动
    deinit {
        stopScanning()
    }
} 

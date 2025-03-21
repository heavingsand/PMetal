//
//  UDPReceiverViewController.swift
//  PanSwift
//
//  Created by 潘柯宏 on 2025/2/28.
//

import UIKit
import Network

class UDPReceiverViewController: UIViewController {
    
    // MARK: - Property
    
    let receiver = UDPReceiver(port: 5000)
    
    // MARK: - Life Cycle
    
    deinit {
        print("UDPReceiverViewController deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        receiver.start()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        receiver.close()
    }

}

class UDPReceiver {
    let listener: NWListener
    var expectedSeq = 0  // 期望的下一个数据包编号
    var receivedBuffer: [Int: String] = [:]  // 乱序缓冲区
    var port: UInt16
    
    deinit {
        print("UDPReceiver deinit")
    }

    init(port: UInt16) {
        self.port = port
        do {
            guard let endPort = NWEndpoint.Port(rawValue: port) else {
                throw URLError(.badURL)
            }
            listener = try NWListener(using: .udp, on: endPort)
        } catch {
            fatalError()
        }
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            self.receivePackets(connection: connection)
        }
    }

    func receivePackets(connection: NWConnection) {
        connection.receiveMessage { data, _, _, _ in
            if let data = data, let message = String(data: data, encoding: .utf8) {
                self.handleReceivedPacket(connection: connection, message: message)
            }
            self.receivePackets(connection: connection)
        }
    }

    func handleReceivedPacket(connection: NWConnection, message: String) {
        if message.starts(with: "Packet") {
            let packetNum = Int(message.split(separator: " ")[1]) ?? -1

            // 模拟数据丢失（20% 丢失率）
            if Int.random(in: 1...10) <= 2 {
                print("Lost Packet \(packetNum)")
                return
            }

            print("Received: \(message)")

            // 存储到缓冲区
            receivedBuffer[packetNum] = message

            // 发送 ACK
            let ackMessage = "ACK \(packetNum)"
            connection.send(content: ackMessage.data(using: .utf8), completion: .contentProcessed { _ in
                print("Sent \(ackMessage)")
            })

            // 检查是否可以按序提交
            while let message = receivedBuffer[expectedSeq] {
                print("Delivered: \(message)")
                receivedBuffer.removeValue(forKey: expectedSeq)
                expectedSeq += 1
            }
        }
    }
    
    func start() {
        listener.start(queue: .global())
        print("Receiver started on port \(port)")
    }
    
    func close() {
        listener.cancel()
    }
    
}

struct NWManager {
    
    /// 获取本地IP地址
    static func getLocalIP() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) { // 只取 IPv4 地址
                    if let name = interface?.ifa_name, String(cString: name) == "en0" { // en0 是 Wi-Fi 网络接口
                        var addr = interface?.ifa_addr.pointee
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(&addr!, socklen_t(interface!.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
                ptr = ptr?.pointee.ifa_next
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
    
}



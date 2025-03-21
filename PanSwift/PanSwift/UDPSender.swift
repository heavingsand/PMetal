//
//  UDPSendViewController.swift
//  PanSwift
//
//  Created by 潘柯宏 on 2025/2/28.
//

import UIKit
import Network

class UDPSendViewController: UIViewController {
    
    // MARK: - Property
    
    let sender = UDPSender(host: "127.0.0.1", port: 5000)

    // MARK: - Life Cycle
    
    deinit {
        print("UDPSendViewController deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        sender.start()
        test()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sender.close()
    }
    
    func test() {
        var mergedSleepDBModels: [String] = []
        mergedSleepDBModels.sort { $0 < $1 }
        print("不会崩溃吧")
    }

}

class UDPSender {
    let connection: NWConnection
    let windowSize = 4  // 发送窗口大小
    let totalPackets = 10  // 需要发送的数据包总数
    let timeout: TimeInterval = 2.0  // 超时时间

    var base = 0  // 发送窗口的起点
    var unackedPackets: [Int: Date] = [:]  // 记录未确认的数据包
    var port: UInt16
    
    deinit {
        print("UDPSender deinit")
    }

    init(host: String, port: UInt16) {
        self.port = port
        self.connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .udp)
        self.connection.start(queue: .global())
    }

    func sendPacket(packetID: Int) {
        let message = "Packet \(packetID)"
        connection.send(content: message.data(using: .utf8), completion: .contentProcessed { _ in
            print("Sent: \(message)")
        })

        // 记录未确认的包和发送时间
        unackedPackets[packetID] = Date()
    }

    func startSending() {
        DispatchQueue.global().async {
            while self.base < self.totalPackets {
                // 发送窗口范围内的新包
                while self.base + self.unackedPackets.count < min(self.base + self.windowSize, self.totalPackets) {
                    self.sendPacket(packetID: self.base + self.unackedPackets.count)
                }

                // 等待 ACK
                self.receiveACK()
                
                // 检查超时包
                self.checkTimeouts()
                sleep(1)
            }
            print("All packets sent successfully.")
        }
    }

    func receiveACK() {
        connection.receiveMessage { data, _, _, _ in
            if let data = data, let ackMessage = String(data: data, encoding: .utf8) {
                if ackMessage.starts(with: "ACK") {
                    let ackNum = Int(ackMessage.split(separator: " ")[1]) ?? -1
                    print("Received ACK: \(ackNum)")

                    // 移除已确认的数据包
                    self.unackedPackets.removeValue(forKey: ackNum)

                    // 移动窗口
                    if ackNum == self.base {
                        while self.unackedPackets[self.base] == nil, self.base < self.totalPackets {
                            self.base += 1
                        }
                    }
                }
            }
        }
    }

    func checkTimeouts() {
        let currentTime = Date()
        for (packetID, sendTime) in unackedPackets {
            if currentTime.timeIntervalSince(sendTime) > timeout {
                print("Timeout! Resending Packet \(packetID)")
                sendPacket(packetID: packetID)
            }
        }
    }
    
    func start() {
        startSending()
    }
    
    func close() {
        connection.cancel()
    }
    
}

struct PNetworkManager {
    
    /// 通信类型
    enum CommunicationType {
        // 广播
        case broadcast
        // 组播
        case multicast
    }
    
}

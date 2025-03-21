import CoreBluetooth
import Foundation

/// 蓝牙设备连接状态
enum BluetoothConnectionState {
    case disconnected
    case connecting
    case connected
    case failed(Error?)
}

/// 蓝牙管理器代理协议
protocol BluetoothManagerDelegate: AnyObject {
    /// 发现新设备
    func bluetoothManager(_ manager: BluetoothManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber)
    /// 设备连接状态改变
    func bluetoothManager(_ manager: BluetoothManager, peripheral: CBPeripheral, didChangeState state: BluetoothConnectionState)
    /// 收到数据
    func bluetoothManager(_ manager: BluetoothManager, peripheral: CBPeripheral, didReceiveData data: Data, characteristic: CBCharacteristic)
}

class BluetoothManager: NSObject {
    
    // MARK: - Properties
    
    /// 单例
    static let shared = BluetoothManager()
    
    /// 代理
    weak var delegate: BluetoothManagerDelegate?
    
    /// 中心管理器
    private var centralManager: CBCentralManager!
    
    /// 已连接的设备字典 [UUID: CBPeripheral]
    private var connectedPeripherals: [String: CBPeripheral] = [:]
    
    /// 设备的特征字典 [UUID: [CBCharacteristic]]
    private var characteristics: [String: [CBCharacteristic]] = [:]
    
    /// 最大连接数
    private let maxConnections = 5
    
    /// 服务UUID（根据实际需求修改）
    private let serviceUUID = CBUUID(string: "YOUR_SERVICE_UUID")
    
    /// 特征UUID（根据实际需求修改）
    private let characteristicUUID = CBUUID(string: "YOUR_CHARACTERISTIC_UUID")
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    /// 开始扫描设备
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("蓝牙未开启")
            return
        }
        
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }
    
    /// 停止扫描
    func stopScanning() {
        centralManager.stopScan()
    }
    
    /// 连接设备
    func connect(_ peripheral: CBPeripheral) {
        guard connectedPeripherals.count < maxConnections else {
            print("已达到最大连接数")
            return
        }
        
        centralManager.connect(peripheral, options: nil)
        peripheral.delegate = self
    }
    
    /// 断开设备连接
    func disconnect(_ peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    /// 断开所有连接
    func disconnectAll() {
        connectedPeripherals.values.forEach { peripheral in
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    /// 向指定设备发送数据
    func sendData(_ data: Data, to peripheral: CBPeripheral) {
        guard let characteristics = characteristics[peripheral.identifier.uuidString],
              let characteristic = characteristics.first(where: { $0.uuid == characteristicUUID }) else {
            print("未找到特征")
            return
        }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    /// 向所有已连接设备发送数据
    func broadcastData(_ data: Data) {
        connectedPeripherals.values.forEach { peripheral in
            sendData(data, to: peripheral)
        }
    }
    
    /// 获取已连接设备列表
    func getConnectedDevices() -> [CBPeripheral] {
        Array(connectedPeripherals.values)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("蓝牙已开启")
        case .poweredOff:
            print("蓝牙已关闭")
            connectedPeripherals.removeAll()
            characteristics.removeAll()
        case .unsupported:
            print("设备不支持蓝牙")
        case .unauthorized:
            print("蓝牙未授权")
        case .resetting:
            print("蓝牙重置中")
        case .unknown:
            print("蓝牙状态未知")
        @unknown default:
            print("未知状态")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        delegate?.bluetoothManager(self, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripherals[peripheral.identifier.uuidString] = peripheral
        delegate?.bluetoothManager(self, peripheral: peripheral, didChangeState: .connected)
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        delegate?.bluetoothManager(self, peripheral: peripheral, didChangeState: .failed(error))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripherals.removeValue(forKey: peripheral.identifier.uuidString)
        characteristics.removeValue(forKey: peripheral.identifier.uuidString)
        delegate?.bluetoothManager(self, peripheral: peripheral, didChangeState: .disconnected)
    }
}
 
// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        self.characteristics[peripheral.identifier.uuidString] = characteristics
        
        for characteristic in characteristics {
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        delegate?.bluetoothManager(self, peripheral: peripheral, didReceiveData: data, characteristic: characteristic)
    }
} 

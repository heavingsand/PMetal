//
//  AVCaptureDevice+Extension.swift
//  PanSwift
//
//  Created by Pan on 2022/4/2.
//

import Foundation
import AVFoundation
import CoreMedia
import UIKit

extension AVCaptureDevice {
    
    /// 获取当前设备支持的音频设备
    /// - Returns: 音频设备
    class func supportedAudioDevice() -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone], mediaType: .audio, position: .unspecified).devices
            return devices.first
        } else {
            let devices = AVCaptureDevice.devices(for: .audio)
            return devices.first
        }
    }
    
    /// 获取当前设备支持的视频摄像头
    /// - Parameter position: 摄像头位置
    /// - AVCaptureDevicePositionUnspecified模式可以获取到所有的摄像头
    /// - Returns: 摄像头
    class func supportedVideoDevice(with position: AVCaptureDevice.Position) -> [AVCaptureDevice] {
        // iOS10以后获取摄像头方法和之前有所区别
        if #available(iOS 10.0, *) {
            // iOS10以后所支持的摄像头
            var deviceTypes: Array<AVCaptureDevice.DeviceType> = [];
            deviceTypes.append(AVCaptureDevice.DeviceType.builtInWideAngleCamera)
            deviceTypes.append(AVCaptureDevice.DeviceType.builtInTelephotoCamera)
            if #available(iOS 10.2, *) {
                deviceTypes.append(AVCaptureDevice.DeviceType.builtInDualCamera)
            } else {
                deviceTypes.append(AVCaptureDevice.DeviceType.builtInDuoCamera)
            }
            if #available(iOS 11.1, *) {
                deviceTypes.append(AVCaptureDevice.DeviceType.builtInTrueDepthCamera)
            }
            if #available(iOS 13.0, *) {
                deviceTypes.append(AVCaptureDevice.DeviceType.builtInUltraWideCamera)
                deviceTypes.append(AVCaptureDevice.DeviceType.builtInDualWideCamera)
                deviceTypes.append(AVCaptureDevice.DeviceType.builtInTripleCamera)
            }
            if #available(iOS 15.4, *) {
                deviceTypes.append(AVCaptureDevice.DeviceType.builtInLiDARDepthCamera)
            }
            
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: position)
            return discoverySession.devices
        } else {
            // iOS10之前所支持的摄像头
            let devices = AVCaptureDevice.devices(for: .video)
            
            if position == .unspecified {
                return devices
            }
            
            for device in devices {
                if device.position == position {
                    return [device];
                }
            }
            
            return devices
        }
    }
    
    /// 获取默认的视频捕捉设备
    /// - Returns: 摄像头
    class func defaultVideoDevice() -> AVCaptureDevice? {
        return AVCaptureDevice.default(for: .video)
    }
    
    /// 设备是否支持杜比视觉录制
    class func supportDolbyVision() -> Bool {
        let devices = supportedVideoDevice(with: .back)
        for device in devices {
            for format in device.formats {
                let formatDescriptionRef = format.formatDescription
                let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescriptionRef)
                if mediaSubType == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange {
                    return true
                }
            }
        }
        return false
    }
}

extension AVCaptureVideoOrientation {
    
    /// 根据设备方位获取视频方向
    /// - Parameter deviceOrientation: 设备方向
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
    
    
    /// 根据程序界面的方向视频方向
    /// - Parameter interfaceOrientation: 程序方向
    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: return nil
        }
    }
    
    /// 与纵向的角度偏移
    func angleOffsetFromPortraitOrientation(at position: AVCaptureDevice.Position) -> Double {
        switch self {
        case .portrait:
            return position == .front ? .pi : 0
        case .portraitUpsideDown:
            return position == .front ? 0 : .pi
        case .landscapeRight:
            return -.pi / 2.0
        case .landscapeLeft:
            return .pi / 2.0
        default:
            return 0
        }
    }
}

extension AVCaptureConnection {
    
    /// 视频方向转换
    /// - Parameter destinationVideoOrientation: 目标方向
    /// - Returns: 旋转角度
    func videoOrientationTransform(relativeTo destinationVideoOrientation: AVCaptureVideoOrientation) -> CGAffineTransform {
        let videoDevice: AVCaptureDevice
        if let deviceInput = inputPorts.first?.input as? AVCaptureDeviceInput, deviceInput.device.hasMediaType(.video) {
            videoDevice = deviceInput.device
        } else {
            // Fatal error? Programmer error?
            print("Video data output's video connection does not have a video device")
            return .identity
        }
        
        let fromAngleOffset = videoOrientation.angleOffsetFromPortraitOrientation(at: videoDevice.position)
        let toAngleOffset = destinationVideoOrientation.angleOffsetFromPortraitOrientation(at: videoDevice.position)
        let angleOffset = CGFloat(toAngleOffset - fromAngleOffset)
        let transform = CGAffineTransform(rotationAngle: angleOffset)
        
        return transform
    }
}

extension Bundle {
    
    /// 获取bundle名称
    var applicationName: String {
        if let name = object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return name
        } else if let name = object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        
        return "-"
    }
    
}

//
//  PCameraAuthorization.swift
//  PanSwift
//
//  Created by Pan on 2022/1/21.
//

import Foundation
import AVFoundation
import Photos

public enum CameraAuthStatus: UInt {
    /// 未询问过用户是否授权
    case notDetermined
    
    /// 未授权，例如家长控制
    case restricted
    
    /// 用户明确拒绝授权
    case denied
    
    /// 已经授权
    case authorized
    
    /// 未知
    case unknown
}

public enum CameraAuthType: UInt {
    /// 摄像头
    case video
    
    /// 麦克风
    case audio
    
    /// 相册
    case photos
}

public struct PCameraAuthorization {
    
    public typealias AuthCallBack = (Bool) -> Void
    
    /// 获取相机相关权限状态
    /// - Parameter type: 权限类型
    /// - Returns: 权限状态
    public static func authorizationStatus(with type: CameraAuthType) -> CameraAuthStatus {
        switch type {
        case .video, .audio:
            return mediaAuthStatus(with: type)
        case .photos:
            return photosAuthStatus()
        }
    }
    
    /// 请求相机相关权限状态
    /// - Parameters:
    ///   - type: 权限类型
    ///   - completion: 完成回调
    public static func requestAuthorization(with type: CameraAuthType, completion: @escaping AuthCallBack) {
        switch type {
        case .video, .audio:
            requsetMediaAuth(with: type, completion: completion)
        case .photos:
            requestPhotosAuth(completion: completion)
        }
    }
    
    // MARK: - Private
    
    /// 媒体类型权限状态
    /// - Parameter type: 媒体类型
    /// - Returns: 权限状态
    private static func mediaAuthStatus(with type: CameraAuthType) -> CameraAuthStatus {
        var mediaType: AVMediaType
        switch type {
        case .video:
            mediaType = .video
        case .audio:
            mediaType = .audio
        default:
            return .unknown
        }
        
        let status = AVCaptureDevice.authorizationStatus(for: mediaType)
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .unknown
        }
    }
    
    /// 请求媒体类型权限
    /// - Parameters:
    ///   - type: 媒体类型
    ///   - completion: 完成回调
    private static func requsetMediaAuth(with type: CameraAuthType, completion: @escaping AuthCallBack) {
        let status = mediaAuthStatus(with: type)
        switch status {
        case .notDetermined:
            var mediaType: AVMediaType
            switch type {
            case .video:
                mediaType = .video
            case .audio:
                mediaType = .audio
            default:
                completion(false)
                return
            }
            
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .authorized:
            completion(true)
        default:
            completion(false)
        }
    }
    
    /// 图片库权限
    /// - Returns: 权限类型
    private static func photosAuthStatus() -> CameraAuthStatus {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized, .limited:
            return .authorized
        default:
            return .unknown
        }
    }
    
    /// 请求图片库权限
    /// - Parameter completion: 完成回调
    private static func requestPhotosAuth(completion: @escaping AuthCallBack) {
        let status = photosAuthStatus()
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { authStatus in
                DispatchQueue.main.async {
                    completion(authStatus == .authorized)
                }
            }
        case .authorized:
            completion(true)
        default:
            completion(false)
        }
    }

}

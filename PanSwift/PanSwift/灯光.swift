//
//  MetalLightVC.swift
//  PanSwift
//
//  Created by Pan on 2021/11/5.
//

import UIKit
import MetalKit

class MetalLightVC: MetalBasicVC {
    // MARK: - Property


    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Vector Uniforms
        let teapotColor = simd_make_float4(0.7, 0.47, 0.18, 1.0)
        let lightPosition = simd_make_float4(5.0, 5.0, 2.0, 1.0)
        let reflectivity = simd_make_float3(0.9, 0.5, 0.3)
        let intensity = simd_make_float3(1.0, 1.0, 1.0)
        
        // Matrix Uniforms
        let yAxis = simd_make_float4(0, -1, 0, 0)
        var modelViewMatrix = Matrix4x4.rotationAboutAxis(yAxis, byAngle: 1)
        modelViewMatrix.W.z = -2
        
        let aspect = Float32(view.bounds.width) / Float32(view.bounds.height)
        
        let projectionMatrix = Matrix4x4.perspectiveProjection(aspect, fieldOfViewY: 60, near: 0.1, far: 100.0)
        
        let uniform = Uniforms(lightPosition: lightPosition, color: teapotColor, reflectivity: reflectivity, lightIntensity: intensity, projectionMatrix: projectionMatrix, modelViewMatrix: modelViewMatrix)
        
        let uniforms = metalContext.device.makeBuffer(length: MemoryLayout<Uniforms>.size, options: [])
    }

}

// MARK: - 统一缓冲区

struct Vector4 {
    var x: Float
    var y: Float
    var z: Float
    var w: Float
}

struct Matrix4x4 {
    var X: Vector4
    var Y: Vector4
    var Z: Vector4
    var W: Vector4
    
    init() {
        X = Vector4(x: 1, y: 0, z: 0, w: 0)
        Y = Vector4(x: 0, y: 1, z: 0, w: 0)
        Z = Vector4(x: 0, y: 0, z: 1, w: 0)
        W = Vector4(x: 0, y: 0, z: 0, w: 1)
    }
    
    /// 绕轴旋转
    static func rotationAboutAxis(_ axis: SIMD4<Float>, byAngle angle: Float32) -> Matrix4x4 {
        var mat = Matrix4x4()
        let c = cos(angle)
        let s = sin(angle)
        
        mat.X.x = axis.x * axis.x + (1 - axis.x * axis.x) * c
        mat.X.y = axis.x * axis.y * (1 - c) - axis.z * s
        mat.X.z = axis.x * axis.z * (1 - c) + axis.y * s
        mat.Y.x = axis.x * axis.y * (1 - c) + axis.z * s
        mat.Y.y = axis.y * axis.y + (1 - axis.y * axis.y) * c
        mat.Y.z = axis.y * axis.z * (1 - c) - axis.x * s
        mat.Z.x = axis.x * axis.z * (1 - c) - axis.y * s
        mat.Z.y = axis.y * axis.z * (1 - c) + axis.x * s
        mat.Z.z = axis.z * axis.z + (1 - axis.z * axis.z) * c
        
        return mat
    }
    
    /// 透视投影
    static func perspectiveProjection(_ aspect: Float32,
                                      fieldOfViewY: Float32,
                                      near:Float32,
                                      far: Float32) -> Matrix4x4 {
        var mat = Matrix4x4()
        let fovRadians = fieldOfViewY * Float32(Double.pi / 180.0)
        let yScale = 1 / tan(fovRadians * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near
        let zScale = -(far + near) / zRange
        let wzScale = -2 * far * near / zRange
        
        mat.X.x = xScale
        mat.Y.y = yScale
        mat.Z.z = zScale
        mat.Z.w = -1
        mat.W.z = wzScale
        
        return mat
    }
}

struct Uniforms {
    /// 灯光位置
    let lightPosition: SIMD4<Float>
    /// 颜色
    let color: SIMD4<Float>
    /// 反射率
    let reflectivity: SIMD3<Float>
    /// 光强度
    let lightIntensity: SIMD3<Float>
    /// 投影矩阵
    let projectionMatrix:Matrix4x4
    /// 模型视图矩阵
    let modelViewMatrix:Matrix4x4
}

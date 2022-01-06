//
//  MetalBasicOneVC.swift
//  PanSwift
//
//  Created by Pan on 2021/9/18.
//

import UIKit
import MetalKit

class MetalBasicOneVC: MetalBasicVC {
    
    // MARK: - Property
    var allocator: MTKMeshBufferAllocator!

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        render()
    }
    
    func render() {
        // Queues, buffers and encoders
        allocator = MTKMeshBufferAllocator(device: metalContext.device)
        
        /** sphereWithExtent -> (x, y ,z) */
        let mdlMesh = boxModel()
        
        guard let mesh = try? MTKMesh(mesh: mdlMesh, device: metalContext.device) else {
            fatalError("Fail init MTKMesh")
        }
        
        // Shader Functions
        let shader = """
            #include <metal_stdlib>
            using namespace metal;
            struct VertexIn {
             float4 position [[ attribute(0) ]];
            };
            vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
             return vertex_in.position;
            }
            fragment float4 fragment_main() {
             return float4(0.1, 0.4, 0.5, 1);
            }
        """
        guard let library = try? metalContext.device.makeLibrary(source: shader, options: nil) else {
            fatalError("Library not support")
        }
        
        guard let vertexFuntion = library.makeFunction(name: "vertex_main") else {
            fatalError("vertexFuntion not find")
        }
        
        guard let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            fatalError("fragmentFunction not find")
        }
        
        // The Pipeline State
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        descriptor.vertexFunction = vertexFuntion
        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
        descriptor.fragmentFunction = fragmentFunction
        
        /** 创建管道状态需要花费时间, 最好一次性设置 */
        guard let pipelineState = try? metalContext.device.makeRenderPipelineState(descriptor: descriptor) else {
            fatalError("PipelineState get fail")
        }
        
        // Rendering
        guard let commandBuffer = metalContext.commandQueue.makeCommandBuffer(),
              let descriptor = mtkView.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            fatalError()
        }
        
        /** 给渲染编码器你之前设置的管道状态 */
        renderEncoder.setRenderPipelineState(pipelineState)
        /** 前面加载的球体网格包含一个包含的简单列表的缓冲区顶点。把这个缓冲区给渲染编码器*/
        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        
        guard let submesh = mesh.submeshes.first else {
            fatalError()
        }
        
        /** 绘图*/
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: submesh.indexCount,
                                            indexType: submesh.indexType,
                                            indexBuffer: submesh.indexBuffer.buffer,
                                            indexBufferOffset: 0)
        
        /** 完成向渲染命令编码器发送命令并完成帧 */
        renderEncoder.endEncoding()
        
        guard let drawable = mtkView.currentDrawable else {
            fatalError()
        }
        // 显示
        commandBuffer.present(drawable)
        // 提交
        commandBuffer.commit()
        
        exportFile(with: mdlMesh)
    }
    
    /// 导出metal模型到沙盒
    func exportFile(with mesh: MDLMesh) {
        let asset = MDLAsset()
        asset.add(mesh)
        
        let fileExtension = "obj"
        guard MDLAsset.canExportFileExtension(fileExtension) else {
            fatalError("Can't export a .\(fileExtension) format")
        }
        
        let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        guard let documentPath = documentPath else {
            fatalError("documentPath is nil")
        }
        
        let url = URL(string: documentPath)?.appendingPathComponent("primitive.\(fileExtension)")
        guard let url = url else {
            fatalError("url is nil")
        }
        
        do {
            try asset.export(to: url)
        } catch  {
            fatalError("Error \(error.localizedDescription)")
        }
    }
}

// MARK: - Metal Model
extension MetalBasicOneVC {
    /// 球形模型
    func sphereModel() -> MDLMesh {
        /** sphereWithExtent -> (x, y ,z) */
        let mdlMesh = MDLMesh(sphereWithExtent: [0.75, 0.75, 0.75],
                              segments: [100, 100],
                              inwardNormals: false,
                              geometryType: .triangles,
                              allocator: allocator)
        return mdlMesh
    }
    
    /// 锥心模型
    func coneModel() -> MDLMesh {
        let mdlMesh = MDLMesh(coneWithExtent: [1, 1, 1],
                              segments: [10, 10],
                              inwardNormals: false,
                              cap: true,
                              geometryType: .triangles,
                              allocator: allocator)
        return mdlMesh
    }
    
    func boxModel() -> MDLMesh {
        let mdlMesh = MDLMesh(boxWithExtent: [1, 1, 1],
                              segments: [1, 1, 1],
                              inwardNormals: false,
                              geometryType: .triangles,
                              allocator: allocator)
        return mdlMesh
    }
}

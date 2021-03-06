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
        
        /** ????????????????????????????????????, ????????????????????? */
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
        
        /** ???????????????????????????????????????????????? */
        renderEncoder.setRenderPipelineState(pipelineState)
        /** ?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????*/
        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        
        guard let submesh = mesh.submeshes.first else {
            fatalError()
        }
        
        /** ??????*/
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: submesh.indexCount,
                                            indexType: submesh.indexType,
                                            indexBuffer: submesh.indexBuffer.buffer,
                                            indexBufferOffset: 0)
        
        /** ?????????????????????????????????????????????????????? */
        renderEncoder.endEncoding()
        
        guard let drawable = mtkView.currentDrawable else {
            fatalError()
        }
        // ??????
        commandBuffer.present(drawable)
        // ??????
        commandBuffer.commit()
        
        exportFile(with: mdlMesh)
    }
    
    /// ??????metal???????????????
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
    /// ????????????
    func sphereModel() -> MDLMesh {
        /** sphereWithExtent -> (x, y ,z) */
        let mdlMesh = MDLMesh(sphereWithExtent: [0.75, 0.75, 0.75],
                              segments: [100, 100],
                              inwardNormals: false,
                              geometryType: .triangles,
                              allocator: allocator)
        return mdlMesh
    }
    
    /// ????????????
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

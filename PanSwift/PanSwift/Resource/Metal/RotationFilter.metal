//
//  RotationFilter.metal
//  PanSwift
//
//  Created by Pan on 2022/8/4.
//

#include <metal_stdlib>
using namespace metal;

struct TextureVertexIn
{
    // 传递进来的顶点数据要定义成packed-->紧致矢量类型
    packed_float4 position;
    packed_float2 texCoords;
};

constant sampler kBilinearSampler(filter::linear, coord::pixel, address::clamp_to_edge);

/// 旋转滤镜
//kernel void rotationKernel(constant TextureVertexIn &vertex_array [[ buffer(0) ]],
//                           texture2d<half, access::read> sourceTexture [[texture(0)]],  // 源纹理
//                           texture2d<half, access::write> destTexture [[texture(1)]],   // 目标纹理
//                           uint2 grid [[thread_position_in_grid]]) {
//    half4 color = sourceTexture.read(grid);
//    float2 texCoords = vertex_array.texCoords;
//    destTexture.write(color, texCoords);
//}



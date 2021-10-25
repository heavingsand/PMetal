//
//  Shaders.metal
//  PanSwift
//
//  Created by Pan on 2021/9/14.
//

#include <metal_stdlib>

using namespace metal;

// MARK: - 基础Shader

struct VertexInOut {
    float4 position [[position]];
    float4 color;
};

// 顶点函数
vertex VertexInOut vertex_basic(const device packed_float3 *vertex_array [[buffer(0)]],
                                constant packed_float4 *color [[buffer(1)]],
                                unsigned int vid [[vertex_id]]) {
    VertexInOut outVertex;
    outVertex.position = float4(vertex_array[vid], 1.0);
    outVertex.color = color[vid];
    return outVertex;
}

// 片元函数
fragment half4 fragment_basic(VertexInOut inFrag [[stage_in]]) {
    return half4(inFrag.color);
//    return half4(1.0);
}


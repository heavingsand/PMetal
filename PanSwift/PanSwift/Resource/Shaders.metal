//
//  Shaders.metal
//  PanSwift
//
//  Created by Pan on 2021/9/14.
//

#include <metal_stdlib>

using namespace metal;

struct CameraVertex {
    vector_float4 clipSpacePosition [[position]];
    vector_float2 textureCoordinate;
};

typedef struct {
    // position的修饰符表示这个是顶点
    float4 clipSpacePosition [[position]];
    // 纹理坐标，会做插值处理
    float2 textureCoordinate;
} RasterizerData;

struct VertexInOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexInOut vertex_basic(const device packed_float3 *vertex_array [[buffer(0)]],
                                constant packed_float4 *color [[buffer(1)]],
                                unsigned int vid [[vertex_id]]) {
    VertexInOut outVertex;
    outVertex.position = float4(vertex_array[vid], 1.0);
    outVertex.color = color[vid];
    return outVertex;
}

fragment half4 fragment_basic(VertexInOut inFrag [[stage_in]]) {
    return half4(inFrag.color);
//    return half4(1.0);
}


//
//  DepthShader.metal
//  PanSwift
//
//  Created by Pan on 2022/7/13.
//

#include <metal_stdlib>
using namespace metal;

struct TextureVertex
{
    float4 position [[position]];
    float2 texCoords;
};

struct InputFloat3
{
    float x;
    float y;
    float z;
};

/// 顶点函数
vertex TextureVertex depth_texture_vertex(constant packed_float3 *inVertex [[buffer(0)]],
                                          uint vid [[vertex_id]])
{
    TextureVertex vert;
    vert.position = float4(inVertex[vid].x, inVertex[vid].y, inVertex[vid].z, 1.0);
    /** 这里要进行iOS坐标系和平面坐标系的转换*/
    vert.texCoords = float2(0.5 + inVertex[vid].x / 2.0, 0.5 - inVertex[vid].y / 2.0);
    return vert;
}

/// 片元函数
fragment half4 depth_texture_fragment(TextureVertex vert [[stage_in]],
                                      texture2d<float> videoTexture [[texture(0)]],
                                      texture2d<float> blurTexture [[texture(1)]],
                                      texture2d<float> depthTexture [[texture(2)]],
                                      sampler samplr [[sampler(0)]])
{
    // 获取纹理对应位置的颜色
    float r = depthTexture.sample(samplr, vert.texCoords).r;
    if (r < 1.0) {
        return half4(videoTexture.sample(samplr, vert.texCoords));
    } else {
        return half4(blurTexture.sample(samplr, vert.texCoords));
    }
}



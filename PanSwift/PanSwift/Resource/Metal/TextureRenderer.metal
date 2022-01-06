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
vertex TextureVertex texture_vertex_main(constant InputFloat3 *inVertex [[buffer(0)]],
                                         uint vid [[vertex_id]])
{
    TextureVertex vert;
    vert.position = float4(inVertex[vid].x, inVertex[vid].y, inVertex[vid].z, 1.0);
    /** 这里要进行iOS坐标系和平面坐标系的转换*/
    vert.texCoords = float2(0.5 + inVertex[vid].x / 2.0, 0.5 - inVertex[vid].y / 2.0);
    return vert;
}

/// 片元函数
fragment half4 texture_fragment_main(TextureVertex vert [[stage_in]],
                                     texture2d<float> videoTexture [[texture(0)]],
                                     sampler samplr [[sampler(0)]])
{
    // 获取纹理对应位置的颜色
    float3 texColor = videoTexture.sample(samplr, vert.texCoords).rgb;
    return half4((half3)texColor, 1);
}

/// 片元函数
fragment half4 texture_fragment_main_one(TextureVertex vert [[stage_in]], // stage_in表示这个数据来自光栅化。（光栅化是顶点处理之后的步骤，业务层无法修改）
                                         texture2d<half> texture [[texture(0)]]) // texture表明是纹理数据，0是索引
{
    // 创建采样器
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    // 获取纹理对应位置的颜色
    const half4 color = texture.sample(textureSampler, vert.texCoords);
    return half4(color.r * 0.5, color.gba);
}

//
//  RenderShader.metal
//  PMetal
//
//  Created by Pan on 2022/7/26.
//

#include <metal_stdlib>
using namespace metal;

/// 顶点纹理
struct TextureVertex
{
    float4 position [[position]];
    float2 texCoords;
};

/// 纹理顶点输入
struct TextureVertexIn
{
    // 传递进来的顶点数据要定义成packed-->紧致矢量类型
    packed_float4 position;
    packed_float2 texCoords;
};

/// 渲染采样器
//constant sampler kRenderSampler(min_filter::nearest, mag_filter::linear, mip_filter::linear, address::clamp_to_edge);
constant sampler kRenderSampler(filter::linear, address::clamp_to_edge);

/// 顶点函数
vertex TextureVertex render_vertex(uint vid [[vertex_id]],  // vertex_id是顶点shader每次处理的index，用于定位当前的顶点
                                   constant TextureVertexIn *inVertex [[buffer(0)]]) // buffer表明是缓存数据，0是索引
{
    TextureVertex textureVertex;
    textureVertex.position = inVertex[vid].position;
    textureVertex.texCoords = inVertex[vid].texCoords;
    return textureVertex;
}

/// 片元函数
fragment half4 render_fragment(TextureVertex textureVertex [[stage_in]], // stage_in表示这个数据来自光栅化。（光栅化是顶点处理之后的步骤，业务层无法修改）
                               texture2d<float> texture [[texture(0)]]) // texture表明是纹理数据，0是索引
{
    // 获取纹理对应位置的颜色
    float3 color = texture.sample(kRenderSampler, textureVertex.texCoords).rgb;
    return half4((half3)color, 1);
}

//
//  WatermarkShader.metal
//  PanSwift
//
//  Created by 潘柯宏 on 2024/8/21.
//

#include <metal_stdlib>
using namespace metal;

struct TextureVertex
{
    float4 position [[position]];
    float2 texCoords;
};

struct WatermarkParameters {
    float2 position;
    float2 size;
};

/// 水印片元函数
fragment float4 watermark_fragment(TextureVertex vert [[stage_in]],
                                   texture2d<float> imageTexture [[texture(0)]],
                                   texture2d<float> watermarkTexture [[texture(1)]],
                                   constant WatermarkParameters &params [[buffer(1)]]) {
    // 初始化采样器
    constexpr sampler textureSampler(s_address::clamp_to_edge,
                                     t_address::clamp_to_edge,
                                     mag_filter::linear,
                                     min_filter::nearest,
                                     mip_filter::linear);
    
    float4 imageColor = imageTexture.sample(textureSampler, vert.texCoords);
    float2 imageSize = float2(imageTexture.get_width(), imageTexture.get_height());
    float2 watermarkCoord = (vert.texCoords * imageSize - params.position) / params.size;
    
    // 只有在水印区域内才绘制水印
    if (watermarkCoord.x >= 0.0 && watermarkCoord.x <= 1.0 && watermarkCoord.y >= 0.0 && watermarkCoord.y <= 1.0) {
        float4 watermarkColor = watermarkTexture.sample(textureSampler, watermarkCoord);
        return mix(imageColor, watermarkColor, watermarkColor.a);
    } else {
        return imageColor;
    }
}

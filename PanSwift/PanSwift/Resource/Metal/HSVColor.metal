//
//  HSVColor.metal
//  PanSwift
//
//  Created by Pan on 2022/9/19.
//

#include <metal_stdlib>
using namespace metal;

struct TextureVertex
{
    float4 position [[position]];
    float2 texCoords;
};

// MARK: 顶点函数

vertex TextureVertex hsv_vertex(constant vector_float2 *position [[buffer(0)]],
                                uint vid [[vertex_id]])
{
    TextureVertex vert;
    vert.position = float4(position[vid].x, position[vid].y, 0.0, 1.0);
    /** 这里要进行iOS坐标系和平面坐标系的转换*/
    vert.texCoords = float2(0.5 + position[vid].x / 2.0, 0.5 - position[vid].y / 2.0);
    return vert;
}

// MARK: 片元函数

fragment half4 hsv_fragment(TextureVertex vert [[stage_in]],
                            texture2d<half, access::sample> texture [[texture(0)]])
{
    float x = (vert.texCoords.x - 0.5) * 2.0;
    float y = (0.5 - vert.texCoords.y) * 2.0;
    
    // H分量
    float angleRad = atan2(y, x);
    float hue = (angleRad + M_PI_F) / (2.0 * M_PI_F) + 0.5;
    if(hue > 1.0) {
        hue -= 1.0;
    }
    
    // S分量
    float distanceRadius = sqrt(pow(x, 2.0) + pow(y, 2.0));
    float saturation;
    if (distanceRadius > 1.0) {
        saturation = 1.0;
    } else {
        saturation = distanceRadius;
    }
    
    // V分量
    float brightness = 1.0;
    
    // 转换公式
    int hi = (int)(hue * 6.0);
    float f = (hue * 6.0) - hi;
    float p = brightness * (1.0 - saturation);
    float q = brightness * (1.0 - f * saturation);
    float t = brightness * (1.0 - (1.0 - f) * saturation);
    
    half4 color = half4(0.0, 0.0, 0.0, 1.0);
    if (hi == 0) {
        color = half4(brightness, t, p, 1.0);
    } else if (hi == 1) {
        color = half4(q, brightness, p, 1.0);
    } else if (hi == 2) {
        color = half4(p, brightness, t, 1.0);
    } else if (hi == 3) {
        color = half4(p, q, brightness, 1.0);
    } else if (hi == 4) {
        color = half4(t, p, brightness, 1.0);
    } else if (hi == 5) {
        color = half4(brightness, p, q, 1.0);
    }

    // 平滑函数, 消除圆形边缘锯齿
    half value = smoothstep(1.0 - 0.001, 1.0 + 0.001, distanceRadius);
    color = mix(color, half4(0.0, 0.0, 0.0, 0.0), value);
    
    return color;
}

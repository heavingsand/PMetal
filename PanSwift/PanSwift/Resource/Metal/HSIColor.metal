//
//  HSIColor.metal
//  PanSwift
//
//  Created by Pan on 2022/9/2.
//

#include <metal_stdlib>
using namespace metal;

struct TextureVertex
{
    float4 position [[position]];
    float2 texCoords;
};

// MARK: 顶点函数

vertex TextureVertex hsi_vertex(constant vector_float2 *position [[buffer(0)]],
                                uint vid [[vertex_id]])
{
    TextureVertex vert;
    vert.position = float4(position[vid].x, position[vid].y, 0.0, 1.0);
    /** 这里要进行iOS坐标系和平面坐标系的转换*/
    vert.texCoords = float2(0.5 + position[vid].x / 2.0, 0.5 - position[vid].y / 2.0);
    return vert;
}

// MARK: 片元函数

fragment half4 hsi_fragment(TextureVertex vert [[stage_in]],
                            texture2d<half, access::sample> texture [[texture(0)]])
{
    float x = (vert.texCoords.x - 0.5) * 2.0;
    float y = (0.5 - vert.texCoords.y) * 2.0;
    
    // H分量
    float angleRad = atan2(y, x);
    if (angleRad <= 0.0) {
        angleRad = angleRad + 2 * M_PI_F;
    }
    float angleDeg = angleRad * 180.f / M_PI_F;
    if (angleDeg < 0.f) {
        angleDeg = angleDeg + 360.f;
    }
    float h = angleDeg * M_PI_F / 180.f;

    // S分量
    float distanceRadius = sqrt(pow(x, 2.0) + pow(y, 2.0));
    float s;
    if (distanceRadius > 1.0) {
        s = 1.0;
    } else {
        s = distanceRadius;
    }

    // I分量
    float i = 1.0;

    // 计算公式
    float r, g, b;
    float otz = 2.0 * M_PI_F / 3.0;
    
    if (h >= 0.0 && h < otz) {
        b = i * (1.0 - s);
        r = i * (1.0 + (s * cos(h)) / (cos(M_PI_F / 3.0 - h)));
        g = 3.0 * i - (b + r);
    } else if (h >= otz && h < (2 * otz)) {
        float newAngleDeg = angleDeg - 120.0;
        h = newAngleDeg * M_PI_F / 180.f;

        r = i * (1.0 - s);
        g = i * (1.0 + (s * cos(h)) / cos(M_PI_F / 3.0 - h));
        b = 3.0 * i - (g + r);
    } else {
        float angleDeg2 = angleDeg - 240.f;
        h = angleDeg2 * M_PI_F / 180.f;

        g = i * (1.0 - s);
        b = i * (1.0 + (s * cos(h)) / (cos(M_PI_F / 3.0 - h)));
        r = 3.0 * i - (g + b);
    }

    half4 newRgb = normalize(half4(r, g, b, 1.0));
    return newRgb;
}

fragment half4 hsi_fragment1(TextureVertex vert [[stage_in]],
                            texture2d<half, access::sample> texture [[texture(0)]])
{
    float r = 1.0, g = 1.0, b = 1.0;
    
    float x = (vert.texCoords.x - 0.5) * 2.0;
    float y = (0.5 - vert.texCoords.y) * 2.0;
    float angleRad = atan2(y, x);
//    float h = (angleRad + M_PI_F);

    float h = (angleRad + M_PI_F)/(2.0*M_PI_F) + 0.5;
    if(h > 1.0){
        h -= 1.0;
    }
    
    // S分量
    float distanceRadius = sqrt(pow(x, 2.0) + pow(y, 2.0));
    float s;
    if (distanceRadius > 1.0) {
        s = 1.0;
    } else {
        s = distanceRadius;
    }
    
    
    // L分量
    float l = 0.5;
    
    float c = (1.0 - abs(2 * l - 1.0) * s);
    float m = (l - 0.5 * c);
    float3 hsl = float3(h,s,l);
    
    
    half4 color = half4(r, g, b, 1.0);

    float hue = h;
    float saturation = s;
    float light = l;
    half3 rgb = half3(0.0);
    
    if (saturation <= 0.0)
    {
        rgb.r = rgb.b = rgb.g = light;
    }
    else
    {
        float chroma = (1.0 - abs(2.0*light - 1.0)) * saturation;
        float x = chroma * (1.0 - abs(fmod(hue * 6.0, 2.0) - 1.0));
        if (hue < 1.0/6.0){
            rgb = half3(chroma, x, 0.0);
        }
        else if (hue < 1.0/3.0){
            rgb = half3(x, chroma, 0.0);
        }
        else if (hue < 0.5){
            rgb = half3(0.0, chroma, x);
        }
        else if (hue < 2.0/3.0){
            rgb = half3(0.0, x, chroma);
        }
        else if (hue < 5.0/6.0){
            rgb = half3(x, 0.0, chroma);
        }
        else{
            rgb = half3(chroma, 0.0, x);
        }
        
        float m = light-chroma*0.5;
        rgb += m;
    }
    
    return half4(rgb,1.0);
}



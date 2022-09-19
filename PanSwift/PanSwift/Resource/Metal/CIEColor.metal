//
//  CIEColor.metal
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

//constant float3x3 XYZToRGB = float3x3(2.3645, -0.5152, 0.0052,
//                                      -0.8965, 1.4264, -0.0144,
//                                      -0.4681, 0.0888, 1.0092);

constant float3x3 RGBToXYZ = float3x3(0.49001, 0.30999, 0.20000,
                                      0.17697, 0.81240, 0.01063,
                                      0, 0.01000, 0.99000);

constant float3x3 XYZToRGB = float3x3(2.3645, -0.8965, -0.4681,
                                      -0.5152, 1.4264, -0.0888,
                                      0.0052, -0.0144, 1.0092);

// MARK: 顶点函数

vertex TextureVertex cie_vertex(constant vector_float2 *position [[buffer(0)]],
//                                constant vector_float4 *color [[buffer(1)]],
                                uint vid [[vertex_id]])
{
    TextureVertex vert;
    vert.position = float4(position[vid].x, position[vid].y, 0.0, 1.0);
    /** 这里要进行iOS坐标系和平面坐标系的转换*/
    vert.texCoords = float2(0.5 + position[vid].x / 2.0, 0.5 - position[vid].y / 2.0);
//    vert.color = float4(color[vid].r, color[vid].g, color[vid].b, color[vid].a);
    return vert;
}

// MARK: 片元函数

fragment half4 cie_fragment(TextureVertex vert [[stage_in]],
                            texture2d<half, access::sample> texture [[texture(0)]])
{
    
    float x = (vert.texCoords.x - 0.5) * 2.0;
    float y = (0.5 - vert.texCoords.y) * 2.0;

    //创建采样器
//    constexpr sampler textureSampler (mag_filter::linear,
//                                      min_filter::linear);
//
//    half4 lineColor = texture.sample(textureSampler, vert.texCoords);
//
//    float width = texture.get_width();
//    float height = texture.get_height();
//    uint2 gridPosition = uint2(vert.texCoords.x * width, vert.texCoords.y * height);
////    half4 lineColor = texture.read(gridPosition);
//    float3 rgbColor = float3(float(lineColor.r), float(lineColor.g), float(lineColor.b));
//    float3 XYZ = RGBToXYZ * rgbColor;
//    float x = XYZ.x;
//    float y = XYZ.y;
//
//    float2 xy = normalize(vert.texCoords);
//    float x = xy.x;
//    float y = xy.y;
//    distance(<#half2 x#>, <#half2 y#>)
//    length(<#half2 x#>)
//    acos(<#float2 x#>)
//
//    float x = vert.texCoords.x;
//    float y = (1.0 - vert.texCoords.y);

    float z = 1 - x - y;
    float3 xyz = float3(x, y, z);

    float3 color = XYZToRGB * xyz;

    // 获取纹理对应位置的颜色
    return half4(half3(color), 1.0);
}


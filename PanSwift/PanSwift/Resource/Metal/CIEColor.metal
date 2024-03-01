//
//  CIEColor.metal
//  PanSwift
//
//  Created by Pan on 2022/9/19.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Property

struct TextureVertex
{
    float4 position [[position]];
    float2 texCoords;
};

enum ColorGamut {
    REC709 = 0,
    DCIP3,
    BT2020,
};

constant half3x2 REC709Point = half3x2(half2(0.6399, 0.3300), half2(0.2999, 0.6000), half2(0.1490, 0.0600));
constant half3x2 DCIP3Point = half3x2(half2(0.6799, 0.3200), half2(0.2650, 0.6899), half2(0.1500, 0.060));
constant half3x2 BT2020Point = half3x2(half2(0.7080, 0.2920), half2(0.1700, 0.7970), half2(0.1310, 0.0460));
    
// MARK: - Method
    
half3 Yxy2XYZ(half Y, half x, half y) {
    half X = x * (Y / y);
    half Z = (1 - x - y) * (Y / y);
    return half3(X, Y, Z);
}

half3 XYZ2RGB(half x, half y, half z) {
    half dr, dg, db;
    dr = 0.4185 * x - 0.1587 * y - 0.0828 * z;
    dg = -0.0912 * x + 0.2524 * y + 0.0157 * z;
    db = 0.0009 * x - 0.0025 * y + 0.1786 * z;
    
    half max = 0;
    max = dr > dg ? dr : dg;
    max = max > db ? max : db;
    
    dr = dr / max * 255;
    dg = dg / max * 255;
    db = db / max * 255;

    dr = dr > 0 ? dr : 0;
    dg = dg > 0 ? dg : 0;
    db = db > 0 ? db : 0;
    
    if (dr > 255) {
        dr = 255;
    }
    
    if (dg > 255) {
      dg = 255;
    }
            
    if (db > 255) {
      db = 255;
    }
    
    half r = dr + 0.5;
    half g = dg + 0.5;
    half b = db + 0.5;
    
    return half3(r / 255.0, g / 255.0, b / 255.0);
}

// 顺时针运动, 点是否在三角边的右边
half triangleSign(half2 point0, half2 point1, half2 point2) {
    return (point0.x - point2.x) * (point1.y - point2.y) - (point1.x - point2.x) * (point0.y - point2.y);
}

// 根据两点求边长
half sideLength(half2 point1, half2 point2) {
    return sqrt(pow(float(point1.x - point2.x), 2.0) + pow(float(point1.y - point2.y), 2.0));
}

// MARK: 顶点函数

vertex TextureVertex cie_vertex(constant vector_float2 *position [[buffer(0)]],
                                uint vid [[vertex_id]])
{
    TextureVertex vert;
    vert.position = float4(position[vid].x, position[vid].y, 0.0, 1.0);
    /** 这里要进行iOS坐标系和平面坐标系的转换*/
    vert.texCoords = float2(0.5 + position[vid].x / 2.0, 0.5 - position[vid].y / 2.0);
    return vert;
}

// MARK: 片元函数

fragment half4 cie_fragment(TextureVertex vert [[stage_in]],
                            constant ColorGamut &colorGamut [[buffer(0)]],
                            texture2d<half, access::sample> texture [[texture(0)]])
{
    
    // 创建采样器
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);

    half boundary = texture.sample(textureSampler, vert.texCoords).a;
    if (boundary <= 0) {
        return half4(0.0, 0.0, 0.0, 0.0);
    }
    
    half x = vert.texCoords.x;
    half y = 1 - vert.texCoords.y;
    half Y = 0.24;
    
    half3 XYZ = Yxy2XYZ(Y, x, y);
    half3 RGB = XYZ2RGB(XYZ.x, Y, XYZ.z);
    
    half2 redPoint, greenPoint, bluePoint;
    half2 point = half2(x, y);
    
    switch (colorGamut) {
        case REC709:
            redPoint = REC709Point[0];
            greenPoint = REC709Point[1];
            bluePoint = REC709Point[2];
            break;
        case DCIP3:
            redPoint = DCIP3Point[0];
            greenPoint = DCIP3Point[1];
            bluePoint = DCIP3Point[2];
            break;
        case BT2020:
            redPoint = BT2020Point[0];
            greenPoint = BT2020Point[1];
            bluePoint = BT2020Point[2];
            break;
    }
    
    float b0f = triangleSign(point, redPoint, greenPoint);
    float b1f = triangleSign(point, greenPoint, bluePoint);
    float b2f = triangleSign(point, bluePoint, redPoint);

    bool b0 = b0f <= 0.0;
    bool b1 = b1f <= 0.0;
    bool b2 = b2f <= 0.0;
    
    bool isInTriangle = ((b0 == b1) && (b1 == b2));
    float triangleSmoothConstant = 0.002;
    float minF = min(fabs(b0f),fabs(b1f));
    minF = min(minF,fabs(b2f));
    half value = 1.0;
    
    half4 color = half4(0.0, 0.0, 0.0, 1.0);
    // cie图边缘透明度不一致, 需要先做混合防止锯齿过大
    color = mix(half4(RGB, 1.0), half4(0.0, 0.0, 0.0, 1.0), (1 - boundary));
    if (isInTriangle) {
        // 三角边缘平滑逻辑
        if (minF < triangleSmoothConstant) {
            value = 1.0 - smoothstep(0, triangleSmoothConstant, minF);
            color = half4(RGB, 1.0);
            half4 colorOut = mix(half4(RGB, 1.0), half4(0.0, 0.0, 0.0, 1.0), 0.6);
            color = mix(color, colorOut, value);
        } else {
            color = half4(RGB, 1.0);
        }
    } else {
        color = mix(color, half4(0.0, 0.0, 0.0, 1.0), 0.6);
    }
    return color;
}


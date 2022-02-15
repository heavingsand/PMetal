//
//  LutFilter.metal
//  PanSwift
//
//  Created by Pan on 2022/1/5.
//

#include <metal_stdlib>
using namespace metal;

struct TextureVertex
{
    float4 position [[position]];
    float2 texCoords;
};

struct TextureVertexIn
{
    // 传递进来的顶点数据要定义成packed-->紧致矢量类型
    packed_float4 position;
    packed_float2 texCoords;
};

/// 顶点函数
vertex TextureVertex lut_texture_vertex(uint vid [[ vertex_id ]], // vertex_id是顶点shader每次处理的index，用于定位当前的顶点
                                        constant TextureVertexIn *vertex_array [[ buffer(0) ]]) // buffer表明是缓存数据，0是索引
{
    TextureVertex textureVertex;
    textureVertex.position =  vertex_array[vid].position;
    textureVertex.texCoords = vertex_array[vid].texCoords;
    return textureVertex;
}

constant float SquareSize = 63.0 / 512.0;
constant float stepSize = 0.0; // 0.5 / 512.0;

/// 片元函数
fragment half4 lut_texture_fragment(TextureVertex textureVertex [[ stage_in ]], // stage_in表示这个数据来自光栅化。（光栅化是顶点处理之后的步骤，业务层无法修改）
                                    texture2d<half> imageTexture [[ texture(0) ]], // texture表明是纹理数据，0是索引
                                    texture2d<half> lutTexture [[ texture(1) ]]) // lut纹理
{
    // 创建采样器
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    // 获取正常的纹理颜色
    const half4 imageColor = imageTexture.sample(textureSampler, textureVertex.texCoords);
    
    float blueColor = imageColor.b * 63.0; // 蓝色部分[0, 63] 共64种
    
    float2 quad1; // 第一个正方形色块的位置, 假如blueColor=22.5, 则y=22/8=2, x=22-8*2=6, 即是第2行，第6个正方形；（因为y是纵坐标）
    quad1.y = floor(floor(blueColor) * 0.125); // 向下取整
    quad1.x = floor(blueColor) - (quad1.y * 8.0);
    
    float2 quad2; // 第二个正方形的位置，同上。注意x、y坐标的计算，还有这里用int值也可以，但是为了效率使用float
    quad2.y = floor(ceil(blueColor) * 0.125);
    quad2.x = ceil(blueColor) - (quad2.y * 8.0);
    
    float2 texPos1; // 计算颜色(r,b,g)在第一个正方形中对应位置
    /*
     quad1是正方形的坐标，每个正方形占纹理大小的1/8，即是0.125，所以quad1.x * 0.125是算出正方形的左下角x坐标
     stepSize这里设置为0，可以忽略；
     SquareSize是63/512，一个正方形小格子在整个图片的纹理宽度
     */
    
//    texPos1.x = (imageColor.r * 63 + quad1.x * 64) / 512;
    texPos1.x = (quad1.x * 0.125) + stepSize + (SquareSize * imageColor.r);
    texPos1.y = (quad1.y * 0.125) + stepSize + (SquareSize * imageColor.g);
    
    float2 texPos2; // 同上
    texPos2.x = (quad2.x * 0.125) + stepSize + (SquareSize * imageColor.r);
    texPos2.y = (quad2.y * 0.125) + stepSize + (SquareSize * imageColor.g);
    
    half4 newColor1 = lutTexture.sample(textureSampler, texPos1); // 正方形1的颜色值
    half4 newColor2 = lutTexture.sample(textureSampler, texPos2); // 正方形2的颜色值
    
    half4 newColor = mix(newColor1, newColor2, fract(blueColor)); // fract,返回此数的小数点(对于负数而言,例如-0.1, 返回-0.1-(-1)=0.9) , 根据小数点的部分进行mix
    
    return half4(newColor.rgb, imageColor.w);
}

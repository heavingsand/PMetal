//
//  MixerShader.metal
//  PanSwift
//
//  Created by Pan on 2022/6/13.
//

#include <metal_stdlib>
using namespace metal;

/// 混合参数
struct MixerParameters
{
    float2 pipPosition;
    float2 pipSize;
};

constant sampler kBilinearSampler(filter::linear, coord::pixel, address::clamp_to_edge);

/// 画中画并行计算函数
kernel void pipMixer(texture2d<half, access::read> fullScreenInput [[texture(0)]],  // 全屏纹理
                     texture2d<half, access::sample> pipInput [[texture(1)]],       // 画中画纹理
                     texture2d<half, access::write> outputTexture [[texture(2)]],   // 输出纹理
                     const device MixerParameters &mixerParameters [[buffer(0)]],   // 纹理混合所需参数
                     uint2 gid [[thread_position_in_grid]])                         // 当前节点在多线程网格中的位置
{
    uint2 pipPosition = uint2(mixerParameters.pipPosition);
    uint2 pipSize = uint2(mixerParameters.pipSize);
    
    half4 outputColor;
    
    // 检查输出像素应该在全屏还是画中画
    if (gid.x >= pipPosition.x &&
        gid.y >= pipPosition.y &&
        gid.x < pipPosition.x + pipSize.x &&
        gid.y < pipPosition.y + pipSize.y) {
        // 定位并缩放画中画窗口
        float2 pipSamplingCoord = float2(gid - pipPosition) * float2(pipInput.get_width(), pipInput.get_height()) / float2(pipSize);
        outputColor = pipInput.sample(kBilinearSampler, pipSamplingCoord + 0.5);
    } else {
        outputColor = fullScreenInput.read(gid);
    }
    outputTexture.write(outputColor, gid);
}

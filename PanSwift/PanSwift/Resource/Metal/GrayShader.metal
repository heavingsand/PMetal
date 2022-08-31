//
//  GrayFilter.metal
//  PanSwift
//
//  Created by Pan on 2022/7/21.
//

#include <metal_stdlib>
using namespace metal;

/// 把rgba转换成亮度值
constant half3 kRec709Luma = half3(0.2126, 0.1752, 0.0722);

kernel void grayKernel(texture2d<half, access::read> sourceTexture [[texture(0)]],  // 源纹理
                       texture2d<half, access::write> destTexture [[texture(1)]],   // 目标纹理
                       uint2 grid [[thread_position_in_grid]])                      // 当前节点在多线程网格中的位置
{
    // 边界保护
    if (grid.x > destTexture.get_width() || grid.y > destTexture.get_height()) {
        return;
    }
    
    // 初始颜色
    half4 color = sourceTexture.read(grid);
    // 转换成亮度
    half gray = dot(color.rgb, kRec709Luma);
    // 写回对应纹理
    destTexture.write(half4(gray, gray, gray, 1.0), grid);
}

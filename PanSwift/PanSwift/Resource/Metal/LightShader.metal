//
//  LightShader.metal
//  PanSwift
//
//  Created by Pan on 2021/11/5.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float4 normal [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 lightIntensity;
};

struct Uniforms {
    float4 lightPosition;
    float4 color;
    packed_float4 reflectivity;
    packed_float4 intensity;
    float4x4 modelViewMatrix;
    float4x4 projectionMatrix;
};

vertex VertexOut lightingVertex (VertexIn vertexIn [[stage_in]],
                                constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut outVertex;
    float4 tnorm = normalize(uniforms.projectionMatrix * vertexIn.normal);
    float4 eyeCoords = uniforms.modelViewMatrix * float4(vertexIn.position, 1.0);
    float4 s = normalize(float4(uniforms.lightPosition - eyeCoords));
    outVertex.lightIntensity = uniforms.intensity * uniforms.reflectivity * max(dot(s, tnorm),0.0);
    outVertex.position = uniforms.modelViewMatrix * float4(vertexIn.position, 1.0);
    return outVertex;
}

fragment half4 lightingFragment(VertexOut inFrag [[stage_in]],
                                constant Uniforms &uniforms [[buffer(1)]]) {
    return half4(inFrag.lightIntensity * uniforms.color);
}

#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec4 uBounds;
uniform sampler2D uBackground;
out vec4 fragColor;

vec3 sampleLinear(vec2 uv) {
    vec2 pixel = uv * uSize - 0.5;
    vec2 base = floor(pixel);
    vec2 f = fract(pixel);
    vec2 a = (base + 0.5) / uSize;
    vec2 stepUV = 1.0 / uSize;
    return mix(mix(texture(uBackground, a).rgb, texture(uBackground, a + vec2(stepUV.x, 0.0)).rgb, f.x),
               mix(texture(uBackground, a + vec2(0.0, stepUV.y)).rgb, texture(uBackground, a + stepUV).rgb, f.x), f.y);
}

void main() {
    vec2 p = FlutterFragCoord().xy;
    vec2 halfSize = uBounds.zw * 0.5;
    float radius = halfSize.y;
    vec2 q = p - uBounds.xy - halfSize;
    float core = max(halfSize.x - radius, 0.0);
    vec2 radial = q - vec2(clamp(q.x, -core, core), 0.0);
    float distanceToCore = length(radial);
    float sd = distanceToCore - radius;
    float coverage = 1.0 - smoothstep(-1.0, 0.0, sd);
    if (coverage < 0.001) { fragColor = vec4(0.0); return; }

    // A smooth cylindrical body with spherical endcaps. Evaluate normals
    // analytically so no quantized normal texture can pit the rim.
    vec2 xy = radial / max(radius, 1.0);
    float nz = sqrt(max(0.002, 1.0 - dot(xy, xy)));
    vec3 normal = normalize(vec3(xy, nz));
    // A monotonic thick-lens mapping: 1.7x body magnification, stronger curved
    // edges, without folding the image into duplicated vertical streaks.
    float normalizedRadius = clamp(distanceToCore / radius, 0.0, 1.0);
    vec2 displacement = -radial * (0.42 + 0.10 * normalizedRadius * normalizedRadius);
    vec2 uv = (p + displacement) / uSize;
    #ifdef IMPELLER_TARGET_OPENGLES
      uv.y = 1.0 - uv.y;
    #endif
    uv = clamp(uv, 0.5 / uSize, 1.0 - 0.5 / uSize);
    vec3 color = sampleLinear(uv);
    float fresnel = pow(1.0 - nz, 2.5);
    float direction = 0.35 + 0.65 * abs(dot(normal.xy, normalize(vec2(-0.6, -0.8))));
    float rim = clamp(fresnel * direction * 0.48, 0.0, 0.48);
    color = mix(color, vec3(1.0), rim);
    fragColor = vec4(color * coverage, coverage);
}

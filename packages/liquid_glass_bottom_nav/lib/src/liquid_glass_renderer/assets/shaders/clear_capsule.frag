#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec4 uBounds;
uniform float uDark;
uniform float uBubble;
uniform float uHeld;
uniform float uScale;
uniform vec4 uTint;
uniform sampler2D uBackground;
out vec4 fragColor;

vec3 sampleLinear(vec2 point) {
    vec2 uv = point / uSize;
    #ifdef IMPELLER_TARGET_OPENGLES
      uv.y = 1.0 - uv.y;
    #endif
    uv = clamp(uv, 0.5 / uSize, 1.0 - 0.5 / uSize);
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

    // A flat optical slab with a curved 7dp bevel, rather than rescaling the
    // picture across the pane. The active lens has a full convex surface.
    float bevel = mix(min(radius, 7.0 * uScale), radius, uBubble);
    float slope = clamp(1.0 + sd / max(bevel, 1.0), 0.0, 1.0);
    vec2 xy = radial / max(distanceToCore, 0.001) * slope;
    float nz = sqrt(max(0.001, 1.0 - dot(xy, xy)));
    vec3 normal = normalize(vec3(xy, nz));
    // Snell's law. Inward bending locally magnifies the bevel/lens; the slab
    // interior samples the same screen position. No whole-pane compression.
    vec3 transmitted = refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / 1.46);
    float thickness = mix(8.0, 11.0 + 4.0 * uHeld, uBubble) * uScale;
    vec2 shift = transmitted.xy / max(-transmitted.z, 0.2) * thickness;
    vec3 color = sampleLinear(p + shift);
    // Very small spectral separation is limited to the curved perimeter.
    float dispersion = uBubble * smoothstep(0.65, 1.0, slope) * 0.32;
    color.r = mix(color.r, sampleLinear(p + shift * 1.035).r, dispersion);
    color.b = mix(color.b, sampleLinear(p + shift * 0.965).b, dispersion);
    // Continuous contrast compression keeps foreground labels readable over
    // page text without individual opaque disks or a fog/blur mask.
    vec3 contrast = mix(1.0 - (1.0 - color) / (1.0 + .95 * (1.0 - color)),
                        color / (1.0 + .95 * color), uDark);
    color = mix(contrast, color, uBubble * .28);
    float fresnel = pow(1.0 - nz, 2.0);
    float light = dot(normal.xy, normalize(vec2(-0.55, -0.83)));
    float highlight = fresnel * (0.20 + 0.46 * abs(light));
    float hairline = (1.0 - smoothstep(0.0, 1.1 * uScale, -sd));
    float reflection = mix(0.20, 0.12, uDark) + uBubble * mix(0.12, -0.06, uDark);
    reflection += mix(.075, mix(.12, .04, uDark), uBubble) * smoothstep(-0.6, 0.8, -q.y / radius);
    color = mix(color, vec3(1.0), clamp(reflection + highlight + hairline * .30, 0.0, .76));
    // The underside of a convex lens has a subtle, continuous contact edge.
    float shade = uBubble * smoothstep(0.15, 0.95, q.y / radius) * fresnel * .23;
    color *= 1.0 - shade;
    color = mix(color, uTint.rgb, uTint.a * uBubble * (1.0 - .72 * fresnel));
    fragColor = vec4(color * coverage, coverage);
}

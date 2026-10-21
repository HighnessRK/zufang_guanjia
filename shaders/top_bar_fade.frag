#include <flutter/runtime_effect.glsl>

// 顶栏「界内渐隐模糊」蒙版：
// BackdropFilter 将本着色器作为 outer 滤镜，对已模糊的背景图按 y 坐标
// 平滑降透明度（smoothstep），顶栏底边处恰好归零——模糊无硬边、无接缝。
//
// Uniforms:
//   u_size  —— 引擎自动绑定：输入纹理尺寸（勿手动赋值）
//   u_input —— 引擎自动绑定：inner 滤镜（高斯模糊）输出的背景图
//   u_fade  —— x = 渐隐起点（0..1，自顶向下）；y = 渐隐终点（1.0 = 底边归零）

uniform vec2 u_size;
uniform sampler2D u_input;
uniform vec2 u_fade;

out vec4 frag_color;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  // OpenGL 后端 y 轴翻转，否则上下颠倒
  uv.y = 1.0 - uv.y;
#endif
  vec4 c = texture(u_input, uv);
  // 平滑渐隐系数；背景图为预乘 alpha，rgb 需同步缩放保持预乘合法
  float m = 1.0 - smoothstep(u_fade.x, u_fade.y, uv.y);
  frag_color = vec4(c.rgb * m, c.a * m);
}

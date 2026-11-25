#version 460 core
// Fine cinematic grain + soft vignette, composited above the 3D view.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uGrain;     // grain strength (0..0.12)
uniform float uVignette;  // vignette strength (0..1)

out vec4 fragColor;

float hash(vec3 p) {
  p = fract(p * 0.3183099 + 0.1);
  p *= 17.0;
  return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float g = hash(vec3(floor(frag * 0.75), floor(uTime * 24.0))) - 0.5;
  vec2 c = uv - 0.5;
  c.x *= uSize.x / uSize.y;
  float v = smoothstep(0.35, 1.05, length(c)) * uVignette;
  float gl = max(g, 0.0) * uGrain * 2.0;   // lightening grain
  float gd = max(-g, 0.0) * uGrain * 2.0;  // darkening grain
  float a = clamp(v * 0.85 + gd + gl, 0.0, 1.0);
  vec3 col = vec3(0.93, 0.93, 0.90) * gl;  // premultiplied
  fragColor = vec4(col, a);
}

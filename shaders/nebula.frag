#version 460 core
// Soft, slowly drifting nebula used behind 2D-heavy screens (create, reading).
// Deliberately low-frequency and desaturated: atmosphere, not decoration.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec4 uColorA;   // deep base
uniform vec4 uColorB;   // mist
uniform vec4 uColorC;   // warm glow
uniform float uWarmth;  // 0..1 amount of warm glow

out vec4 fragColor;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
  float s = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    s += a * noise(p);
    p = p * 2.03 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return s;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 p = vec2(uv.x * uSize.x / uSize.y, uv.y) * 2.2;
  float t = uTime * 0.025;
  vec2 q = vec2(fbm(p + vec2(0.0, t)), fbm(p + vec2(5.2, 1.3) - t));
  float n = fbm(p + 1.8 * q + vec2(t * 0.6, -t * 0.4));
  float glow = smoothstep(0.45, 0.95, fbm(p * 0.7 + q * 1.3 + 3.0)) * uWarmth;
  vec3 col = mix(uColorA.rgb, uColorB.rgb, smoothstep(0.25, 0.85, n) * 0.55);
  col = mix(col, uColorC.rgb, glow * 0.45);
  // vertical falloff toward deep space at the top
  col *= mix(0.78, 1.04, smoothstep(0.0, 1.0, uv.y));
  fragColor = vec4(col, 1.0);
}

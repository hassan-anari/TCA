#version 460 core
// Reveal overlay: a warm luminous bloom that expands from the capsule centre
// while noisy filaments dissolve. Drawn over the 3D view during Memory Reveal.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uProgress;  // 0..1
uniform vec2 uCenter;     // in pixels

out vec4 fragColor;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 45758.5453); }
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 d = (frag - uCenter) / uSize.y;
  float r = length(d);
  float ang = atan(d.y, d.x);
  float ring = uProgress * 1.25;
  float n = noise(vec2(ang * 6.0, r * 8.0 - uTime * 0.6));
  float edge = exp(-pow((r - ring) * 9.0, 2.0)) * (0.55 + 0.45 * n);
  float core = exp(-r * r * 18.0) * smoothstep(0.0, 0.35, uProgress) * (1.0 - smoothstep(0.6, 1.0, uProgress));
  float a = clamp(edge * (1.0 - uProgress) + core * 0.85, 0.0, 1.0);
  vec3 col = mix(vec3(0.898, 0.773, 0.682), vec3(0.933, 0.929, 0.898), core);
  fragColor = vec4(col * a, a);
}

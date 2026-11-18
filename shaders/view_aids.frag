// Viewing aids on the GPU (m2-design §5.3): the photo as Gray, Values or
// Colors. The formulas are those of lib/core/imaging/tone.dart, the
// reference; test/features/view_aids/tone_shader_test.dart pins them.
//
// Uniform order matters: lib/features/view_aids/ui/tone_shader.dart sets
// them by index.

#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;     // painted size, in local coordinates
uniform float uMode;    // 0 gray, 1 values, 2 colors
uniform float uBands;   // values: 2–9
uniform float uCount;   // colors: palette size, 1–16
uniform vec4 uLab[16];  // palette in CIELAB (xyz), for the nearest match
uniform vec4 uRgb[16];  // the same colors in sRGB 0–1 (xyz), to draw
uniform sampler2D uImage;

out vec4 fragColor;

const float kDelta = 6.0 / 29.0;

float toLinear(float c) {
  return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}

float toSrgb(float v) {
  float c = v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1.0 / 2.4) - 0.055;
  return clamp(c, 0.0, 1.0);
}

float labF(float t) {
  return t > kDelta * kDelta * kDelta
      ? pow(t, 1.0 / 3.0)
      : t / (3.0 * kDelta * kDelta) + 4.0 / 29.0;
}

float labFInverse(float f) {
  return f > kDelta ? f * f * f : 3.0 * kDelta * kDelta * (f - 4.0 / 29.0);
}

// The sRGB gray with lightness [l] (L*, 0–100).
float grayForLStar(float l) {
  return toSrgb(labFInverse((clamp(l, 0.0, 100.0) + 16.0) / 116.0));
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 texel = texture(uImage, uv);
  // Images are premultiplied; photos are opaque, but be safe at the edges.
  vec3 srgb = texel.a > 0.0 ? texel.rgb / texel.a : vec3(0.0);
  vec3 lin = vec3(toLinear(srgb.r), toLinear(srgb.g), toLinear(srgb.b));

  // Linear sRGB → XYZ (D65); the Y row is tone.dart's luminance weights.
  vec3 xRow = vec3(0.4124564, 0.3575761, 0.1804375);
  vec3 yRow = vec3(0.2126, 0.7152, 0.0722);
  vec3 zRow = vec3(0.0193339, 0.1191920, 0.9503041);
  float y = dot(yRow, lin);

  vec3 outRgb;
  if (uMode < 0.5) {
    // Gray: the sRGB gray with the same luminance.
    float g = toSrgb(y);
    outRgb = vec3(g);
  } else if (uMode < 1.5) {
    // Values: equal steps of L*, each shown at its middle.
    float l = 116.0 * labF(y) - 16.0;
    float band = clamp(floor(l * uBands / 100.0), 0.0, uBands - 1.0);
    outRgb = vec3(grayForLStar((band + 0.5) * 100.0 / uBands));
  } else {
    // Colors: the nearest palette color in CIELAB (ΔE76).
    float whiteX = xRow.x + xRow.y + xRow.z;
    float whiteZ = zRow.x + zRow.y + zRow.z;
    float fx = labF(dot(xRow, lin) / whiteX);
    float fy = labF(y);
    float fz = labF(dot(zRow, lin) / whiteZ);
    vec3 lab = vec3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz));
    float best = 1e20;
    outRgb = uRgb[0].xyz;
    for (int i = 0; i < 16; i++) {
      if (float(i) >= uCount) break;
      vec3 d = lab - uLab[i].xyz;
      float dist = dot(d, d);
      if (dist < best) {
        best = dist;
        outRgb = uRgb[i].xyz;
      }
    }
  }
  fragColor = vec4(outRgb * texel.a, texel.a);
}

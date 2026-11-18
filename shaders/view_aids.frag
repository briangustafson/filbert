// Viewing aids on the GPU (m2-design §5.3): the photo as Gray, Values or
// Colors, optionally with a compare photo blended over it (§3.4). The
// formulas are those of lib/core/imaging/tone.dart, the reference;
// test/features/view_aids/tone_shader_test.dart pins them.
//
// Uniform order matters: lib/features/view_aids/ui/tone_shader.dart sets
// them by index.

#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;     // painted size, in local coordinates
uniform float uMode;    // 0 gray, 1 values, 2 colors, 3 plain (no tone)
uniform float uBands;   // values: 2–9
uniform float uCount;   // colors: this photo's palette size, 1–16
uniform vec4 uLab[16];  // this photo's palette in CIELAB (xyz), to match
uniform vec4 uRgb[16];  // the same colors in sRGB 0–1 (xyz), to draw
uniform float uCompare; // 1 to blend the compare photo, 0 not
uniform float uOpacity; // compare: 0 only this photo, 1 only the other
uniform float uCount2;  // colors: the compare photo's palette size
uniform vec4 uLab2[16]; // the compare photo's palette, as above
uniform vec4 uRgb2[16];
uniform sampler2D uImage;
uniform sampler2D uOther; // the compare photo, stretched to this frame

out vec4 fragColor;

const float kDelta = 6.0 / 29.0;

// Linear sRGB → XYZ (D65); the Y row is tone.dart's luminance weights.
const vec3 kXRow = vec3(0.4124564, 0.3575761, 0.1804375);
const vec3 kYRow = vec3(0.2126, 0.7152, 0.0722);
const vec3 kZRow = vec3(0.0193339, 0.1191920, 0.9503041);

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

// Un-premultiplied sRGB of a texel. Photos are opaque, but be safe at the
// edges.
vec3 srgbOf(vec4 texel) {
  return texel.a > 0.0 ? texel.rgb / texel.a : vec3(0.0);
}

// [srgb] with the tone aid applied, using the first palette or, with
// [second], the compare photo's.
vec3 tone(vec3 srgb, bool second) {
  if (uMode > 2.5) return srgb;
  vec3 lin = vec3(toLinear(srgb.r), toLinear(srgb.g), toLinear(srgb.b));
  float y = dot(kYRow, lin);
  if (uMode < 0.5) {
    // Gray: the sRGB gray with the same luminance.
    return vec3(toSrgb(y));
  }
  if (uMode < 1.5) {
    // Values: equal steps of L*, each shown at its middle.
    float l = 116.0 * labF(y) - 16.0;
    float band = clamp(floor(l * uBands / 100.0), 0.0, uBands - 1.0);
    return vec3(grayForLStar((band + 0.5) * 100.0 / uBands));
  }
  // Colors: the nearest palette color in CIELAB (ΔE76).
  float whiteX = kXRow.x + kXRow.y + kXRow.z;
  float whiteZ = kZRow.x + kZRow.y + kZRow.z;
  float fx = labF(dot(kXRow, lin) / whiteX);
  float fy = labF(y);
  float fz = labF(dot(kZRow, lin) / whiteZ);
  vec3 lab = vec3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz));
  float best = 1e20;
  vec3 result = second ? uRgb2[0].xyz : uRgb[0].xyz;
  float count = second ? uCount2 : uCount;
  for (int i = 0; i < 16; i++) {
    if (float(i) >= count) break;
    vec3 d = lab - (second ? uLab2[i].xyz : uLab[i].xyz);
    float dist = dot(d, d);
    if (dist < best) {
      best = dist;
      result = second ? uRgb2[i].xyz : uRgb[i].xyz;
    }
  }
  return result;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 texel = texture(uImage, uv);
  vec3 rgb = tone(srgbOf(texel), false);
  if (uCompare > 0.5) {
    // Each photo toned first, then mixed as displayed (sRGB), like a
    // layer's opacity in a photo editor.
    vec3 other = tone(srgbOf(texture(uOther, uv)), true);
    rgb = mix(rgb, other, uOpacity);
  }
  fragColor = vec4(rgb * texel.a, texel.a);
}

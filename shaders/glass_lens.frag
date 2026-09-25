// Линза жидкого стекла: фон под стеклом преломляется у скруглённой кромки,
// как у толстого стекла со скошенным краем. Работает фильтром фона
// (ImageFilter.shader), поэтому только под Impeller.
#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// Порядок униформ — контракт с EvGlassLens: индексы setFloat идут подряд.
uniform vec2 uSize;         // 0–1   размер текстуры фона — задаёт движок
uniform vec4 uRect;         // 2–5   стекло в пикселях текстуры: x, y, ширина, высота
uniform float uRadius;      // 6     скругление, px
uniform float uBevel;       // 7     ширина кромки, на которой свет гнётся, px
uniform float uDepth;       // 8     сдвиг у самого края, px
uniform float uDispersion;  // 9     расхождение каналов, доля сдвига
uniform float uDebug;       // 10    1 — локальные координаты вместо фона

uniform sampler2D uBackdrop;

out vec4 fragColor;

float roundedBox(vec2 p, vec2 halfSize, float r) {
  r = min(r, min(halfSize.x, halfSize.y));
  vec2 q = abs(p) - halfSize + r;
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

vec4 backdrop(vec2 px) {
  vec2 uv = px / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  // у OpenGL ось выборки идёт снизу вверх
  uv.y = 1.0 - uv.y;
#endif
  return texture(uBackdrop, uv);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 halfSize = uRect.zw * 0.5;
  vec2 p = frag - (uRect.xy + halfSize);
  float d = roundedBox(p, halfSize, uRadius);

  if (uDebug > 0.5) {
    vec2 local = (frag - uRect.xy) / uRect.zw;
    fragColor = d <= 0.0 ? vec4(local, 0.0, 1.0) : backdrop(frag);
    return;
  }
  if (d >= 0.0 || uBevel <= 0.0) {
    fragColor = backdrop(frag);
    return;
  }

  // Нормаль кромки — градиент расстояния до неё.
  vec2 grad = vec2(
    roundedBox(p + vec2(1.0, 0.0), halfSize, uRadius) -
      roundedBox(p - vec2(1.0, 0.0), halfSize, uRadius),
    roundedBox(p + vec2(0.0, 1.0), halfSize, uRadius) -
      roundedBox(p - vec2(0.0, 1.0), halfSize, uRadius));
  float len = length(grad);
  vec2 n = len > 1e-4 ? grad / len : vec2(0.0);

  // Кромка — четверть круга: у края поверхность стоит отвесно, на глубине
  // uBevel ложится плашмя. Наклон растёт к краю быстрее линейного, поэтому
  // середина стекла почти не искажает, а у кромки фон заметно гнётся.
  float s = clamp(1.0 + d / uBevel, 0.0, 1.0);
  float bend = uDepth * (1.0 - sqrt(1.0 - s * s));

  // Луч уходит внутрь стекла: у края видно то, что лежит глубже под ним.
  vec2 shift = -n * bend;
  vec4 g = backdrop(frag + shift);
  float r = backdrop(frag + shift * (1.0 + uDispersion)).r;
  float b = backdrop(frag + shift * (1.0 - uDispersion)).b;
  fragColor = vec4(r, g.g, b, g.a);
}

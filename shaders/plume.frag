// Плюм пара за интерфейсом — перенос WebGL-шейдера из прототипа
// (design/evaporate-launcher.html, «ambient WebGL plume») без изменений
// в математике.
#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// Порядок униформ — контракт с EvAtmosphere: индексы setFloat идут подряд.
uniform vec2 uRes;   // 0–1   размер кадра в пикселях
uniform float uT;    // 2     секунды
uniform vec2 uM;     // 3–4   курсор 0…1, y снизу вверх
uniform vec3 cHot;   // 5–7   акцент облика
uniform vec3 cHot2;  // 8–10
uniform vec3 cCool;  // 11–13

out vec4 fragColor;

float h(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float n(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x),
             mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
  float s = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    s += a * n(p);
    p = p * 2.03 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return s;
}

void main() {
  // Кадр рисуется в отдельную картинку без преобразований, поэтому
  // координата здесь одна и та же у Skia и Impeller. Ось y перевёрнута:
  // шейдер писался под WebGL, где начало координат внизу.
  vec2 fc = FlutterFragCoord().xy;
  fc.y = uRes.y - fc.y;

  vec2 uv = (fc - 0.5 * uRes) / uRes.y;
  vec2 par = (uM - 0.5) * 0.22;
  uv += par;
  float t = uT * 0.028;

  // поднимающийся плюм: область сдвигается вверх со временем
  vec2 p = uv * 1.5 + vec2(0.0, -t * 2.2);
  vec2 q = vec2(fbm(p + vec2(0.0, t)), fbm(p + vec2(5.2, 1.3) - t));
  vec2 r = vec2(fbm(p + 3.4 * q + vec2(1.7, 9.2) + t * 0.6),
                fbm(p + 3.4 * q + vec2(8.3, 2.8) - t * 0.4));
  float f = fbm(p + 3.0 * r);

  // спад по вертикали — плотный внизу, редеет, поднимаясь
  float rise = smoothstep(-0.95, 0.75, uv.y);
  float body = pow(clamp(f * 1.25, 0.0, 1.0), 1.6) * (1.0 - rise * 0.86);
  vec3 col = mix(cHot * 0.55, cHot2, clamp(r.x * 1.25, 0.0, 1.0));
  col = mix(col, cCool, clamp(q.y * 0.85 - 0.15, 0.0, 1.0) * 0.55);

  // горячее ядро у жерла
  float core = exp(-length(uv - vec2(0.16, -0.62)) * 2.3);
  col += cHot2 * core * 0.55;
  float a = body * 0.62 + core * 0.22;

  // тихая полоса развёртки: живо, но не суетливо
  a *= 0.82 + 0.18 * sin(uv.y * 7.0 + uT * 0.35);
  a *= smoothstep(1.25, 0.05, length(uv * vec2(0.72, 1.0)));

  // Смешение прототипа: выход обрезается до 0…1 и ложится на пустой буфер
  // через SRC_ALPHA / ONE_MINUS_SRC_ALPHA, а буфер уходит на страницу как
  // предумноженный. Итог: цвет = clamp(col·a·1.5)·a′, альфа = a′²,
  // где a′ = 0.92·a.
  //
  // В самом прототипе холст был запрошен без предумноженной альфы, и
  // браузер умножал на неё в третий раз: вклад плюма не превышал 1 %
  // яркости — фон был включён, но невидим. Замерено readPixels.
  float ap = a * 0.92;
  vec3 rgb = clamp(col * a * 1.5, 0.0, 1.0) * ap;
  fragColor = vec4(rgb, ap * ap);
}

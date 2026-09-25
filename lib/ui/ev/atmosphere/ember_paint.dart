import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'ember_field.dart';

/// Сторона спрайта свечения, px.
const _spriteSize = 32.0;

/// Белый спрайт свечения искры: те же ступени, что у градиента искры в
/// прототипе, — ядро, 28 % на трети радиуса, ноль на краю. Окрашивается
/// под каждую искру при рисовании.
ui.Image makeEvEmberSprite() {
  const center = Offset(_spriteSize / 2, _spriteSize / 2);
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawCircle(
    center,
    _spriteSize / 2,
    Paint()
      ..shader = ui.Gradient.radial(
        center,
        _spriteSize / 2,
        const [Color(0xFFFFFFFF), Color(0x47FFFFFF), Color(0x00FFFFFF)],
        const [0, 0.35, 1],
      ),
  );
  final picture = recorder.endRecording();
  final image = picture.toImageSync(_spriteSize.toInt(), _spriteSize.toInt());
  picture.dispose();
  return image;
}

/// Искры: свечение одним вызовом drawAtlas из белого [sprite], окрашенного
/// под каждую, и светлое ядро поверх. Смешение «экран», как у холста
/// частиц в прототипе. Горячие искры — цвета [hot], холодные — [cool].
void paintEvEmbers(
  Canvas canvas,
  Iterable<EvEmber> embers, {
  required ui.Image sprite,
  required Color hot,
  required Color cool,
}) {
  final transforms = <RSTransform>[];
  final rects = <Rect>[];
  final tints = <Color>[];
  final cores = <(Offset, double, double)>[];
  const source = Rect.fromLTWH(0, 0, _spriteSize, _spriteSize);
  for (final e in embers) {
    final a = e.opacity;
    if (a <= 0.004) continue;
    final rr = e.coreRadius;
    transforms.add(
      RSTransform.fromComponents(
        rotation: 0,
        scale: rr * 5.5 / (_spriteSize / 2),
        anchorX: _spriteSize / 2,
        anchorY: _spriteSize / 2,
        translateX: e.x,
        translateY: e.y,
      ),
    );
    rects.add(source);
    tints.add((e.cool ? cool : hot).withValues(alpha: a));
    cores.add((Offset(e.x, e.y), rr * 0.55, a * 0.9));
  }
  if (transforms.isEmpty) return;
  canvas.drawAtlas(
    sprite,
    transforms,
    rects,
    tints,
    BlendMode.modulate,
    null,
    Paint()
      ..blendMode = BlendMode.screen
      ..filterQuality = FilterQuality.low,
  );
  final core = Paint()..blendMode = BlendMode.screen;
  for (final (center, radius, alpha) in cores) {
    core.color = Color.fromRGBO(255, 246, 230, alpha);
    canvas.drawCircle(center, radius, core);
  }
}

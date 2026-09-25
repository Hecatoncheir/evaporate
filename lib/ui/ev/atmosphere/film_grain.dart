import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Плёночное зерно: плитка 128 × 128, серый 110…200 — как в прототипе.
///
/// Плитка одна на приложение: её кладут и поверх фона (атмосфера), и поверх
/// матового стекла, где она снимает бандинг на размытии.
abstract final class EvFilmGrain {
  static ui.Image? _image;
  static Future<ui.Image>? _loading;

  /// Готовая плитка; `null` — ещё не загружена.
  static ui.Image? get image => _image;

  /// Меняется один раз, когда плитка готова: тем, кто уже нарисовал кадр
  /// без зерна, нужно перерисоваться.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Future<ui.Image> load() => _loading ??= _make().then((image) {
    _image = image;
    revision.value++;
    return image;
  });

  static Future<ui.Image> _make() {
    const side = 128;
    final random = math.Random(128);
    final pixels = Uint8List(side * side * 4);
    for (var i = 0; i < side * side; i++) {
      final v = 110 + random.nextInt(90);
      pixels
        ..[i * 4] = v
        ..[i * 4 + 1] = v
        ..[i * 4 + 2] = v
        ..[i * 4 + 3] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      side,
      side,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}

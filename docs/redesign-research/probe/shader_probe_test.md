# shader_probe_test

Проба из исследования; в прогон тестов не входит, лежит как образец. Запускать из scratchpad: `flutter test <абсолютный путь>`.

```dart
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

// Проба: собирается ли настоящий шейдер из pubspec `flutter: shaders:`
// в прогоне `flutter test`, или он доступен только в сборке приложения.
void main() {
  ui.FragmentProgram? program;
  Object? failure;
  setUpAll(() async {
    try {
      program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/drops.frag',
      ).timeout(const Duration(seconds: 60));
    } on Object catch (e) {
      failure = e;
    }
  });

  test('drops.frag собирается в flutter test', () {
    // ignore: avoid_print
    print('PROBE_RESULT program=${program != null} failure=$failure');
    expect(program, isNotNull, reason: '$failure');
  });

  test('шейдер принимает униформы капель', () {
    final p = program;
    if (p == null) return;
    final shader = p.fragmentShader();
    shader
      ..setFloat(0, 1)
      ..setFloat(1, 120)
      ..setFloat(2, 180)
      ..setFloat(3, 1)
      ..setFloat(4, 600)
      ..setFloat(5, 900);
    // ignore: avoid_print
    print('PROBE_RESULT uniforms=ok');
    shader.dispose();
  });
}

```

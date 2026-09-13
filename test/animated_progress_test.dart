import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/animated_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Полоса хода загрузки.
///
/// Проверяется по нарисованному, а не по дереву виджетов, и на то есть
/// причина: заполнение однажды уже было честными тридцатью четырьмя
/// процентами в дереве и нулём на экране. `DecoratedBox` без ребёнка
/// схлопывался в нулевую высоту, и человек видел пустую дорожку под
/// надписью «34%». Дерево такую поломку не показывает — только пиксели.
void main() {
  /// Снимает полосу и отдаёт два столбца пикселей во всю её высоту:
  /// из заполненной части и из пустой.
  Future<({List<int> filled, List<int> empty})> shot(
    WidgetTester tester, {
    required double value,
    bool busy = false,
    bool dark = true,
  }) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? EvaporateTheme.dark() : EvaporateTheme.light(),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 400,
                child: AnimatedProgress(
                  value: value,
                  height: 6,
                  borderRadius: 4,
                  busy: busy,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Полоса едет к значению почти секунду — дожидаемся приезда.
    await tester.pump(const Duration(seconds: 2));

    // Снимок — только в настоящей зоне: под фейковым временем `toImage`
    // и `toByteData` не завершаются, и тест повисает молча.
    late Uint8List bytes;
    late int imageWidth;
    late int imageHeight;
    await tester.runAsync(() async {
      final render =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      imageWidth = image.width;
      imageHeight = image.height;
      bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      image.dispose();
    });

    List<int> columnAt(double fraction) {
      final x = (imageWidth * fraction).round().clamp(0, imageWidth - 1);
      return [
        for (var y = 0; y < imageHeight; y++)
          () {
            final i = (y * imageWidth + x) * 4;
            return (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
          }(),
      ];
    }

    // Десятая доля ширины при ходе в треть — заведомо внутри заполненного;
    // девять десятых — заведомо снаружи.
    return (filled: columnAt(0.1), empty: columnAt(0.9));
  }

  for (final dark in [true, false]) {
    final scheme = dark ? 'Арклайт' : 'Картридж';

    testWidgets('$scheme: заполненная часть закрашена по всей высоте', (
      tester,
    ) async {
      final pixels = await shot(tester, value: 0.34, dark: dark);

      // Каждая строка столбца, а не только середина: схлопывалась именно
      // высота, и серединный пиксель ничего бы не показал, окажись заливка
      // толщиной в один пиксель.
      expect(
        pixels.filled.every((pixel) => !pixels.empty.contains(pixel)),
        isTrue,
        reason: 'заливка должна занимать всю высоту полосы, а не полоску',
      );
    });
  }

  testWidgets('на работающей задаче заполнение тоже видно', (tester) async {
    final pixels = await shot(tester, value: 0.34, busy: true);

    expect(pixels.filled.toSet(), isNot(pixels.empty.toSet()));
  });

  testWidgets('нулевой ход не закрашивает ничего', (tester) async {
    final pixels = await shot(tester, value: 0);

    expect(pixels.filled, pixels.empty);
  });
}

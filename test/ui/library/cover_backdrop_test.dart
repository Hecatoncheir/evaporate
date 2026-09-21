import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/detail/cover_backdrop.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/temp_dir.dart';

/// Обложка приглушённым фоном страницы игры.
///
/// Проверяется по нарисованному: фон обязан быть вверху и сходить на нет к
/// середине — иначе он спорит с содержимым, ради которого страницу и
/// открыли.
void main() {
  late Directory tmp;
  late String cover;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_backdrop_');
    // Однотонный красный квадрат: на нём видно и сам фон, и то, где он
    // кончился.
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 64, 64),
      Paint()..color = const Color(0xFFFF0000),
    );
    final image = await recorder.endRecording().toImage(64, 64);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    cover = '${tmp.path}/cover.png';
    await File(cover).writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });

  tearDownAll(() async {
    await deleteTempDir(tmp);
  });

  Game gameWith({String? path}) => Game(
    id: 'g1',
    title: 'Игра',
    addedAt: DateTime.now(),
    details: GameDetails(coverPath: path),
  );

  /// Средняя яркость строки пикселей на заданной доле высоты.
  Future<List<double>> brightness(
    WidgetTester tester, {
    required Game game,
    bool enabled = true,
    required List<double> rows,
  }) async {
    final key = GlobalKey();
    // Картинка читается с диска по-настоящему, поэтому и дерево строим в
    // настоящей зоне: под фейковым временем `Image.file` не дочитается, и
    // снимок поймает один затемняющий слой без самой обложки.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EvaporateTheme.dark(),
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 400,
                height: 400,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: EvaporateTheme.dark().colorScheme.surface,
                      ),
                    ),
                    Positioned.fill(
                      child: CoverBackdrop(game: game, enabled: enabled),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      // Дожидаемся самой картинки, а не отведённого на неё времени:
      // 120 мс под нагрузкой полного прогона не хватало, снимок ловил фон
      // без обложки, и тест мигал. Тот же `FileImage`, что у `Image.file`,
      // — значит, тот же ключ в кэше.
      final path = game.details.coverPath;
      if (path != null) {
        final context = key.currentContext!;
        await precacheImage(FileImage(File(path)), context);
      }
      await tester.pump();
    });
    await tester.pump();

    late Uint8List bytes;
    late int w, h;
    await tester.runAsync(() async {
      final render =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      w = image.width;
      h = image.height;
      bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      image.dispose();
    });

    return [
      for (final row in rows)
        () {
          final y = (h * row).round().clamp(0, h - 1);
          var red = 0;
          for (var x = 0; x < w; x++) {
            red += bytes[(y * w + x) * 4];
          }
          return red / w;
        }(),
    ];
  }

  testWidgets('фон держится вверху и тает к середине', (tester) async {
    final rows = await brightness(
      tester,
      game: gameWith(path: cover),
      rows: const [0.05, 0.45, 0.85],
    );

    // Вверху обложка проступает, к середине слабеет, внизу её нет вовсе.
    expect(rows[0], greaterThan(rows[1]));
    expect(rows[1], greaterThan(rows[2]));
  });

  testWidgets('приглушён, а не выложен в полную силу', (tester) async {
    final rows = await brightness(
      tester,
      game: gameWith(path: cover),
      rows: const [0.05],
    );

    // Чистый красный дал бы 255. Фон обязан остаться фоном.
    expect(rows.single, lessThan(140));
  });

  testWidgets('выключенный не рисует ничего', (tester) async {
    final on = await brightness(
      tester,
      game: gameWith(path: cover),
      rows: const [0.05],
    );
    final off = await brightness(
      tester,
      game: gameWith(path: cover),
      enabled: false,
      rows: const [0.05],
    );

    expect(off.single, lessThan(on.single));
  });

  testWidgets('игра без обложки обходится без фона и без падения', (
    tester,
  ) async {
    await brightness(tester, game: gameWith(), rows: const [0.05]);

    expect(tester.takeException(), isNull);
  });
}

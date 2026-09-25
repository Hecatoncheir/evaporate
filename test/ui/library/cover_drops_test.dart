import 'dart:io';
import 'dart:ui' as ui;

import 'package:evaporate/ui/library/effects/cover_drops.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/temp_dir.dart';

/// Капли рисует шейдер, и прогон тестов собирает его из `pubspec` так же,
/// как сборка приложения. Поэтому проверяется и сама отрисовка — что капли
/// рисуют обложку, а не чёрный прямоугольник, — и то, что плитка при любом
/// отказе остаётся плиткой: исчезнувшая обложка — уже поломка.
void main() {
  /// Настоящий PNG размером в точку: обложка декодируется, и подделка из
  /// нулей не прошла бы.
  const png = <int>[
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, //
    0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, //
    0, 0, 0, 13, 73, 68, 65, 84, 120, 218, 99, 252, 207, 192, 80, 15, //
    0, 4, 133, 1, 128, 132, 169, 140, 33, 0, 0, 0, 0, 73, 69, 78, 68, //
    174, 66, 96, 130,
  ];

  late Directory tmp;
  late String coverPath;

  // Файл готовим снаружи testWidgets: настоящий файловый ввод-вывод внутри
  // него живёт в фейковом времени и не завершается никогда.
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_drops_');
    coverPath = '${tmp.path}/cover.png';
    await File(coverPath).writeAsBytes(png);
  });

  tearDown(() async {
    CoverDrops.useProgram(null);
    await deleteTempDir(tmp);
  });

  Future<void> show(
    WidgetTester tester, {
    required bool enabled,
    String? coverPath,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 150,
            child: CoverDrops(
              enabled: enabled,
              coverPath: coverPath,
              child: const Text('обложка'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('выключенный эффект показывает обложку как есть', (tester) async {
    await show(tester, enabled: false, coverPath: coverPath);

    expect(find.text('обложка'), findsOneWidget);
    expect(find.byKey(const ValueKey('cover-drops')), findsNothing);
  });

  // У игры без обложки искажать нечего: капли на подложке с одним названием
  // ничего не украсили бы, а времени стоили бы столько же.
  testWidgets('без обложки капли не идут', (tester) async {
    await show(tester, enabled: true, coverPath: null);

    expect(find.text('обложка'), findsOneWidget);
    expect(find.byKey(const ValueKey('cover-drops')), findsNothing);
  });

  // Шейдер может не собраться на чужой машине, а обложка — исчезнуть с
  // диска между кадрами. Ни то, ни другое не повод терять плитку.
  testWidgets('несобравшийся шейдер оставляет обложку на месте', (
    tester,
  ) async {
    // ignore перед подстановкой: до первого слушателя тестовая среда
    // считает такую ошибку необработанной и валит тест раньше времени.
    final failing = Future<ui.FragmentProgram>.error(
      StateError('шейдер не собрался'),
    )..ignore();
    CoverDrops.useProgram(failing);

    await show(tester, enabled: true, coverPath: coverPath);

    expect(find.text('обложка'), findsOneWidget);
    expect(find.byKey(const ValueKey('cover-drops')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('с настоящим шейдером', () {
    // Программу грузим снаружи testWidgets: будущее, начатое в подменном
    // времени, в другом тесте не завершилось бы никогда.
    late ui.FragmentProgram program;
    setUpAll(() async {
      program = await ui.FragmentProgram.fromAsset('assets/shaders/drops.frag');
    });

    testWidgets('капли рисуют обложку, а не чёрное', (tester) async {
      CoverDrops.useProgram(Future.value(program));
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox(
                width: 100,
                height: 150,
                child: CoverDrops(
                  enabled: true,
                  coverPath: coverPath,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      // Обложка читается с диска и расшифровывается по-настоящему: шаги
      // загрузки проходят под настоящим временем, между ними — кадр.
      final drops = find.byKey(const ValueKey('cover-drops'));
      for (var i = 0; i < 40 && drops.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }
      expect(drops, findsOneWidget, reason: 'капли так и не пошли');
      // Фиксированное число кадров, а не pumpAndSettle: часы капель идут,
      // пока капли включены, и «успокоиться» им нечем.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final pixels = await tester.runAsync(() async {
        final image = await render.toImage();
        try {
          return (await image.toByteData())!.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      });
      // Обложка — красная точка: где-то на плитке красный обязан быть.
      var red = 0;
      for (var i = 0; i < pixels!.length; i += 4) {
        if (pixels[i] > 32) red++;
      }
      expect(red, greaterThan(pixels.length ~/ 4 ~/ 2));
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('пропавшая обложка не роняет плитку', (tester) async {
    await tester.runAsync(() => File(coverPath).delete());

    await show(tester, enabled: true, coverPath: coverPath);

    expect(find.text('обложка'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

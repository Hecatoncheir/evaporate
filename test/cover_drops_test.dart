import 'dart:io';
import 'dart:ui' as ui;

import 'package:evaporate/ui/library/cover_drops.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Капли рисует шейдер, а шейдер собирается вместе с приложением — в прогоне
/// тестов его нет. Проверить здесь можно и нужно другое: что плитка при
/// любом отказе остаётся плиткой. Сама картинка проверяется глазами, а вот
/// исчезнувшая обложка — уже поломка.
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
    if (await tmp.exists()) await tmp.delete(recursive: true);
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

  testWidgets('пропавшая обложка не роняет плитку', (tester) async {
    await tester.runAsync(() => File(coverPath).delete());

    await show(tester, enabled: true, coverPath: coverPath);

    expect(find.text('обложка'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

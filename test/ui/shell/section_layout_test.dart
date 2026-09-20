import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/ui/library/game_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  Future<TestHarness> show(WidgetTester tester, Size window) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    for (var i = 0; i < 8; i++) {
      harness.addGame(title: 'Игра $i');
    }
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    // Библиотека ложится на диск через 400 мс после правки: не дождавшись,
    // тест уносит дерево вместе с живым таймером.
    await tester.pump(const Duration(milliseconds: 500));
    return harness;
  }

  // Главное, ради чего подписи разделов стали одной строкой. Прежде сверху
  // стояли метка, лозунг кеглем 32 и абзац про библиотеку — около ста
  // двадцати точек, — и в окне 1280×900 первый ряд обложек уходил под
  // нижний край: библиотека не показывала ни одной полной обложки.
  testWidgets('первый ряд обложек виден целиком в окне 1280×900', (
    tester,
  ) async {
    await show(tester, const Size(1280, 900));

    final grid = tester.getRect(find.byType(GridView));
    final tile = tester.getRect(find.byType(GameCoverTile).first);

    expect(tile.top, greaterThanOrEqualTo(grid.top));
    expect(
      tile.bottom,
      lessThanOrEqualTo(grid.bottom),
      reason: 'обложка обрезана нижним краем полки',
    );
  });

  testWidgets('раздел подписан меткой, а не своим именем трижды', (
    tester,
  ) async {
    final harness = await show(tester, const Size(1280, 900));

    // Имя раздела стоит в обойме сверху — и только там. Заголовок кеглем
    // 34 повторял его на самой странице третий раз, считая метку.
    for (final (section, label, name) in [
      (AppSection.library, '[ 01 / КОЛЛЕКЦИЯ ]', 'БИБЛИОТЕКА'),
      (AppSection.downloads, '[ 02 / АКТИВНО ]', 'ЗАГРУЗКИ'),
      (AppSection.saves, '[ 03 / СИНХРОНИЗАЦИЯ ]', 'СОХРАНЕНИЯ'),
      (AppSection.settings, '[ 04 / ПАРАМЕТРЫ ]', 'НАСТРОЙКИ'),
    ]) {
      harness.nav.add(SectionSelected(section));
      await tester.pumpAndSettle();

      expect(find.text(label), findsOneWidget, reason: 'метка раздела $label');
      expect(
        find.text(name),
        findsOneWidget,
        reason: 'имя «$name» должно остаться только в обойме',
      );
    }
  });

  testWidgets('нижняя строка занята показаниями, а не мебелью сайта', (
    tester,
  ) async {
    await show(tester, const Size(1280, 900));

    // Копирайт и ссылки на репозиторий занимали место навсегда, а нажимали
    // их один раз в жизни. Ссылка переехала в «О программе».
    expect(find.text('© 2026 EVAPORATE'), findsNothing);
    expect(find.text('GITHUB'), findsNothing);
    expect(find.text('RELEASES'), findsNothing);
    expect(find.text('ОСТАНОВЛЕН'), findsOneWidget);
  });
}

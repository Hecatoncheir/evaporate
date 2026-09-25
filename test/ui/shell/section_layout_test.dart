import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/ui/ev/shell/ev_top_bar.dart';
import 'package:evaporate/ui/library/game_cover_tile.dart';
import 'package:evaporate/ui/library/library_body.dart';
import 'package:evaporate/ui/shell/shell_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';
import '../../support/test_app.dart';

void main() {
  final l = LRu();
  late Directory tmp;

  // Влез ли ряд обложек и встала ли панель в строку — свойства настоящей
  // раскладки: служебный шрифт набирает строки вдвое шире, и тест мерил бы
  // окно, которого человек не увидит.
  setUpAll(loadAppFonts);
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
  // нижний край: библиотека не показывала ни одной полной обложки. В
  // наименьшем окне ряд срезала панель библиотеки: обойма слева сузила
  // её, и органы панели вставали столбцом в три строки.
  //
  // Страница с тех пор прокручивается целиком, но первый экран — тот, что
  // видят, открыв библиотеку, — по-прежнему обязан показать ряд обложек:
  // видимое — место раздела между полосами, а не вся прокрутка.
  for (final window in [const Size(1280, 900), const Size(900, 620)]) {
    testWidgets('первый ряд обложек виден целиком в окне '
        '${window.width.round()}×${window.height.round()}', (tester) async {
      await show(tester, window);

      final page = tester.getRect(find.byType(LibraryBody));
      final tile = tester.getRect(find.byType(GameCoverTile).first);

      expect(tile.top, greaterThanOrEqualTo(page.top));
      expect(
        tile.bottom,
        lessThanOrEqualTo(page.bottom),
        reason: 'обложка ушла под строку подсказок',
      );
    });
  }

  testWidgets('раздел подписан меткой, а не своим именем трижды', (
    tester,
  ) async {
    final harness = await show(tester, const Size(1280, 900));

    // Имя раздела стоит в крошке верхней полосы — и только там. Заголовок
    // кеглем 34 повторял его на самой странице третий раз, считая метку.
    for (final (section, label, name) in [
      (AppSection.library, '[ 01 / КОЛЛЕКЦИЯ ]', l.library),
      (AppSection.downloads, '[ 02 / АКТИВНО ]', l.downloads),
      (AppSection.saves, '[ 03 / СИНХРОНИЗАЦИЯ ]', l.saves),
      (AppSection.settings, '[ 04 / ПАРАМЕТРЫ ]', l.settings),
    ]) {
      harness.nav.add(SectionSelected(section));
      await tester.pumpAndSettle();

      expect(find.text(label), findsOneWidget, reason: 'метка раздела $label');
      // Подсказки рейла тоже называют раздел, но они не на странице.
      expect(
        find.descendant(of: find.byType(EvTopBar), matching: find.text(name)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ShellSections),
          matching: find.text(name),
        ),
        findsNothing,
        reason: 'имя «$name» должно остаться только в крошке полосы',
      );
    }
  });

  // Строка подсказок — облик прототипа как есть (0013), но состояние
  // движка в ней настоящее, а не «готов» из образца.
  testWidgets('нижняя строка показывает настоящее состояние движка', (
    tester,
  ) async {
    await show(tester, const Size(1280, 900));

    expect(find.text('● ${l.engineStopped2.toUpperCase()}'), findsOneWidget);
    expect(find.text('● ${l.evHintsReady}'), findsNothing);
    expect(find.text('GITHUB'), findsNothing);
  });
}

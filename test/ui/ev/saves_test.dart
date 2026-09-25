import 'package:evaporate/ui/ev/data/sample_data.dart';
import 'package:evaporate/ui/ev/data/sample_saves.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/saves/ev_conflict.dart';
import 'package:evaporate/ui/ev/saves/ev_timeline.dart';
import 'package:evaporate/ui/ev/saves/saves_data.dart';
import 'package:evaporate/ui/ev/screens/saves_page.dart';
import 'package:evaporate/ui/ev/widgets/ev_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void _window(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> _app(WidgetTester tester) async {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  await tester.pumpWidget(EvaporateApp(effects: effects));
  await _settle(tester);
}

Future<void> _page(
  WidgetTester tester,
  EvSavesState state, {
  VoidCallback? onResolve,
}) async {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildEvTheme(),
      home: EvEffectsScope(
        effects: effects,
        child: Scaffold(
          body: SavesPage(saves: sampleSavesFor(state), onResolve: onResolve),
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// Выбрать состояние сохранений в «Настройках → Разработка».
Future<void> _pick(WidgetTester tester, String name) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
  await _settle(tester);
  await tester.ensureVisible(find.text(name));
  await _settle(tester);
  await tester.tap(find.text(name));
  await _settle(tester);
  await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
  await _settle(tester);
}

void main() {
  group('числа облака', () {
    test('занято, защищено и конфликты выводятся, а не пишутся', () {
      final s = sampleSavesFor(EvSavesState.synced);
      // Полоса — то же число, что и надпись над ней.
      expect(s.fill, closeTo(4.1 / 20, 1e-9));
      // Под защитой те игры, в которые играли: у остальных нечего
      // сохранять.
      expect(
        s.protected,
        sampleLibrary.where((g) => g.played > Duration.zero).length,
      );
      expect(s.protected, 8);
      expect(s.conflicts, 0);
      expect(sampleSavesFor(EvSavesState.conflict).conflicts, 1);
    });

    test('«последняя выгрузка» — верхняя ушедшая точка ленты', () {
      final synced = sampleSavesFor(EvSavesState.synced);
      expect(synced.lastUpload, synced.points.first.ago);
      expect(synced.lastUpload, '6 мин');

      // Точка, которая уходит прямо сейчас, ещё не выгружена.
      final up = sampleSavesFor(EvSavesState.uploading);
      expect(up.points.first.mark, EvSaveMark.uploading);
      expect(up.lastUpload, up.points[1].ago);
      expect(up.lastUpload, '1 ч 20 мин');

      // Облако молчит — выгружать некуда и ленты нет.
      final none = sampleSavesFor(EvSavesState.noCloud);
      expect(none.points, isEmpty);
      expect(none.lastUpload, '—');
    });

    test('точка «Глубины 9» описывает ту ветку, на которую показывает', () {
      final c = sampleSavesFor(EvSavesState.conflict);
      final point = c.points.firstWhere((p) => p.game.title == 'Глубина 9');
      final theirs = c.conflict!.theirs;
      expect(point.device, theirs.device);
      expect(point.ago, theirs.ago);
      // Кислород в ленте — тот же, что в колонке этого устройства.
      expect(point.where, contains('73 %'));
      expect(theirs.facts, contains(('Кислород', '73 %')));
      expect(point.mark, EvSaveMark.conflict);

      // Без конфликта та же точка — обычная выгруженная.
      final s = sampleSavesFor(EvSavesState.synced);
      expect(
        s.points.firstWhere((p) => p.game.title == 'Глубина 9').mark,
        EvSaveMark.synced,
      );
    });
  });

  group('раздел «Сохранения»', () {
    testWidgets('обычное состояние: приборы, устройства и лента', (
      tester,
    ) async {
      _window(tester, 1440, 1200);
      await _page(tester, EvSavesState.synced);

      expect(find.textContaining('4.1', findRichText: true), findsOneWidget);
      expect(find.text('8'), findsOneWidget, reason: 'игр под защитой');
      expect(find.text('248'), findsOneWidget, reason: 'точек отката');
      expect(find.text('6 мин'), findsOneWidget, reason: 'последняя выгрузка');
      expect(find.text('0'), findsOneWidget, reason: 'конфликтов');

      expect(find.text('ПК · КУЗНЯ'), findsOneWidget);
      expect(find.text('в сети'), findsOneWidget);
      expect(find.text('офлайн'), findsOneWidget);
      expect(find.text('активно'), findsOneWidget);

      expect(find.byType(EvSaveRow), findsNWidgets(5));
      expect(find.byType(EvConflictCard), findsNothing);
      expect(find.text('выгружено'), findsNWidgets(5));
      expect(
        find.text('Пепельный Предел · Глава 5 «Кузня Сумерек»'),
        findsOneWidget,
      );
      expect(find.text('вчера, 23:41'), findsOneWidget);
      expect(find.text('3 дня назад'), findsOneWidget);
    });

    testWidgets('расхождение: две версии рядом и третий выход', (tester) async {
      _window(tester, 1440, 1200);
      var resolved = 0;
      await _page(tester, EvSavesState.conflict, onResolve: () => resolved++);

      expect(find.byType(EvConflictCard), findsOneWidget);
      expect(find.text('1 конфликт'), findsOneWidget, reason: 'счёт раздела');
      expect(find.text('1'), findsOneWidget, reason: 'и то же число в приборе');
      expect(
        find.text('Глубина 9 — два расхождения сохранения'),
        findsOneWidget,
      );
      // Обе версии показывают одни и те же четыре факта.
      expect(find.text('ПРОГРЕСС'), findsNWidgets(2));
      expect(find.text('КИСЛОРОД'), findsNWidgets(2));
      expect(find.text('Уровень 6 · 62 %'), findsOneWidget);
      expect(find.text('Уровень 5 · 88 %'), findsOneWidget);
      expect(find.text('ПРОТИВ'), findsOneWidget);
      expect(find.text('ПК · КУЗНЯ · это устройство'), findsOneWidget);
      expect(find.text('конфликт версий'), findsOneWidget);

      // Три выхода, и каждый разрешает расхождение.
      expect(find.text('Оставить эту'), findsNWidgets(2));
      await tester.tap(find.text('Оставить эту').first);
      await _settle(tester);
      await tester.tap(find.text('Оставить эту').last);
      await _settle(tester);
      await tester.tap(find.text('Сохранить обе копии'));
      await _settle(tester);
      expect(resolved, 3);
    });

    testWidgets('выгрузка идёт: полоса у верхней точки и только у неё', (
      tester,
    ) async {
      _window(tester, 1440, 1200);
      await _page(tester, EvSavesState.uploading);

      expect(find.text('выгружается · 62 %'), findsOneWidget);
      expect(find.text('92 МБ из 148 МБ'), findsOneWidget);
      expect(find.text('сейчас'), findsOneWidget);
      expect(find.byType(EvBar), findsNWidgets(2), reason: 'облако и точка');
      // Полоса точки не шире 420 — иначе она читалась бы как полоса
      // всего раздела.
      final bar = tester.getRect(find.byType(EvBar).last);
      expect(bar.width, closeTo(420, .5));
      expect(find.text('1 ч 20 мин'), findsOneWidget);
    });

    testWidgets('облако молчит: лента уходит, объяснение остаётся', (
      tester,
    ) async {
      _window(tester, 1440, 1200);
      await _page(tester, EvSavesState.noCloud);

      expect(find.byType(EvSaveTimeline), findsNothing);
      expect(find.text('Лента сохранений'), findsNothing);
      expect(find.byType(EvNothing), findsOneWidget);
      expect(find.text('Хранилище не отвечает'), findsOneWidget);
      expect(find.textContaining('5 сохранений ждут очереди'), findsOneWidget);
      expect(find.text('Проверить связь'), findsOneWidget);
      expect(find.text('—'), findsOneWidget, reason: 'выгружать некуда');
      // Хранилище тоже помечено офлайном — устройства и лента говорят
      // об облаке одно и то же.
      expect(find.text('офлайн'), findsNWidgets(2));
    });

    testWidgets('на узком окне версии встают друг под друга', (tester) async {
      _window(tester, 660, 1600);
      await _page(tester, EvSavesState.conflict);
      final sides = find.text('Оставить эту');
      final first = tester.getRect(sides.first);
      final second = tester.getRect(sides.last);
      expect(second.top, greaterThan(first.bottom));
      expect(find.text('ПРОТИВ'), findsNothing, reason: 'делить нечего');
    });
  });

  group('состояние окна', () {
    testWidgets('«Разработка» переключает раздел и плашку', (tester) async {
      _window(tester, 1440, 1000);
      await _app(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await _settle(tester);
      expect(find.byType(EvSaveTimeline), findsOneWidget);
      expect(find.widgetWithText(EvPill, 'Движок готов'), findsOneWidget);

      await _pick(tester, 'Конфликт версий');
      expect(find.byType(EvConflictCard), findsOneWidget);
      expect(find.widgetWithText(EvPill, '1 конфликт'), findsOneWidget);

      await _pick(tester, 'Облако недоступно');
      expect(find.byType(EvNothing), findsOneWidget);
      expect(find.widgetWithText(EvPill, 'Облако недоступно'), findsOneWidget);
    });

    testWidgets('решение конфликта убирает его из окна', (tester) async {
      _window(tester, 1440, 1000);
      await _app(tester);
      await _pick(tester, 'Конфликт версий');
      expect(find.byType(EvConflictCard), findsOneWidget);

      await tester.tap(find.text('Сохранить обе копии'));
      await _settle(tester);
      expect(find.byType(EvConflictCard), findsNothing);
      expect(find.widgetWithText(EvPill, '1 конфликт'), findsNothing);
      expect(find.widgetWithText(EvPill, 'Движок готов'), findsOneWidget);
    });
  });
}

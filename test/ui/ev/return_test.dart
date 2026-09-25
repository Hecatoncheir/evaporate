import 'dart:math' as math;

import 'package:evaporate/ui/ev/atmosphere/ember_field.dart';
import 'package:evaporate/ui/ev/data/game_facts.dart';
import 'package:evaporate/ui/ev/data/sample_data.dart';
import 'package:evaporate/ui/ev/data/sample_downloads.dart';
import 'package:evaporate/ui/ev/data/sample_friends.dart';
import 'package:evaporate/ui/ev/data/sample_saves.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/downloads/download_data.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/first_run/ev_first_run_widgets.dart';
import 'package:evaporate/ui/ev/launch/ev_launch_ritual.dart';
import 'package:evaporate/ui/ev/library/hero_state.dart';
import 'package:evaporate/ui/ev/returning/ev_return_widgets.dart';
import 'package:evaporate/ui/ev/returning/return_data.dart';
import 'package:evaporate/ui/ev/saves/saves_data.dart';
import 'package:evaporate/ui/ev/screens/downloads_page.dart';
import 'package:evaporate/ui/ev/screens/friend_profile_page.dart';
import 'package:evaporate/ui/ev/screens/saves_page.dart';
import 'package:evaporate/ui/ev/sheet/ev_game_sheet.dart';
import 'package:evaporate/ui/ev/widgets/ev_controls.dart';
import 'package:evaporate/ui/ev/widgets/ev_game_card.dart';
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
  await tester.pumpWidget(EvaporateApp(effects: effects, readCatalog: false));
  await _settle(tester);
}

/// Выбрать строку в «Настройках → Разработка» и вернуться в библиотеку.
Future<void> _dev(WidgetTester tester, String name) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
  await _settle(tester);
  await tester.ensureVisible(find.text(name));
  await _settle(tester);
  await tester.tap(find.text(name));
  await _settle(tester);
}

Future<void> _returned(WidgetTester tester) async {
  await _dev(tester, 'Второй запуск');
  await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
  await _settle(tester);
}

Finder get _news => find.textContaining('Пока вас не было ·');

void main() {
  final events = sampleDigestEvents();

  group('данные', () {
    test('пять событий, у каждого не больше одного действия', () {
      expect(events, hasLength(5));
      for (final e in events) {
        expect(e.action == null, e.target == null, reason: e.title);
      }
      expect(events.where((e) => e.action != null), hasLength(4));
    });

    test('события говорят то же, что окно', () {
      final orbita = sampleDownloadsFor(EvDownloadsState.active).torrents.first;
      expect(events.first.title, contains(orbita.game.title));
      expect(
        events.first.detail,
        '${formatGb(orbita.parts.received)} из '
        '${formatGb(orbita.parts.total)} · ${orbita.eta}',
      );
      // «Грозовой фронт» установлен — он раздаёт, а не качается.
      final storm = events.last.game!;
      expect(storm.state, EvGameState.ready);
      expect(
        events.last.detail,
        contains(
          EvGameFacts.of(storm).ratio.toStringAsFixed(2).replaceAll('.', ','),
        ),
      );
      expect(events[2].title, startsWith(samplePeople.first.name));
    });

    test('точка сохранения — верхняя точка ленты сохранений', () {
      final top = sampleSavesFor(EvSavesState.synced).points.first;
      expect(sampleReturnSpot.game, top.game);
      expect(top.note, contains(sampleReturnSpot.size));
      expect(top.where, contains('Кузня Сумерек'));
      expect(sampleReturnSpot.where, contains('Кузня Сумерек'));
    });

    test('версия патча — одна строка: предлагают её, ставят её же', () {
      final v = sampleUpdate.bareVersion;
      expect(v, isNot(sampleHero.bareVersion));
      expect(
        sampleHeroStates[EvHeroState.update]!.chips.first.$1,
        'Обновление $v',
      );
      expect(
        sampleHeroStates[EvHeroState.returned]!.chips.map((c) => c.$1),
        contains('${sampleUpdate.version} · обновлена'),
      );
      expect(events[1].title, contains(v));
      // Библиотека во втором запуске знает про обновление; в остальных — нет.
      expect(sampleLibraryFor(EvHeroState.returned).first.version, 'v$v');
      expect(sampleLibraryFor(EvHeroState.ready), same(sampleLibrary));
    });

    test('седьмое состояние героя: место, а не игра', () {
      final c = sampleHeroStates[EvHeroState.returned]!;
      expect(c.eyebrow, 'Вы остановились ${sampleReturnSpot.ago}');
      expect(c.savePoint, sampleReturnSpot);
      expect(c.chips.map((c) => c.$1), containsAll(['Глава 5']));
      expect(c.chips.any((c) => c.$1.contains('обновлена')), isTrue);
      expect(EvHeroState.values, hasLength(7));
    });

    test('панель испаряется: искры срываются из её прямоугольника', () {
      final field = EvEmberField(random: math.Random(7))
        ..resize(const Size(1440, 900), 1);
      const rect = Rect.fromLTWH(1000, 70, 360, 480);
      field.burstFrom(rect, count: 40);
      final burst = field.embers.take(40);
      for (final e in burst) {
        expect(rect.contains(Offset(e.x, e.y)), isTrue);
        expect(e.vy, lessThan(0), reason: 'вверх');
        expect(e.life, lessThanOrEqualTo(84 / 60));
      }
    });
  });

  group('виджеты', () {
    testWidgets('дайджест: пять строк, четыре действия, «Всё понятно»', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      final taps = <String>[];
      var done = 0;
      final effects = EvEffects.still();
      addTearDown(effects.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildEvTheme(),
          home: EvEffectsScope(
            effects: effects,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: EvDigest.width,
                  child: EvDigest(
                    events: events,
                    onAction: (e) => taps.add(e.action!),
                    onDone: () => done++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('ПОКА ВАС НЕ БЫЛО'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.byType(EvMiniButton), findsNWidgets(4));
      await tester.tap(find.text('Посмотреть'));
      await tester.tap(find.text('Всё понятно'));
      await tester.tap(find.bySemanticsLabel('Свернуть'));
      expect(taps, ['Посмотреть']);
      expect(done, 2);
    });
  });

  group('в окне', () {
    testWidgets('«Всё понятно» сворачивает дайджест в плашку, она его вернёт', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _returned(tester);
      expect(find.byType(EvDigest), findsOneWidget);
      expect(find.text('ВЫ ОСТАНОВИЛИСЬ 41 МИНУТУ НАЗАД'), findsOneWidget);
      expect(find.byType(EvSavePointCard), findsOneWidget);
      expect(_news, findsNothing);

      await tester.tap(find.text('Всё понятно'));
      await _settle(tester);
      expect(find.byType(EvDigest), findsNothing);
      expect(find.text('Пока вас не было · 5'), findsOneWidget);

      await tester.tap(find.text('Пока вас не было · 5'));
      await _settle(tester);
      expect(find.byType(EvDigest), findsOneWidget);
      expect(_news, findsNothing);
    });

    testWidgets('действия ведут туда, куда обещают', (tester) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _returned(tester);

      await tester.tap(find.text('Показать'));
      await _settle(tester);
      expect(
        tester.widget<EvGameSheet>(find.byType(EvGameSheet)).game.title,
        'Грозовой Фронт',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      // Карточка поверх — дайджест остался.
      expect(find.byType(EvDigest), findsOneWidget);

      await tester.tap(find.text('Посмотреть'));
      await _settle(tester);
      expect(find.byType(FriendProfilePage), findsOneWidget);
      expect(find.text('Пока вас не было · 5'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await _settle(tester);
      await tester.tap(find.text('Пока вас не было · 5'));
      await _settle(tester);
      await tester.tap(find.text('К загрузкам'));
      await _settle(tester);
      expect(find.byType(DownloadsPage), findsOneWidget);
    });

    testWidgets('«Другое» у точки сохранения ведёт в сохранения', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _returned(tester);
      await tester.tap(find.text('Другое'));
      await _settle(tester);
      expect(find.byType(SavesPage), findsOneWidget);
    });

    testWidgets('уход из второго запуска убирает и дайджест, и плашку', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _returned(tester);
      await tester.tap(find.text('Всё понятно'));
      await _settle(tester);
      await _dev(tester, 'Обычное состояние');
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await _settle(tester);
      expect(find.byType(EvDigest), findsNothing);
      expect(_news, findsNothing);
    });

    testWidgets('во втором запуске «Терминал» видит обновлённую версию', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _returned(tester);
      await tester.tap(find.bySemanticsLabel('Терминал'));
      await _settle(tester);
      expect(find.text(sampleUpdate.bareVersion), findsOneWidget);
      expect(find.text(sampleHero.bareVersion), findsNothing);
    });

    testWidgets('широкое окно: дайджест первым в правой колонке', (
      tester,
    ) async {
      _window(tester, 1900, 1100);
      await _app(tester);
      await _returned(tester);
      final digest = tester.getRect(find.byType(EvDigest));
      final hero = tester.getRect(find.text('ВЫ ОСТАНОВИЛИСЬ 41 МИНУТУ НАЗАД'));
      expect(digest.left, greaterThan(hero.right));
      expect(tester.takeException(), isNull);
    });

    testWidgets('сценарий «Возвращение»: четыре шага до ритуала', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _dev(tester, 'Возвращение');
      expect(find.text('1/4'), findsOneWidget);
      expect(find.byType(EvDigest), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      expect(find.byType(DownloadsPage), findsOneWidget);
      expect(find.text('Пока вас не было · 5'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      expect(find.byType(EvDigest), findsNothing);
      expect(find.text('ВЫ ОСТАНОВИЛИСЬ 41 МИНУТУ НАЗАД'), findsOneWidget);
      expect(find.byType(EvLaunchRitual), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      expect(find.byType(EvLaunchRitual), findsOneWidget);
    });

    testWidgets(
      'выход из «Возвращения» — обычный герой, первый запуск его сменяет',
      (tester) async {
        _window(tester, 1440, 900);
        await _app(tester);
        await _dev(tester, 'Возвращение');
        await tester.tap(find.bySemanticsLabel('Выйти из сценария'));
        await _settle(tester);
        expect(find.byType(EvFlowBar), findsNothing);
        expect(find.text('ВЫ ОСТАНОВИЛИСЬ 41 МИНУТУ НАЗАД'), findsNothing);

        await _dev(tester, 'Возвращение');
        await _dev(tester, 'Первый запуск');
        expect(find.text('1/8'), findsOneWidget);
        expect(find.byType(EvDigest), findsNothing);
        expect(_news, findsNothing);

        // Первый запуск сменил возвращение, а не лёг поверх: после выхода
        // из него полоса не всплывает с шагом «Возвращения».
        await tester.tap(find.bySemanticsLabel('Выйти из сценария'));
        await _settle(tester);
        expect(find.byType(EvFlowBar), findsNothing);
      },
    );
  });
}

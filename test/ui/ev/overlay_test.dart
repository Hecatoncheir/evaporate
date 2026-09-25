import 'package:evaporate/ui/ev/data/game_facts.dart';
import 'package:evaporate/ui/ev/data/sample_data.dart';
import 'package:evaporate/ui/ev/data/sample_downloads.dart';
import 'package:evaporate/ui/ev/data/sample_friends.dart';
import 'package:evaporate/ui/ev/data/sample_profile.dart';
import 'package:evaporate/ui/ev/data/sample_session.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/downloads/download_data.dart';
import 'package:evaporate/ui/ev/downloads/rate_graph.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/friends/friends_data.dart';
import 'package:evaporate/ui/ev/library/hero_state.dart';
import 'package:evaporate/ui/ev/overlay/ev_overlay.dart';
import 'package:evaporate/ui/ev/overlay/overlay_data.dart';
import 'package:evaporate/ui/ev/screens/downloads_page.dart';
import 'package:evaporate/ui/ev/sheet/ev_game_sheet.dart';
import 'package:evaporate/ui/ev/util/units.dart';
import 'package:evaporate/ui/ev/widgets/ev_game_card.dart';
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

/// Выбрать строку в «Настройках → Разработка».
Future<void> _dev(WidgetTester tester, String name) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
  await _settle(tester);
  await tester.ensureVisible(find.text(name));
  await _settle(tester);
  await tester.tap(find.text(name));
  await _settle(tester);
}

/// Игра запущена, открыта библиотека.
Future<void> _running(WidgetTester tester) async {
  await _dev(tester, 'Игра запущена');
  await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
  await _settle(tester);
}

Finder get _overlay => find.byType(EvOverlay);

void main() {
  final session = sampleSession;

  group('данные', () {
    test('сессия одна: герой пишет её время, место и кадры', () {
      final c = sampleHeroStates[EvHeroState.running]!;
      expect(session.clock, '01:04:12');
      expect(session.length, '1 ч 04 мин');
      expect(c.runningFor, session.clock);
      expect(c.eyebrow, contains(session.length));
      expect(c.blurb, startsWith('${session.chapter}, ${session.place}'));
      expect(c.chips.map((c) => c.$1), contains('${session.fps} к/с'));
      expect(c.chips.map((c) => c.$1), contains('PID ${session.pid}'));
    });

    test('кадры начинаются с числа героя и бродят в своих пределах', () {
      final frames = EvFrameSeries(session.fps);
      expect(frames.history, hasLength(64));
      expect(frames.fps, session.fps);
      expect(frames.frame, '6.9 мс');
      for (var i = 0; i < 400; i++) {
        frames.advance();
        expect(frames.fps, inInclusiveRange(102, 162));
      }
      expect(frames.history, hasLength(64));
    });

    test('достижение сессии — полученное, и профиль видит его первым', () {
      final unlocked = EvGameFacts.of(session.game).unlocked;
      expect(session.earned.index, lessThan(unlocked));
      expect(sampleProfile.recent.first, same(session.earned));
      // «Собиратель» ближе всего — значит, ещё не получен.
      expect(EvGameFacts.collector, greaterThanOrEqualTo(unlocked));
      final (name, rule) = EvGameFacts.achievements[EvGameFacts.collector];
      expect(name, 'Собиратель');
      expect(rule, contains('${EvGameFacts.relicsTotal}'));
    });

    test('пока идёт игра, очередь ужата до предела — каждой её доля', () {
      final full = sampleDownloadsFor(EvDownloadsState.active);
      final capped = full.capped(downKb: 1000, upKb: 1000);
      expect(capped.downKb, closeTo(1000, 1));
      expect(capped.upKb, closeTo(1000, 1));
      final orbita = capped.torrents.first;
      expect(orbita.downKb, (592 * 1000 / full.downKb).round());
      expect(
        orbita.eta,
        formatEta(orbita.parts.total - orbita.parts.received, orbita.downKb!),
      );
      // Под пределом ничего не меняется.
      expect(full.capped(downKb: 5000, upKb: 5000), same(full));
    });

    test('друг в той же главе — «та же глава», остальные — как в списке', () {
      expect(session.lineOf(samplePeople[0]), 'та же глава');
      expect(session.lineOf(samplePeople[1]), 'Красный Меридиан');
      expect(session.lineOf(samplePeople[3]), 'в сети');
    });
  });

  group('в окне', () {
    testWidgets('«Оверлей» в герое: сессия, достижения, друзья и фоном', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _running(tester);
      await tester.tap(find.text('Оверлей'));
      await _settle(tester);
      expect(_overlay, findsOneWidget);
      expect(find.text('Сессия 1 ч 04 мин'), findsOneWidget);
      expect(find.text('Глава 5 · Кузня Сумерек'), findsOneWidget);
      expect(find.text('Друзья · 6 в сети'), findsOneWidget);
      expect(find.text('та же глава'), findsOneWidget);
      expect(find.text('orbita-7 · 365 КБ/с'), findsOneWidget);
      expect(find.text('Без единой царапины'), findsOneWidget);
      expect(find.text('Собиратель · 37 из 60'), findsOneWidget);
      expect(find.text('Осталось 23 реликвии'), findsOneWidget);
      expect(
        find.descendant(
          of: _overlay,
          matching: find.textContaining('до 1 МБ/с'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Esc, Shift+Tab и «Вернуться в игру» закрывают — игра идёт', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _running(tester);
      Future<void> open() async {
        await tester.tap(find.text('Оверлей'));
        await _settle(tester);
        expect(_overlay, findsOneWidget);
      }

      await open();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(_overlay, findsNothing);

      await open();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await _settle(tester);
      expect(_overlay, findsNothing);

      await open();
      await tester.tap(find.text('Вернуться в игру'));
      await _settle(tester);
      expect(_overlay, findsNothing);
      expect(find.text('Игра запущена'), findsOneWidget);
    });

    testWidgets('«Завершить игру» закрывает оверлей и игру', (tester) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _running(tester);
      await tester.tap(find.text('Оверлей'));
      await _settle(tester);
      await tester.tap(find.text('Завершить игру'));
      await _settle(tester);
      expect(_overlay, findsNothing);
      expect(find.text('Игра запущена'), findsNothing);
      expect(find.text('Движок готов'), findsOneWidget);
    });

    testWidgets('«Оверлей» в карточке игры сменяет карточку', (tester) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _running(tester);
      // У идущей игры «Подробнее» нет — карточка открывается с полки.
      final card = find.byWidgetPredicate(
        (w) => w is EvGameCard && w.title == sampleHero.title,
      );
      await tester.ensureVisible(card);
      await _settle(tester);
      await tester.tap(card);
      await _settle(tester);
      expect(find.byType(EvGameSheet), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(EvGameSheet),
          matching: find.text('Оверлей'),
        ),
      );
      await _settle(tester);
      expect(find.byType(EvGameSheet), findsNothing);
      expect(_overlay, findsOneWidget);
    });

    testWidgets('из «Разработки»: игра запускается, оверлей открыт', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _dev(tester, 'Оверлей в игре');
      expect(_overlay, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(_overlay, findsNothing);
      // Приём ужат — значит, игра и правда идёт.
      expect(find.text('1.0 МБ/с'), findsOneWidget);
    });

    testWidgets('в игре верхняя полоса и загрузки говорят про ужатый приём', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _running(tester);
      expect(find.text('1.0 МБ/с'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await _settle(tester);
      expect(find.byType(DownloadsPage), findsOneWidget);
      expect(find.textContaining('365 КБ/с'), findsWidgets);
    });

    testWidgets('в игре правая колонка и «Друзья» читают ту же очередь', (
      tester,
    ) async {
      _window(tester, 1900, 1100);
      await _app(tester);
      await _running(tester);
      // Правая колонка: та же доля «Орбиты», что в загрузках и в оверлее.
      expect(find.text('41 % · 365 КБ/с'), findsOneWidget);
      // Друзья отдают свою долю от ужатого приёма, а не прежние 1.34 МБ/с.
      final queue = sampleDownloadsFor(EvDownloadsState.active)
          .capped(downKb: 1000, upKb: 1000);
      final friends = sampleFriendsFor(EvFriendsState.normal, queue: queue);
      expect(friends.fromFriendsKb, lessThanOrEqualTo(queue.downKb));
      for (final s in friends.seeders) {
        final t = queue.torrents.firstWhere((t) => t.game == s.game);
        expect(s.ofKb, t.downKb);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await _settle(tester);
      // Крупное число «от друзей» — в МБ/с, как в разделе.
      expect(
        find.textContaining(
          (friends.fromFriendsKb / 1000).toStringAsFixed(2),
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('кадры идут по часам, а «меньше движения» их останавливает', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _dev(tester, 'Оверлей в игре');
      List<double> series() =>
          tester.widget<EvRateGraph>(find.byType(EvRateGraph)).series;
      final before = series();
      await tester.pump(const Duration(seconds: 3));
      expect(series(), isNot(before));

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      final still = series();
      await tester.pump(const Duration(seconds: 3));
      expect(series(), still);

      // Движение вернули — кадры идут сразу, а не догоняют простой.
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(series(), isNot(still));
    });

    testWidgets('минимальное окно: три карточки в ряд, ничего не режется', (
      tester,
    ) async {
      _window(tester, 1280, 720);
      await _app(tester);
      await _dev(tester, 'Оверлей в игре');
      expect(tester.takeException(), isNull);
      final tops = {
        for (final label in [
          'ПРОИЗВОДИТЕЛЬНОСТЬ',
          'БЫСТРЫЕ ДЕЙСТВИЯ',
          'ДРУЗЬЯ · 6 В СЕТИ',
        ])
          tester.getTopLeft(find.text(label)).dy,
      };
      expect(tops, hasLength(1));
      expect(
        tester.getBottomLeft(find.text('Завершить игру')).dy,
        lessThanOrEqualTo(720),
      );
    });
  });
}

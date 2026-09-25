import 'package:evaporate/ui/ev/data/sample_data.dart';
import 'package:evaporate/ui/ev/data/sample_downloads.dart';
import 'package:evaporate/ui/ev/data/sample_friends.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/downloads/download_data.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/launch/ev_launch_ritual.dart';
import 'package:evaporate/ui/ev/library/hero_cta.dart';
import 'package:evaporate/ui/ev/library/hero_state.dart';
import 'package:evaporate/ui/ev/screens/library_page.dart';
import 'package:evaporate/ui/ev/sheet/ev_game_sheet.dart';
import 'package:evaporate/ui/ev/widgets/ev_game_card.dart';
import 'package:evaporate/ui/ev/widgets/ev_play_button.dart';
import 'package:evaporate/ui/ev/widgets/ev_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void _window(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Ядро «Играть» дышит бесконечно, а точка «идёт игра» пульсирует:
/// вместо pumpAndSettle — секунда.
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

/// Экран библиотеки в заданном состоянии, без каркаса.
Future<void> _library(
  WidgetTester tester,
  EvHeroState state, {
  VoidCallback? onInstall,
  VoidCallback? onQuit,
}) async {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildEvTheme(),
      home: EvEffectsScope(
        effects: effects,
        child: Scaffold(
          body: LibraryPage(
            state: state,
            games: sampleLibrary,
            hero: sampleHero,
            sessions: sampleSessions,
            friends: sampleFriends,
            friendsOnline: sampleFriendsOnline,
            downloads: sampleDownloadsFor(EvDownloadsState.active),
            onInstall: onInstall,
            onQuit: onQuit,
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// Выбрать состояние в «Настройках → Разработка».
Future<void> _pick(WidgetTester tester, String name) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
  await _settle(tester);
  await tester.ensureVisible(find.text(name));
  await _settle(tester);
  await tester.tap(find.text(name));
  await _settle(tester);
  await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
  await _settle(tester);
}

void main() {
  group('состояния героя', () {
    testWidgets('у каждого своя полоса действий и своя подпись', (
      tester,
    ) async {
      _window(tester, 1440, 900);

      await _library(tester, EvHeroState.ready);
      expect(find.text('ПРОДОЛЖИТЬ · СЫГРАНО 284 Ч 10 МИН'), findsOneWidget);
      expect(find.byType(EvPlayButton), findsOneWidget);
      expect(find.text('Подробнее'), findsOneWidget);
      expect(find.byType(EvCtaNote), findsNothing);

      await _library(tester, EvHeroState.notInstalled);
      expect(find.text('В БИБЛИОТЕКЕ · НА ДИСКЕ НЕТ'), findsOneWidget);
      expect(find.text('Установить'), findsOneWidget);
      expect(find.text('68.4 ГБ'), findsWidgets);
      expect(find.text('Указать папку вручную'), findsOneWidget);
      expect(
        find.textContaining('после установки останется 146 ГБ'),
        findsOneWidget,
      );

      await _library(tester, EvHeroState.update);
      expect(find.text('УСТАНОВЛЕНА · ДОСТУПНО ОБНОВЛЕНИЕ'), findsOneWidget);
      expect(find.text('Обновить и играть'), findsOneWidget);
      expect(find.text('Играть без обновления'), findsOneWidget);
      expect(
        find.text('Со старой версией не работает совместное прохождение'),
        findsOneWidget,
      );

      await _library(tester, EvHeroState.installing);
      expect(find.text('УСТАНОВКА · ОСТАЛОСЬ 12 МИН'), findsOneWidget);
      expect(find.text('Распаковка и проверка'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EvInstallBox),
          matching: find.text('41 %'),
        ),
        findsOneWidget,
      );
      expect(find.text('Пауза'), findsOneWidget);
      expect(find.text('Отменить'), findsOneWidget);
      expect(find.byType(EvPlayButton), findsNothing, reason: 'кнопки нет');

      await _library(tester, EvHeroState.running);
      expect(
        find.text('ИДЁТ ИГРА · ЗАПУЩЕНА 1 Ч 04 МИН НАЗАД'),
        findsOneWidget,
      );
      expect(find.byType(EvRunningPill), findsOneWidget);
      expect(find.text('01:04:12'), findsOneWidget);
      expect(find.text('Оверлей'), findsOneWidget);
      expect(find.text('Завершить'), findsOneWidget);
      expect(find.byType(EvPlayButton), findsNothing);

      await _library(tester, EvHeroState.offline);
      expect(find.text('НЕТ СЕТИ · ИГРАТЬ МОЖНО'), findsOneWidget);
      expect(find.byType(EvPlayButton), findsOneWidget, reason: 'играть можно');
      expect(find.textContaining('Загрузки на паузе'), findsOneWidget);
    });

    testWidgets('на низком окне описание уступает место полосе', (
      tester,
    ) async {
      _window(tester, 1280, 720);
      final blurb = sampleHeroStates[EvHeroState.installing]!.blurb;

      await _library(tester, EvHeroState.ready);
      expect(
        find.text(sampleHeroStates[EvHeroState.ready]!.blurb),
        findsOneWidget,
      );

      await _library(tester, EvHeroState.installing);
      expect(find.text(blurb), findsNothing);
      expect(find.text('Распаковка и проверка'), findsOneWidget);
    });

    testWidgets('«Установить» ведёт к установке, «Завершить» — к покою', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      var installed = 0, quit = 0;
      await _library(
        tester,
        EvHeroState.notInstalled,
        onInstall: () => installed++,
      );
      await tester.tap(find.text('Установить'));
      await _settle(tester);
      expect(installed, 1);

      await _library(tester, EvHeroState.running, onQuit: () => quit++);
      await tester.tap(find.text('Завершить'));
      await _settle(tester);
      expect(quit, 1);
    });
  });

  group('состояние окна', () {
    testWidgets('«Разработка» переключает героя и плашки', (tester) async {
      _window(tester, 1440, 900);
      await _app(tester);
      expect(find.widgetWithText(EvPill, 'Движок готов'), findsOneWidget);

      await _pick(tester, 'Игра запущена');
      expect(find.byType(EvRunningPill), findsOneWidget);
      expect(find.widgetWithText(EvPill, 'Игра запущена'), findsOneWidget);
      expect(find.widgetWithText(EvPill, '1.0 МБ/с'), findsOneWidget);

      await _pick(tester, 'Нет сети');
      expect(find.widgetWithText(EvPill, 'Нет сети'), findsOneWidget);
      expect(find.widgetWithText(EvPill, 'Движок на паузе'), findsOneWidget);
      expect(find.byType(EvPlayButton), findsOneWidget, reason: 'играть можно');

      await _pick(tester, 'Обычное состояние');
      expect(find.widgetWithText(EvPill, 'Движок готов'), findsOneWidget);
      expect(find.byType(EvRunningPill), findsNothing);
    });

    testWidgets('карточка игры говорит то же, что герой', (tester) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _pick(tester, 'Идёт установка');

      // «Подробнее» в этом состоянии нет — карточка открывается с полки
      await tester.tap(find.text('Глубина 9').first);
      await _settle(tester);
      expect(
        find.descendant(
          of: find.byType(EvGameSheet),
          matching: find.text('Играть'),
        ),
        findsOneWidget,
        reason: 'у другой игры своё состояние',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);

      final card = find.byWidgetPredicate(
        (w) => w is EvGameCard && w.title == sampleHero.title,
      );
      await tester.ensureVisible(card);
      await _settle(tester);
      await tester.tap(card);
      await _settle(tester);
      expect(find.byType(EvGameSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EvGameSheet),
          matching: find.text('УСТАНОВКА · ОСТАЛОСЬ 12 МИН'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EvGameSheet),
          matching: find.byType(EvRunningPill),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EvGameSheet),
          matching: find.text(
            '28.0 из 68.4 ГБ · осталось 12 мин',
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('«Играть без обновления» запускает ритуал', (tester) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _pick(tester, 'Есть обновление');

      await tester.tap(find.text('Играть без обновления'));
      await tester.pump();
      expect(find.byType(EvLaunchRitual), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
    });
  });
}

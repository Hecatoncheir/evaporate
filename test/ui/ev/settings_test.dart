import 'package:evaporate/ui/ev/data/sample_data.dart';
import 'package:evaporate/ui/ev/data/sample_downloads.dart';
import 'package:evaporate/ui/ev/data/sample_friends.dart';
import 'package:evaporate/ui/ev/data/sample_profile.dart';
import 'package:evaporate/ui/ev/data/sample_saves.dart';
import 'package:evaporate/ui/ev/design/appearance.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/downloads/download_data.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/friends/friends_data.dart';
import 'package:evaporate/ui/ev/library/hero_state.dart';
import 'package:evaporate/ui/ev/saves/saves_data.dart';
import 'package:evaporate/ui/ev/screens/profile_page.dart';
import 'package:evaporate/ui/ev/screens/settings_page.dart';
import 'package:evaporate/ui/ev/settings/ev_settings_widgets.dart';
import 'package:evaporate/ui/ev/settings/settings_catalog.dart';
import 'package:evaporate/ui/ev/settings/settings_data.dart';
import 'package:evaporate/ui/ev/settings/settings_search.dart';
import 'package:evaporate/ui/ev/shell/ev_hints_bar.dart';
import 'package:evaporate/ui/ev/shell/ev_top_bar.dart';
import 'package:evaporate/ui/ev/sound/ev_sound.dart';
import 'package:evaporate/ui/ev/widgets/ev_controls.dart';
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

List<EvSettingSection> _catalog({EvEffects? effects}) {
  final appearance = EvAppearance();
  addTearDown(appearance.dispose);
  final settings = EvSettings();
  addTearDown(settings.dispose);
  return evSettingsCatalog((
    appearance: appearance,
    effects: effects,
    sound: EvSound(out: const EvSilentOut()),
    settings: settings,
    drives: sampleDrives,
    ratio: '2,41',
    cloud: (4.1, 20),
    hour: 3,
  ));
}

/// Страница в своём окне: свои модели, приборы и прокрутка.
Future<(EvSettings, EvEffects)> _page(WidgetTester tester) async {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  final appearance = EvAppearance();
  addTearDown(appearance.dispose);
  final settings = EvSettings();
  addTearDown(settings.dispose);
  await tester.pumpWidget(
    EvAppearanceScope(
      appearance: appearance,
      child: MaterialApp(
        theme: buildEvTheme(),
        home: EvEffectsScope(
          effects: effects,
          child: Scaffold(
            body: SettingsPage(
              settings: settings,
              drives: sampleDrives,
              ratio: '2,41',
              cloud: (4.1, 20),
              hour: 3,
              state: EvHeroState.ready,
              onState: (_) {},
              downloads: EvDownloadsState.active,
              onDownloads: (_) {},
              saves: EvSavesState.synced,
              onSaves: (_) {},
              friendsState: EvFriendsState.normal,
              onFriends: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return (settings, effects);
}

void main() {
  group('поиск', () {
    test(
      'основа слова: «скорость» находит «скорости», «порт» — только порт',
      () {
        expect(EvSettingsMatch.stem('скорость'), 'скорост');
        expect(EvSettingsMatch.stem('облако'), 'облак');
        expect(EvSettingsMatch.stem('порт'), 'порт');
        expect(EvSettingsMatch.stem('ритуал'), 'ритуал');
      },
    );

    test('каждое слово из подсказки пустого поиска что-то находит', () {
      final sections = _catalog(effects: EvEffects.still());
      for (final word in ['скорость', 'порт', 'облако', 'ритуал']) {
        expect(EvSettingsMatch.of(sections, word).empty, isFalse, reason: word);
      }
    });

    test('заголовок панели раскрывает её целиком, строка — только себя', () {
      final sections = _catalog();
      final net = sections.firstWhere((s) => s.id == 'net');
      final panel = net.panels.single;

      final speed = EvSettingsMatch.of(sections, 'скорость');
      expect(speed.rows(panel), hasLength(panel.rows.length));
      expect(
        [
          for (final s in sections)
            if (speed.section(s)) s.id,
        ],
        ['net'],
      );

      final port = EvSettingsMatch.of(sections, 'порт');
      expect([for (final r in port.rows(panel)) r.title], ['Порт входящих']);
      expect(port.highlight('Порт входящих'), (0, 4));
      expect(port.highlight('Без совпадения'), isNull);
    });

    test('клавиши ищутся так же, как настройки', () {
      final sections = _catalog();
      final keys = sections.firstWhere((s) => s.id == 'keys');
      final m = EvSettingsMatch.of(sections, 'скриншот');
      expect(
        [for (final r in m.rows(keys.panels.single)) r.title],
        ['Скриншот'],
      );
      expect(EvSettingsMatch.of(sections, 'F12').section(keys), isTrue);
    });

    test('ничего не нашлось — выдача пустая', () {
      expect(EvSettingsMatch.of(_catalog(), 'щщщ').empty, isTrue);
      expect(EvSettingsMatch.of(_catalog(), '').empty, isFalse);
    });
  });

  group('числа из других разделов', () {
    test('строка подсказок — те же клавиши, что в таблице', () {
      expect(evHints, [
        ('↑↓←→', 'Навигация'),
        ('Enter', 'Выбрать'),
        ('Esc', 'Назад'),
        ('Ctrl+Tab', 'Разделы'),
        ('/', 'Поиск'),
      ]);
      for (final (keys, _) in evHints) {
        expect(
          evKeyBindings.any(
            (k) => k.keys.join(keys.contains('+') ? '+' : '') == keys,
          ),
          isTrue,
          reason: keys,
        );
      }
    });

    test('папки делят библиотеку, игры укладываются в занятое', () {
      final all = [for (final d in sampleDrives) ...d.games];
      expect(all.toSet(), sampleLibrary.toSet());
      expect(all, hasLength(sampleLibrary.length));
      final (d, e) = (sampleDrives[0], sampleDrives[1]);
      expect((d.games.length, d.gamesGb.round()), (8, 258));
      expect((e.games.length, e.gamesGb.round()), (4, 79));
      for (final drive in sampleDrives) {
        expect(
          drive.gamesGb,
          lessThanOrEqualTo(drive.capacityGb - drive.freeGb),
          reason: drive.path,
        );
      }
      expect((d.used * 100).round(), 57);
      expect((e.used * 100).round(), 88);
    });

    test('свободное место на D — то же, что обещает установка в герое', () {
      final note = sampleHeroStates[EvHeroState.notInstalled]!.note!.text;
      final free = sampleDrives.first.freeGb.round();
      expect(note, contains(sampleDrives.first.path));
      expect(note, contains('свободно $free ГБ'));
    });

    test('рейтинг и облако — из профиля и сохранений', () {
      expect(formatRatio(sampleProfile.ratio), '2,41');
      final saves = sampleSavesFor(EvSavesState.synced);
      expect((saves.usedGb, saves.quotaGb), (4.1, 20));
    });

    test(
      'предел загрузок уводит лишние раздачи в очередь, друзья по ним молчат',
      () {
        final full = sampleDownloadsFor(EvDownloadsState.active);
        expect(full.withSlots(3).active, full.active);
        final one = full.withSlots(1);
        expect(one.slots, 1);
        expect(one.active, 1);
        expect(one.queue.length, full.queue.length + full.active - 1);
        expect(one.queue.first.game, full.torrents[1].game);

        final friends = sampleFriendsFor(EvFriendsState.normal, queue: one);
        expect(
          friends.seeders.every((s) => s.game == one.torrents.first.game),
          isTrue,
        );
        expect(friends.shareOf(one.downKb), lessThanOrEqualTo(1));
      },
    );
  });

  group('страница', () {
    testWidgets('десять разделов и «Разработка», колонка слева', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _page(tester);
      final nav = tester.widgetList<EvSettingsNavItem>(
        find.byType(EvSettingsNavItem),
      );
      expect(
        [for (final n in nav) n.label],
        [
          'Облик',
          'Эффекты',
          'Звук',
          'Библиотека',
          'Загрузки',
          'Раздача',
          'Сохранения',
          'Запуск',
          'Клавиши',
          'О программе',
          'Разработка',
        ],
      );
      expect(nav.first.active, isTrue);
      expect(find.text('Evaporate 3.1.0\nдвижок раздач 2.8.4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('пункт колонки ведёт к разделу и подсвечивается', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _page(tester);
      final left = tester.getTopLeft(find.byType(EvSettingsNavItem).first);
      await tester.tap(find.widgetWithText(EvSettingsNavItem, 'Клавиши'));
      await _settle(tester);
      // Раздел наверху, колонка осталась на месте.
      final header = tester.getTopLeft(
        find.widgetWithText(EvSettingsHeader, 'Клавиши'),
      );
      expect(header.dy, lessThan(120));
      expect(tester.getTopLeft(find.byType(EvSettingsNavItem).first), left);
      final active = tester
          .widgetList<EvSettingsNavItem>(find.byType(EvSettingsNavItem))
          .where((n) => n.active);
      expect([for (final n in active) n.label], ['Клавиши']);
    });

    testWidgets('прокрутка сама переносит подсветку', (tester) async {
      _window(tester, 1440, 900);
      await _page(tester);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -1400),
      );
      await _settle(tester);
      final active = tester
          .widgetList<EvSettingsNavItem>(find.byType(EvSettingsNavItem))
          .singleWhere((n) => n.active);
      expect(active.label, isNot('Облик'));
    });

    testWidgets('поиск прячет лишнее, подсвечивает, Esc очищает', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _page(tester);
      await tester.enterText(find.byType(TextField), 'порт');
      await _settle(tester);
      expect(find.byType(EvSettingsNavItem), findsOneWidget);
      final row = tester.widget<EvOption>(find.byType(EvOption));
      expect((row.title, row.highlight), ('Порт входящих', (0, 4)));

      await tester.enterText(find.byType(TextField), 'щщщ');
      await _settle(tester);
      expect(find.text('Ничего не нашлось'), findsOneWidget);
      expect(find.byType(EvSettingsNavItem), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(find.byType(EvSettingsNavItem), findsNWidgets(11));
      expect(find.text('Ничего не нашлось'), findsNothing);
    });

    testWidgets('расписание: нажатие меняет час, протяжка красит подряд', (
      tester,
    ) async {
      _window(tester, 1440, 1800);
      final (settings, _) = await _page(tester);
      await tester.tap(find.widgetWithText(EvSettingsNavItem, 'Загрузки'));
      await _settle(tester);
      final rect = tester.getRect(find.byType(EvSchedule));
      final step = (rect.width + EvSchedule.gap) / 24;
      Offset hour(int h) => Offset(rect.left + step * (h + .5), rect.center.dy);

      expect(settings.schedule.take(8), everyElement(isTrue));
      await tester.tapAt(hour(12));
      await tester.pump();
      expect(settings.schedule[12], isTrue);

      // Протяжка от серого часа красит всё под собой янтарём.
      final drag = await tester.startGesture(hour(14));
      for (var h = 15; h <= 18; h++) {
        await drag.moveTo(hour(h));
        await tester.pump();
      }
      await drag.up();
      expect(settings.schedule.sublist(14, 19), everyElement(isTrue));
      expect(settings.schedule[19], isFalse);
      expect(find.text('сейчас 03:00'), findsOneWidget);
    });

    testWidgets('«Сбросить» возвращает эффекты как при первом запуске', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      final (_, effects) = await _page(tester);
      expect(effects.sparks, isFalse);
      await tester.tap(find.text('Сбросить'));
      await tester.pump();
      expect(effects.sparks, isTrue);
      expect(effects.livingBackground, isTrue);
      expect(effects.quality, EvEffectsQuality.full);
    });

    testWidgets('темы карточками меняют облик окна', (tester) async {
      _window(tester, 1440, 900);
      await _page(tester);
      await tester.tap(find.text('NEBULA'));
      await tester.pump();
      final appearance = EvAppearanceScope.of(
        tester.element(find.byType(SettingsPage)),
      );
      expect(appearance.skin, EvSkin.nebula);
    });

    testWidgets('узкие окна: колонка встаёт сверху, ничего не лезет', (
      tester,
    ) async {
      for (final (w, h) in [(1280.0, 720.0), (820.0, 900.0)]) {
        _window(tester, w, h);
        await _page(tester);
        final nav = tester.getRect(find.byType(EvSettingsNavItem).first);
        final head = tester.getRect(find.byType(EvSettingsHeader).first);
        if (w < SettingsPage.narrow) {
          expect(
            nav.bottom,
            lessThan(head.top),
            reason: 'колонка над разделами',
          );
        } else {
          expect(nav.right, lessThan(head.left), reason: 'колонка слева');
        }
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -6000),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: '$w × $h');
      }
    });
  });

  group('в окне', () {
    testWidgets('одна загрузка в настройках — одна в «Загрузках»', (
      tester,
    ) async {
      _window(tester, 1440, 1800);
      final effects = EvEffects.still();
      addTearDown(effects.dispose);
      await tester.pumpWidget(EvaporateApp(effects: effects));
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await _settle(tester);
      await tester.tap(find.widgetWithText(EvSettingsNavItem, 'Загрузки'));
      await _settle(tester);
      await tester.tap(find.text('1').first);
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await _settle(tester);
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('строка подсказок внизу окна — из той же таблицы', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      final effects = EvEffects.still();
      addTearDown(effects.dispose);
      await tester.pumpWidget(EvaporateApp(effects: effects));
      await _settle(tester);
      final keys = tester.widgetList<EvKey>(
        find.descendant(
          of: find.byType(EvHintsBar),
          matching: find.byType(EvKey),
        ),
      );
      expect(
        [for (final k in keys) k.label],
        [for (final (k, _) in evHints) k],
      );
    });
  });
}

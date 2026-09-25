import 'package:evaporate/ui/ev/data/game_facts.dart';
import 'package:evaporate/ui/ev/data/sample_data.dart';
import 'package:evaporate/ui/ev/data/sample_friends.dart';
import 'package:evaporate/ui/ev/data/sample_profile.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/friends/friends_data.dart';
import 'package:evaporate/ui/ev/profile/ev_play_year.dart';
import 'package:evaporate/ui/ev/profile/ev_profile_head.dart';
import 'package:evaporate/ui/ev/profile/ev_profile_rows.dart';
import 'package:evaporate/ui/ev/profile/profile_data.dart';
import 'package:evaporate/ui/ev/screens/profile_page.dart';
import 'package:evaporate/ui/ev/util/plural.dart';
import 'package:evaporate/ui/ev/util/units.dart';
import 'package:evaporate/ui/ev/widgets/ev_achievement.dart';
import 'package:evaporate/ui/ev/widgets/ev_controls.dart';
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

Future<void> _page(
  WidgetTester tester, {
  Set<EvShare>? shares,
  void Function(EvShare, bool)? onShare,
}) async {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildEvTheme(),
      home: EvEffectsScope(
        effects: effects,
        child: Scaffold(
          body: ProfilePage(
            profile: sampleProfile,
            shares: shares ?? EvShare.values.toSet(),
            onShare: onShare ?? (_, _) {},
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _app(WidgetTester tester) async {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  await tester.pumpWidget(EvaporateApp(effects: effects));
  await _settle(tester);
}

/// Год из списка уровней по порядку дней; остальное — нули.
EvPlayYear _year(List<int> head) => EvPlayYear([
  ...head,
  for (var i = head.length; i < EvPlayYear.weeks * 7; i++) 0,
]);

String _text(Widget w) => switch (w) {
  Text(:final data?) => data,
  Text(:final textSpan?) => textSpan.toPlainText(),
  _ => '',
};

void main() {
  final p = sampleProfile;

  group('год игры', () {
    test('числа под картой считаются из той же сетки', () {
      final y = p.year;
      expect(y.levels, hasLength(52 * 7));
      expect(y.days, y.levels.where((l) => l > 0).length);
      expect(y.hours, y.levels.fold(0, (s, l) => s + l));
      // Зерно прототипа даёт те же числа, что его страница.
      expect((y.days, y.hours, y.longestStreak), (193, 392, 13));
    });

    test('серия переходит через воскресенье и рвётся на пустом дне', () {
      // Два дня в конце первой недели и три в начале второй — пять подряд.
      final y = _year([0, 0, 0, 0, 0, 1, 2, 3, 1, 4, 0, 1, 1]);
      expect(y.longestStreak, 5);
      expect(y.days, 7);
      expect(y.hours, 13);
      expect(_year([]).longestStreak, 0);
    });

    test('числительные склоняются', () {
      expect(ruCount(193, 'день', 'дня', 'дней'), '193 дня');
      expect(ruCount(392, 'час', 'часа', 'часов'), '392 часа');
      expect(ruCount(11, 'день', 'дня', 'дней'), '11 дней');
      expect(ruCount(21, 'день', 'дня', 'дней'), '21 день');
      expect(ruCount(112, 'друг', 'друга', 'друзей'), '112 друзей');
    });

    test('ячейки квадратные, во всю ширину, но не крупнее 22 px', () {
      expect(EvPlayYearMap.cellFor(52 * 20 + 51 * 3), 20);
      expect(EvPlayYearMap.cellFor(3000), EvPlayYearMap.maxCell);
      expect(EvPlayYearMap.heightFor(3000), 22 * 7 + 3 * 6);
    });
  });

  group('сводка', () {
    test('часы: год плюс прошлое, игры и устройства в них укладываются', () {
      expect(p.hours, p.year.hours + p.hoursBefore);
      expect(p.hours, 1284);
      final library = sampleLibrary.fold(0, (s, g) => s + g.played.inHours);
      expect(library, lessThanOrEqualTo(p.hours));
      expect(p.devices.fold(0, (s, d) => s + d.$2), p.hours);
      expect(p.devices.first.$2, 1106);
    });

    test('игры и достижения — из библиотеки и карточек игр', () {
      expect(p.installed, 8);
      expect(
        p.unlocked,
        sampleLibrary.fold(0, (s, g) => s + EvGameFacts.of(g).unlocked),
      );
      expect((p.unlocked, p.achievements), (24, 60));
    });

    test('недавние достижения карточка игры показывает полученными', () {
      for (final e in p.recent) {
        final facts = EvGameFacts.of(e.game);
        expect(e.index, lessThan(facts.unlocked), reason: e.name);
      }
    });

    test('больше всего часов — игры библиотеки по убыванию', () {
      final top = p.top(ProfilePage.topCount);
      expect(
        [for (final g in top) g.played.inHours],
        [312, 284, 196, 148, 92, 64],
      );
      // Те же часы, что в карточке игры.
      for (final g in top) {
        expect(EvGameFacts.of(g).hours, g.played.inHours, reason: g.title);
      }
    });

    test('в герое сыграно столько же, сколько в библиотеке', () {
      expect(
        sampleHeroStates.values.first.eyebrow,
        'Продолжить · сыграно ${formatPlayed(sampleHero.played)}',
      );
    });
  });

  group('отдача', () {
    test('рейтинг, полоса и строка — из отданного и полученного', () {
      expect(formatRatio(p.ratio), '2,41');
      expect(percent(p.uploadShare), 71);
      expect(formatTraffic(p.uploadedGb), '1,4 ТБ');
      expect(formatTraffic(p.receivedGb), '581 ГБ');
    });

    test('обмен с друзьями и библиотека укладываются во весь трафик', () {
      final f = sampleFriendsFor(EvFriendsState.normal);
      final toYou = f.people.fold(0, (s, x) => s + x.traffic.toYouGb);
      expect(f.givenGb, lessThanOrEqualTo(p.uploadedGb));
      expect(toYou, lessThanOrEqualTo(p.receivedGb));
      final uploaded = sampleLibrary.fold(
        0.0,
        (s, g) => s + EvGameFacts.of(g).uploaded,
      );
      expect(uploaded, lessThanOrEqualTo(p.uploadedGb));
    });

    test('«отдано друзьям» — сумма, «кому больше всего» — по убыванию', () {
      final f = sampleFriendsFor(EvFriendsState.normal);
      expect(
        f.givenGb,
        samplePeople.fold(0, (s, x) => s + x.traffic.fromYouGb),
      );
      final most = p.gaveMost(ProfilePage.gaveCount);
      expect(
        [for (final x in most) x.name],
        ['Игорь В.', 'Антон К.', 'Вера Г.'],
      );
      for (final x in samplePeople.where((x) => !most.contains(x))) {
        expect(
          x.traffic.fromYouGb,
          lessThanOrEqualTo(most.last.traffic.fromYouGb),
        );
      }
    });

    test('раздача с Антоном и Игорем — как на их страницах', () {
      expect(percent(samplePeople[0].traffic.share), 69);
      expect(percent(samplePeople[6].traffic.share), 6);
    });
  });

  group('страница', () {
    testWidgets('окно 1440: шапка, плашки, год и панели', (tester) async {
      _window(tester, 1440, 3000);
      await _page(tester);

      expect(find.text('В EVAPORATE 2 ГОДА 4 МЕСЯЦА'), findsOneWidget);
      expect(find.text('Код: $sampleFriendCode'), findsOneWidget);
      expect(find.text('12 друзей'), findsOneWidget);
      expect(find.text('КУЗНЯ · Windows 11'), findsOneWidget);

      final tiles = [
        for (final t in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(EvStatTiles),
            matching: find.byType(Text),
          ),
        ))
          _text(t),
      ];
      expect(tiles, containsAll(['1\u00A0284', '12', '2,41']));
      expect(tiles, contains('392 часа за последний год'));
      expect(tiles, contains('8 установлено'));
      expect(tiles, contains('40 % от всех'));
      expect(tiles, contains('отдано 1,4 ТБ'));

      expect(find.text('193 дня · около 392 часов'), findsOneWidget);
      expect(find.text('Самая длинная серия — 13 дней подряд'), findsOneWidget);

      expect(find.byType(EvTopHoursRow), findsNWidgets(6));
      expect(find.byType(EvGaveRow), findsNWidgets(3));
      expect(find.text('204 ГБ'), findsOneWidget);
      expect(
        find.text('На каждый скачанный гигабайт вы вернули рою 2,41'),
        findsOneWidget,
      );
      expect(find.byType(EvAchievementTile), findsNWidgets(4));
      expect(find.byType(EvSwitch), findsNWidgets(4));
      expect(find.text('Этот компьютер · 1\u00A0106 часов'), findsOneWidget);
      expect(find.text('Linux · 178 часов · 2 часа назад'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('панели одной строки одной высоты', (tester) async {
      _window(tester, 1440, 3000);
      await _page(tester);
      expect(find.byType(EvHeadPanels), findsNWidgets(2));
      Rect panel(String label) => tester.getRect(
        find.ancestor(of: find.text(label), matching: find.byType(EvPanel)),
      );
      for (final (left, right) in [
        ('БОЛЬШЕ ВСЕГО ЧАСОВ', 'ОТДАЧА'),
        ('НЕДАВНИЕ ДОСТИЖЕНИЯ', 'ЧТО ВИДЯТ ДРУЗЬЯ'),
      ]) {
        final l = panel(left), r = panel(right);
        expect(l.height, closeTo(r.height, .5), reason: left);
        expect(l.top, r.top, reason: left);
        expect(l.width, greaterThan(r.width), reason: '1.25fr против 1fr');
      }
      // Три достижения в ряд, четвёртое — под первым.
      final tiles = find.byType(EvAchievementTile);
      expect(
        tester.getTopLeft(tiles.at(3)).dx,
        tester.getTopLeft(tiles.at(0)).dx,
      );
      expect(
        tester.getTopLeft(tiles.at(2)).dy,
        tester.getTopLeft(tiles.at(0)).dy,
      );
    });

    testWidgets('узкие окна: плашки переносятся, ничего не лезет за край', (
      tester,
    ) async {
      for (final (w, h) in [(1280.0, 720.0), (820.0, 900.0)]) {
        _window(tester, w, h);
        await _page(tester);
        expect(tester.takeException(), isNull, reason: '$w × $h');
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: '$w × $h, низ');
      }
    });

    testWidgets('тумблер говорит странице, что выключить', (tester) async {
      _window(tester, 1440, 3000);
      final calls = <(EvShare, bool)>[];
      await _page(
        tester,
        shares: EvShare.values.toSet()..remove(EvShare.byCode),
        onShare: (s, on) => calls.add((s, on)),
      );
      final switches = tester.widgetList<EvSwitch>(find.byType(EvSwitch));
      expect([for (final s in switches) s.value], [true, true, true, false]);
      await tester.tap(find.byType(EvSwitch).first);
      await tester.tap(find.byType(EvSwitch).last);
      expect(calls, [(EvShare.playing, false), (EvShare.byCode, true)]);
    });

    testWidgets('код копируется, и кнопка на две секунды это говорит', (
      tester,
    ) async {
      _window(tester, 1440, 3000);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _page(tester);
      await tester.tap(find.text('Скопировать код'));
      await tester.pump();
      expect(copied, sampleFriendCode);
      expect(find.text('Код скопирован'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Скопировать код'), findsOneWidget);
    });

    testWidgets('в окне: клавиша 6, тумблеры переживают уход со страницы', (
      tester,
    ) async {
      _window(tester, 1440, 3000);
      await _app(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
      await _settle(tester);
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.byType(EvProfileHead), findsOneWidget);

      await tester.tap(find.byType(EvSwitch).at(1));
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
      await _settle(tester);
      final switches = tester.widgetList<EvSwitch>(find.byType(EvSwitch));
      expect([for (final s in switches) s.value], [true, false, true, true]);
    });
  });
}

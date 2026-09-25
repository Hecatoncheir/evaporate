import 'package:evaporate/ui/ev/data/game_facts.dart';
import 'package:evaporate/ui/ev/data/sample_data.dart';
import 'package:evaporate/ui/ev/data/sample_friend_profiles.dart';
import 'package:evaporate/ui/ev/data/sample_friends.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/friends/ev_friend_rows.dart';
import 'package:evaporate/ui/ev/friends/friends_data.dart';
import 'package:evaporate/ui/ev/profile/ev_friend_profile_rows.dart';
import 'package:evaporate/ui/ev/profile/ev_profile_head.dart';
import 'package:evaporate/ui/ev/screens/friend_profile_page.dart';
import 'package:evaporate/ui/ev/screens/friends_page.dart';
import 'package:evaporate/ui/ev/screens/profile_page.dart';
import 'package:evaporate/ui/ev/widgets/ev_achievement.dart';
import 'package:evaporate/ui/ev/widgets/ev_icon.dart';
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
  WidgetTester tester,
  int index, {
  bool offline = false,
  VoidCallback? onOwnPrivacy,
}) async {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildEvTheme(),
      home: EvEffectsScope(
        effects: effects,
        child: Scaffold(
          body: FriendProfilePage(
            profile: sampleFriendProfile(samplePeople[index]),
            library: sampleLibrary,
            yourGame: sampleHero,
            offline: offline,
            onOwnPrivacy: onOwnPrivacy,
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

String _text(Widget w) => switch (w) {
  Text(:final data?) => data,
  Text(:final textSpan?) => textSpan.toPlainText(),
  _ => '',
};

List<String> _tiles(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(of: find.byType(EvStatTiles), matching: find.byType(Text)),
  ))
    _text(t),
];

void main() {
  group('данные страницы друга', () {
    test(
      'десять друзей выводятся из номера — те же числа, что в прототипе',
      () {
        final expected = {
          2: (1820, 28, 188, 415),
          3: (2186, 35, 184, 383),
          11: (1435, 45, 187, 413),
        };
        for (final MapEntry(key: i, value: v) in expected.entries) {
          final f = sampleFriendProfile(samplePeople[i]);
          expect(
            (f.hours, f.achievements!.$1, f.year!.days, f.year!.hours),
            v,
            reason: samplePeople[i].name,
          );
        }
        final anton = sampleFriendProfile(samplePeople[0]);
        expect((anton.year!.days, anton.year!.hours), (182, 404));
      },
    );

    test('часы за всё время не меньше общих игр и года', () {
      for (final p in samplePeople) {
        final f = sampleFriendProfile(p);
        if (f.hours == null) continue;
        final common = f.common.fold(0, (s, g) => s + g.his!);
        expect(f.hours, greaterThanOrEqualTo(common), reason: p.name);
        expect(f.hours, greaterThanOrEqualTo(f.year!.hours), reason: p.name);
      }
    });

    test('общих в списке не больше, чем общих всего, и все — ваши игры', () {
      for (final p in samplePeople) {
        final f = sampleFriendProfile(p);
        expect(f.common.length, lessThanOrEqualTo(p.common), reason: p.name);
        for (final g in f.common) {
          expect(sampleLibrary, contains(g.game));
          expect(g.mine, g.game.played.inHours);
        }
      }
    });

    test('«которых нет у вас» — карточка игры показывает их неполученными', () {
      final anton = sampleFriendProfile(samplePeople[0]);
      expect(anton.only, hasLength(3));
      for (final (game, index) in anton.only) {
        expect(
          index,
          greaterThanOrEqualTo(EvGameFacts.of(game).unlocked),
          reason: '${game.title}: ${EvGameFacts.achievements[index].$1}',
        );
      }
    });

    test('скрытое не приходит: у Игоря нет часов, года и достижений', () {
      final igor = sampleFriendProfile(samplePeople[6]);
      expect(igor.hours, isNull);
      expect(igor.year, isNull);
      expect(igor.achievements, isNull);
      expect(igor.common.every((g) => g.his == null), isTrue);
      expect(
        [for (final h in igor.hidden) h.$1],
        ['Во что играет', 'Часы и общее время', 'Достижения'],
      );
      expect(sampleFriendProfile(samplePeople[0]).hidden, isEmpty);
    });

    test('лена отдала вам не меньше, чем в ленте за неделю', () {
      expect(samplePeople[2].traffic.toYouGb, greaterThanOrEqualTo(14.2));
    });
  });

  group('страница', () {
    testWidgets('Антон: открыт, первое число — сколько раздал вам', (
      tester,
    ) async {
      _window(tester, 1440, 3200);
      await _page(tester, 0);
      final tiles = _tiles(tester);
      expect(tiles.take(2), ['РАЗДАЛ ВАМ', '214 ГБ']);
      expect(tiles, contains('вы ему — 96 ГБ'));
      expect(tiles, contains('2\u00A0140'));
      expect(find.text('в друзьях с марта 2025'), findsOneWidget);
      expect(find.text('11 общих игр'), findsOneWidget);

      expect(find.byType(EvFriendNowCard), findsOneWidget);
      expect(
        find.text('2 ч 14 мин · Глава 5 · та же глава, что у вас'),
        findsOneWidget,
      );

      expect(find.text('5 из 11'), findsOneWidget);
      final rows = tester.widgetList<EvCommonGameRow>(
        find.byType(EvCommonGameRow),
      );
      expect(
        [for (final r in rows) r.common.game.title],
        [
          'Пепельный Предел',
          'Волчья Тропа',
          'Красный Меридиан',
          'Грозовой Фронт',
          'Глубина 9',
        ],
      );
      expect(
        find.text(
          '69 % трафика между вами шло от него — он раздаёт вам чаще, '
          'чем вы ему',
        ),
        findsOneWidget,
      );
      expect(find.text('Ничего не скрыто'), findsOneWidget);
      expect(find.text('182 дня · около 404 часов'), findsOneWidget);
      expect(
        find.text('Достижения, которых нет у вас'.toUpperCase()),
        findsOneWidget,
      );
      expect(find.byType(EvAchievementTile), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('расходящиеся полосы: у кого больше часов, та длиннее', (
      tester,
    ) async {
      _window(tester, 1440, 3200);
      await _page(tester, 0);
      final ashen = find.ancestor(
        of: find.text('Пепельный Предел'),
        matching: find.byType(EvCommonGameRow),
      );
      Rect bar(String hours) {
        final label = tester.getRect(
          find.descendant(of: ashen, matching: find.text(hours)),
        );
        final boxes = find.descendant(
          of: ashen,
          matching: find.byType(FractionallySizedBox),
        );
        return [
          for (final e in boxes.evaluate())
            tester.getRect(find.byWidget(e.widget)),
        ].reduce(
          (a, b) =>
              (a.center.dx - label.center.dx).abs() <
                  (b.center.dx - label.center.dx).abs()
              ? a
              : b,
        );
      }

      final mine = bar('284 ч'), his = bar('412 ч');
      // Ваша — слева от середины, его — справа, и его длиннее.
      expect(mine.right, lessThan(his.left));
      expect(his.width, greaterThan(mine.width));
    });

    testWidgets('Игорь: скрытое показано скрытым', (tester) async {
      _window(tester, 1440, 3200);
      await _page(tester, 6, onOwnPrivacy: () {});
      final tiles = _tiles(tester);
      expect(tiles.where((t) => t == 'скрыто'), hasLength(2));
      expect(tiles, contains('он не показывает часы'));
      expect(tiles, contains('он не показывает достижения'));
      expect(
        find.descendant(
          of: find.byType(EvStatTiles),
          matching: find.byWidgetPredicate(
            (w) => w is EvIcon && w.name == EvIcons.lock,
          ),
        ),
        findsNWidgets(2),
      );
      expect(find.text('Игорь не показывает, во что играет'), findsOneWidget);
      expect(find.byType(EvFriendNowCard), findsNothing);
      expect(find.byType(EvHiddenRow), findsNWidgets(3));
      expect(find.text('Это его выбор, а не ошибка'), findsOneWidget);
      expect(find.text('Мой профиль'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EvCommonGameRow),
          matching: find.text('скрыто'),
        ),
        findsNWidgets(3),
      );
      expect(find.text('ГОД ИГРЫ'), findsNothing);
      expect(find.byType(EvAchievementTile), findsNothing);
      expect(
        find.text('Только 6 % шло от него: вы раздаёте ему заметно больше'),
        findsOneWidget,
      );
    });

    testWidgets('Лена — «раздала», «ей», «от неё»', (tester) async {
      _window(tester, 1440, 3200);
      await _page(tester, 2);
      final tiles = _tiles(tester);
      expect(tiles.first, 'РАЗДАЛА ВАМ');
      expect(tiles, contains('вы ей — 34 ГБ'));
      expect(find.text('раздала вам 18 ГБ'), findsOneWidget);
      expect(
        find.text('Только 35 % шло от неё: вы раздаёте ей заметно больше'),
        findsOneWidget,
      );
      // Не в той же игре, что ваш герой, — и глава не «та же».
      expect(find.text('5 ч 02 мин · Чёрная река'), findsOneWidget);
    });

    testWidgets('не играет и скрыл игру — разные слова', (tester) async {
      _window(tester, 1440, 3200);
      await _page(tester, 3);
      expect(find.text('Дан в сети, но не в игре'), findsOneWidget);
      expect(find.text('НЕ ПОКАЗЫВАЕТ'), findsNothing);
      await _page(tester, 11);
      expect(find.text('Пётр не в сети'), findsOneWidget);
      expect(find.text('1 общая игра'), findsOneWidget);
    });

    testWidgets('без сети он не в сети и игры не видно', (tester) async {
      _window(tester, 1440, 3200);
      await _page(tester, 0, offline: true);
      expect(find.byType(EvFriendNowCard), findsNothing);
      expect(find.text('Антон не в сети'), findsOneWidget);
      final avatar = tester.widget<EvProfileAvatar>(
        find.byType(EvProfileAvatar),
      );
      final colors = tester.element(find.byType(EvProfileAvatar)).ev.colors;
      expect(avatar.status, evStatusColor(colors, EvPersonStatus.offline));
    });

    testWidgets('узкие окна без переполнения', (tester) async {
      for (final (w, h) in [(1280.0, 720.0), (820.0, 900.0)]) {
        for (final i in [0, 6]) {
          _window(tester, w, h);
          await _page(tester, i);
          await tester.drag(find.byType(ListView), const Offset(0, -4000));
          await _settle(tester);
          expect(tester.takeException(), isNull, reason: '$w × $h, $i');
        }
      }
    });
  });

  group('в окне', () {
    testWidgets('строка друга ведёт на его страницу, Esc — обратно', (
      tester,
    ) async {
      _window(tester, 1440, 3200);
      await _app(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await _settle(tester);
      expect(find.text('1 общая'), findsOneWidget);
      expect(find.text('от неё'), findsNWidgets(2));

      await tester.tap(find.text('Игорь В.'));
      await _settle(tester);
      expect(find.byType(FriendProfilePage), findsOneWidget);
      // В хлебной крошке имя, рейл остаётся на «Друзьях».
      expect(find.text('Игорь В.'), findsWidgets);
      expect(find.text('Друзья'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(find.byType(FriendsPage), findsOneWidget);
      expect(find.text('Друзья'), findsOneWidget);
    });

    testWidgets('карточка «сейчас в игре» и «Все друзья»', (tester) async {
      _window(tester, 1440, 3200);
      await _app(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await _settle(tester);
      await tester.tap(find.byType(EvNowPlayingCard).first);
      await _settle(tester);
      expect(
        tester
            .widget<FriendProfilePage>(find.byType(FriendProfilePage))
            .profile
            .person
            .name,
        'Антон К.',
      );
      await tester.tap(find.text('ВСЕ ДРУЗЬЯ'));
      await _settle(tester);
      expect(find.byType(FriendsPage), findsOneWidget);
    });

    testWidgets('повторный выбор раздела возвращает к списку', (tester) async {
      _window(tester, 1440, 3200);
      await _app(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await _settle(tester);
      await tester.tap(find.text('Дан Р.'));
      await _settle(tester);
      expect(find.byType(FriendProfilePage), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await _settle(tester);
      expect(find.byType(FriendsPage), findsOneWidget);
    });

    testWidgets(
      '«Разработка» открывает закрытый профиль, «Мой профиль» — свой',
      (tester) async {
        _window(tester, 1440, 3200);
        await _app(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
        await _settle(tester);
        await tester.ensureVisible(find.text('Закрытый профиль'));
        await _settle(tester);
        await tester.tap(find.text('Закрытый профиль'));
        await _settle(tester);
        expect(find.text('Игорь не показывает, во что играет'), findsOneWidget);
        await tester.tap(find.text('Мой профиль'));
        await _settle(tester);
        expect(find.byType(ProfilePage), findsOneWidget);
      },
    );
  });
}

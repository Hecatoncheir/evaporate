import 'package:evaporate/ui/ev/data/sample_data.dart';
import 'package:evaporate/ui/ev/data/sample_downloads.dart';
import 'package:evaporate/ui/ev/data/sample_friends.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/downloads/download_data.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/friends/ev_friend_rows.dart';
import 'package:evaporate/ui/ev/friends/friends_data.dart';
import 'package:evaporate/ui/ev/library/ev_side_cards.dart';
import 'package:evaporate/ui/ev/screens/friends_page.dart';
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

int get _rate => sampleDownloadsFor(EvDownloadsState.active).downKb;

Future<void> _page(
  WidgetTester tester,
  EvFriendsState state, {
  bool offline = false,

  /// Весь приём окна — из него считается доля друзей.
  int? rateKb,
  VoidCallback? onInvite,
}) async {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildEvTheme(),
      home: EvEffectsScope(
        effects: effects,
        child: Scaffold(
          body: FriendsPage(
            friends: sampleFriendsFor(state, offline: offline),
            rateKb: rateKb ?? (offline ? 0 : _rate),
            onInvite: onInvite,
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// Выбрать состояние в «Настройках → Разработка». Список состояний
/// длинный, поэтому прокрутка своя на каждую группу.
Future<void> _pick(
  WidgetTester tester,
  String name, {
  required LogicalKeyboardKey back,
}) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
  await _settle(tester);
  await tester.ensureVisible(find.text(name));
  await _settle(tester);
  await tester.tap(find.text(name));
  await _settle(tester);
  await tester.sendKeyEvent(back);
  await _settle(tester);
}

void main() {
  group('числа друзей', () {
    test('приём от друзей и доля считаются из раздающих', () {
      final f = sampleFriendsFor(EvFriendsState.normal);
      expect(f.fromFriendsKb, 402 + 870 + 68);
      expect(f.fromFriendsKb, 1340);
      expect((f.shareOf(_rate) * 100).round(), 83);
      expect(f.online, 6);
      expect(f.people, hasLength(12));
      expect(f.seeders, hasLength(3));
    });

    test('доля раздающего — из скорости той же раздачи', () {
      final queue = sampleDownloadsFor(EvDownloadsState.active);
      for (final s in sampleFriendsFor(EvFriendsState.normal).seeders) {
        final torrent = queue.torrents.firstWhere(
          (t) => t.game.title == s.game.title,
        );
        expect(s.ofKb, torrent.downKb, reason: s.person.name);
        expect(s.rateKb, lessThanOrEqualTo(s.ofKb));
      }
      final shares = [
        for (final s in sampleFriendsFor(EvFriendsState.normal).seeders)
          (s.share * 100).round(),
      ];
      expect(shares, [68, 84, 11]);
    });

    test('общих игр не больше, чем игр в библиотеке', () {
      for (final p in samplePeople) {
        expect(
          p.common,
          lessThanOrEqualTo(sampleLibrary.length),
          reason: p.name,
        );
      }
    });

    test('три доли делят библиотеку целиком', () {
      final lib = sampleFriendsFor(EvFriendsState.normal).library;
      expect(lib.total, sampleLibrary.length);
      expect(lib.shared, lib.everyone + lib.half);
      expect(lib.shared, sampleLibrary.length - lib.onlyYou);
      expect(lib.shared, 8);
    });

    test('без сети раздающих нет и никто не в сети', () {
      final f = sampleFriendsFor(EvFriendsState.normal, offline: true);
      expect(f.seeders, isEmpty);
      expect(f.fromFriendsKb, 0);
      expect(f.online, 0);
      expect(f.playing, isEmpty);
      // Сам список при этом остаётся: друзья не исчезли.
      expect(f.people, hasLength(12));
    });
  });

  group('раздел «Друзья»', () {
    testWidgets('обычное состояние: приборы, полки и списки', (tester) async {
      _window(tester, 1440, 2000);
      await _page(tester, EvFriendsState.normal);

      expect(find.textContaining('1.34', findRichText: true), findsOneWidget);
      expect(
        find.text('83 % вашей скорости приёма дают друзья, а не рой'),
        findsOneWidget,
      );
      expect(find.text('6'), findsOneWidget, reason: 'в сети');
      expect(find.text('12'), findsOneWidget, reason: 'всего');
      expect(
        find.text('510 ГБ'),
        findsOneWidget,
        reason: 'отдано друзьям — сумма по каждому',
      );

      expect(find.byType(EvNowPlayingCard), findsNWidgets(3));
      expect(find.text('3 из 12'), findsOneWidget);
      expect(find.text('2 ч 14 мин · Глава 5'), findsOneWidget);

      expect(find.byType(EvSeederRow), findsNWidgets(3));
      expect(find.text('3 источника'), findsOneWidget);
      expect(find.text('402 КБ/с'), findsOneWidget);
      expect(
        find.textContaining('68 % из 592 КБ/с', findRichText: true),
        findsOneWidget,
      );

      expect(find.byType(EvFriendRow), findsNWidgets(12));
      expect(find.text('6 в сети из 12'), findsOneWidget);
      expect(find.text('в игре · Пепельный Предел'), findsOneWidget);
      expect(find.text('был вчера в 22:10'), findsOneWidget);
      expect(find.text('11 общих'), findsOneWidget);

      // Общая библиотека: текст и доли — одни и те же числа.
      expect(
        find.text('У вас 8 игр, которые есть хотя бы у одного друга'),
        findsOneWidget,
      );
      expect(find.byType(EvStackBar), findsOneWidget);

      expect(find.byType(EvInviteCard), findsNothing);
      expect(find.text('Новых заявок нет'), findsOneWidget);
    });

    testWidgets('доля друзей считается из приёма, а не написана', (
      tester,
    ) async {
      _window(tester, 1440, 2000);
      // Тот же вклад друзей при вдвое большем приёме — вдвое меньшая доля.
      await _page(tester, EvFriendsState.normal, rateKb: _rate * 2);
      expect(
        find.text('41 % вашей скорости приёма дают друзья, а не рой'),
        findsOneWidget,
      );
    });

    testWidgets('полоса общей библиотеки — видимая и в долях', (tester) async {
      _window(tester, 1440, 2000);
      await _page(tester, EvFriendsState.normal);
      final bar = find.byType(EvStackBar);
      final box = tester.getRect(bar);
      // Доли — пустые коробки: без stretch они схлопывались в ноль,
      // и полосы просто не было видно.
      expect(box.height, 8);
      final parts = find.descendant(
        of: bar,
        matching: find.byType(DecoratedBox),
      );
      expect(parts, findsNWidgets(3));
      final widths = [
        for (var i = 0; i < 3; i++) tester.getRect(parts.at(i)).width,
      ];
      for (final w in widths) {
        expect(w, greaterThan(0));
      }
      expect(tester.getRect(parts.at(0)).height, 8);
      // 3 : 5 : 4 — те же числа, что подписаны под полосой.
      expect(widths[1] / widths[0], closeTo(5 / 3, .02));
      expect(widths[2] / widths[0], closeTo(4 / 3, .02));
    });

    testWidgets('заявка: два решения, и оба её убирают', (tester) async {
      _window(tester, 1440, 2000);
      var answered = 0;
      await _page(tester, EvFriendsState.invite, onInvite: () => answered++);
      expect(find.byType(EvInviteCard), findsOneWidget);
      expect(find.text('Кирилл Ж. хочет добавиться'), findsOneWidget);
      expect(find.text('Новых заявок нет'), findsNothing);

      await tester.tap(find.text('Принять'));
      await _settle(tester);
      await tester.tap(find.text('Отклонить'));
      await _settle(tester);
      expect(answered, 2);
    });

    testWidgets('без сети: две таблички вместо полок, список остаётся', (
      tester,
    ) async {
      _window(tester, 1440, 2000);
      await _page(tester, EvFriendsState.normal, offline: true);

      expect(find.byType(EvNowPlayingCard), findsNothing);
      expect(find.byType(EvSeederRow), findsNothing);
      expect(find.byType(EvNothing), findsNWidgets(2));
      expect(find.text('Нет связи с друзьями'), findsOneWidget);
      expect(find.text('Пиры от друзей недоступны'), findsOneWidget);
      expect(find.text('никого'), findsOneWidget);
      expect(find.text('никто'), findsOneWidget);
      expect(
        find.text('Нет сети — весь приём идёт из общего роя'),
        findsOneWidget,
      );
      expect(find.textContaining('0.00', findRichText: true), findsOneWidget);
      expect(find.text('0 в сети из 12'), findsOneWidget);
      // Список не исчезает, но все в нём не в сети.
      expect(find.byType(EvFriendRow), findsNWidgets(12));
      expect(find.text('в игре · Пепельный Предел'), findsNothing);
      expect(find.text('не в сети'), findsNWidgets(6));
    });

    testWidgets('на узком окне «общих» и «написать» уходят', (tester) async {
      _window(tester, 780, 2400);
      await _page(tester, EvFriendsState.normal);
      expect(find.text('11 общих'), findsNothing);
      expect(find.byType(EvFriendRow), findsNWidgets(12));
      expect(find.text('Антон К.'), findsWidgets);
    });
  });

  group('состояние окна', () {
    testWidgets('заявка переключается из «Разработки» и принимается', (
      tester,
    ) async {
      _window(tester, 1440, 1000);
      await _app(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await _settle(tester);
      expect(find.byType(EvInviteCard), findsNothing);

      await _pick(tester, 'Заявка в друзья', back: LogicalKeyboardKey.digit5);
      expect(find.byType(EvInviteCard), findsOneWidget);

      await tester.tap(find.text('Принять'));
      await _settle(tester);
      expect(find.byType(EvInviteCard), findsNothing);
      expect(find.text('Новых заявок нет'), findsOneWidget);
    });

    testWidgets('офлайн из библиотеки доходит до друзей и правой колонки', (
      tester,
    ) async {
      _window(tester, 1900, 1100);
      await _app(tester);
      // Правая колонка широкого окна показывает тех же друзей.
      expect(find.byType(EvFriendsCard), findsOneWidget);
      // Подсказка рейла и заголовок карточки — одно и то же число.
      expect(find.text('Друзья · 6 в сети'), findsOneWidget);
      expect(find.text('ДРУЗЬЯ · 6 В СЕТИ'), findsOneWidget);

      await _pick(tester, 'Нет сети', back: LogicalKeyboardKey.digit1);
      expect(find.text('Друзья · 0 в сети'), findsOneWidget);
      expect(find.text('ДРУЗЬЯ · 0 В СЕТИ'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await _settle(tester);
      expect(find.byType(EvNowPlayingCard), findsNothing);
      expect(find.text('Пиры от друзей недоступны'), findsOneWidget);
    });
  });
}

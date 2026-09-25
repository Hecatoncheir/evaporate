import 'package:evaporate/ui/ev/data/game_facts.dart';
import 'package:evaporate/ui/ev/data/sample_data.dart';
import 'package:evaporate/ui/ev/data/sample_downloads.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/downloads/download_data.dart';
import 'package:evaporate/ui/ev/downloads/ev_torrent_row.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/first_run/ev_add_torrent.dart';
import 'package:evaporate/ui/ev/first_run/ev_first_run_widgets.dart';
import 'package:evaporate/ui/ev/first_run/first_run_data.dart';
import 'package:evaporate/ui/ev/launch/ev_launch_ritual.dart';
import 'package:evaporate/ui/ev/library/ev_hero.dart';
import 'package:evaporate/ui/ev/screens/downloads_page.dart';
import 'package:evaporate/ui/ev/screens/library_page.dart';
import 'package:evaporate/ui/ev/sheet/ev_part_row.dart';
import 'package:evaporate/ui/ev/util/units.dart';
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

Future<void> _app(WidgetTester tester, {bool read = false}) async {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  await tester.pumpWidget(EvaporateApp(effects: effects, readCatalog: read));
}

/// Запустить сценарий из «Разработки» — как пункт в панели прототипа.
Future<void> _start(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
  await _settle(tester);
  await tester.ensureVisible(find.text('Первый запуск'));
  await _settle(tester);
  await tester.tap(find.text('Первый запуск'));
  await _settle(tester);
}

Future<void> _next(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await _settle(tester);
}

String _step(WidgetTester tester) =>
    tester.widget<EvFlowBar>(find.byType(EvFlowBar)).title;

void main() {
  final facts = EvGameFacts.of(EvFirstRun.game);

  group('данные', () {
    test('раздача предлагает то, что карточка держит на диске', () {
      final onDisk = facts.parts.where((p) => p.onDisk);
      expect(EvFirstRun.offered, onDisk.fold<double>(0, (s, p) => s + p.size));
      expect(formatGb(EvFirstRun.offered), '68,4 ГБ');
      expect(onDisk.first.required, isTrue);
    });

    test('время до конца — из остатка и скорости', () {
      expect(formatEta(40.356, 1420), 'осталось 7 ч 54 мин');
      expect(formatEta(1.2, 1000), 'осталось 20 мин');
      expect(formatEta(5, 0), 'время не определено');
      const run = EvFirstRun(EvFirstRunStep.downloading);
      final t = run.torrent!;
      expect(t.eta, formatEta(run.total - t.parts.received, t.downKb!));
      expect(run.detail, '41 % · 28,0 ГБ из 68,4 ГБ · осталось 7 ч 54 мин');
    });

    test('размер раздачи — тот, что выбрали галочками', () {
      const gb = 62.2;
      const run = EvFirstRun(EvFirstRunStep.downloading, gb: gb);
      expect(run.torrent!.parts.total, closeTo(gb, 1e-9));
      expect(run.hero.chips, contains(('62,2 ГБ', false)));
      expect(
        run.at(EvFirstRunStep.verifying).torrent!.parts.total,
        closeTo(gb, 1e-9),
      );
    });

    test('три фазы раздачи: разгон, ход, проверка', () {
      const base = EvFirstRun(EvFirstRunStep.installed);
      final phases = [
        for (final s in [
          EvFirstRunStep.queued,
          EvFirstRunStep.downloading,
          EvFirstRunStep.verifying,
        ])
          base.at(s).torrent!,
      ];
      expect([for (final t in phases) percent(t.progress)], [0, 41, 88]);
      expect(phases.first.eta, 'оцениваем скорость');
      expect(phases.last.alert, isNotNull);
      for (final t in phases) {
        expect(t.parts.remaining, greaterThanOrEqualTo(0));
        expect(t.downKb, lessThanOrEqualTo(t.peakKb));
      }
      expect(base.at(EvFirstRunStep.installing).torrent, isNull);
    });

    test('шаги: пусто до проверки, загрузки — три средних', () {
      const steps = EvFirstRunStep.values;
      expect(steps, hasLength(8));
      expect(
        [for (final s in steps) s.empty],
        [
          true, true, true, true, true, false, false, false, //
        ],
      );
      expect(
        [for (final s in steps) s.downloads],
        [
          false, false, true, true, true, false, false, false, //
        ],
      );
      expect(EvFirstRunStep.installed.previous, isNull);
      expect(EvFirstRunStep.launch.next, isNull);
    });
  });

  group('виджеты', () {
    Future<void> host(WidgetTester tester, Widget child) async {
      final effects = EvEffects.still();
      addTearDown(effects.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildEvTheme(),
          home: EvEffectsScope(
            effects: effects,
            child: Scaffold(body: child),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('пустая библиотека: три входа ведут к добавлению', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      var added = 0;
      await host(
        tester,
        LibraryPage(
          games: const [],
          hero: sampleHero,
          sessions: const [],
          friends: const [],
          friendsOnline: 0,
          downloads: sampleDownloadsFor(EvDownloadsState.empty),
          onAdd: () => added++,
        ),
      );
      expect(find.byType(EvLibraryEmpty), findsOneWidget);
      expect(find.byType(EvHero), findsNothing);
      expect(find.text('Ни одной игры'), findsOneWidget);
      expect(find.text('пока что'), findsOneWidget);
      await tester.tap(find.text('Просканировать диск'));
      await tester.tap(find.text('Вставить magnet-ссылку'));
      await tester.tap(find.text('Перетащите сюда .torrent или папку с игрой'));
      await tester.pump();
      expect(added, 3);
    });

    testWidgets('чтение каталога — скелет вместо героя', (tester) async {
      _window(tester, 1440, 900);
      await host(
        tester,
        LibraryPage(
          games: sampleLibrary,
          hero: sampleHero,
          sessions: sampleSessions,
          friends: const [],
          friendsOnline: 0,
          downloads: sampleDownloadsFor(EvDownloadsState.empty),
          catalog: EvCatalog.reading,
        ),
      );
      expect(find.byType(EvLibrarySkeleton), findsOneWidget);
      expect(find.byType(EvHero), findsNothing);
    });

    testWidgets('диалог: галочки пересчитывают сумму и остаток', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      double? result = -1;
      await host(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.of(context).push(
              evAddTorrentRoute(
                game: EvFirstRun.game,
                freeGb: 214,
                folder: r'D:\Игры\AshenVerge',
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      Future<void> open() async {
        await tester.tap(find.text('open'));
        await _settle(tester);
      }

      await open();
      final rows = find.byType(EvPartRow);
      expect(rows, findsNWidgets(facts.parts.length));
      // Сумма — над частями и на кнопке «Скачать».
      expect(find.text('68,4 ГБ'), findsNWidgets(2));
      expect(find.text('останется 146 ГБ', findRichText: true), findsOneWidget);

      // «Игра» обязательна: нажатие ничего не меняет.
      await tester.tap(rows.first);
      await tester.pump();
      expect(find.text('68,4 ГБ'), findsNWidgets(2));

      // Текстуры сняли — сумма и остаток пересчитались.
      await tester.tap(find.text('Текстуры 4K'));
      await tester.pump();
      final minus = EvFirstRun.offered - facts.parts[2].size;
      expect(find.text(formatGb(minus)), findsNWidgets(2));
      expect(
        find.text('останется ${(214 - minus).round()} ГБ', findRichText: true),
        findsOneWidget,
      );

      await tester.tap(find.text('Скачать'));
      await _settle(tester);
      expect(result, closeTo(minus, 1e-9));

      await open();
      await tester.tap(find.text('Отмена'));
      await _settle(tester);
      expect(result, isNull);
    });
  });

  group('в окне', () {
    testWidgets('при старте каталог читается 300 мс', (tester) async {
      _window(tester, 1440, 900);
      await _app(tester, read: true);
      await tester.pump();
      expect(find.byType(EvLibrarySkeleton), findsOneWidget);
      expect(find.text('Читаем каталог'), findsWidgets);
      await tester.pump(EvCatalog.readTime);
      await tester.pump();
      expect(find.byType(EvLibrarySkeleton), findsNothing);
      expect(find.byType(EvHero), findsOneWidget);
    });

    testWidgets('весь сценарий: пусто → диалог → загрузки → герой → ритуал', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _settle(tester);
      await _start(tester);

      expect(_step(tester), 'Лаунчер только что установлен');
      expect(find.byType(EvLibraryEmpty), findsOneWidget);
      expect(find.text('Каталог пуст'), findsOneWidget);

      await _next(tester);
      expect(find.byType(EvAddTorrent), findsOneWidget);
      await tester.tap(find.text('Текстуры 4K'));
      await tester.pump();
      await tester.tap(find.text('Скачать'));
      await _settle(tester);

      final chosen = EvFirstRun.offered - facts.parts[2].size;
      expect(_step(tester), 'Загрузка встала в очередь');
      expect(find.byType(DownloadsPage), findsOneWidget);
      expect(find.byType(EvTorrentRow), findsOneWidget);
      expect(find.text('Разгоняемся'), findsOneWidget);

      await _next(tester);
      expect(_step(tester), 'Качается');
      expect(
        find.textContaining(formatGb(chosen), findRichText: true),
        findsWidgets,
      );

      await _next(tester);
      expect(find.text('Проверяем целостность'), findsOneWidget);
      await _next(tester);
      expect(find.byType(LibraryPage), findsOneWidget);
      await _next(tester);
      expect(find.text('ГОТОВО · УСТАНОВЛЕНА ТОЛЬКО ЧТО'), findsOneWidget);
      expect(find.text('1 установлена'), findsOneWidget);

      await _next(tester);
      expect(find.byType(EvLaunchRitual), findsOneWidget);
    });

    testWidgets('отказ в диалоге возвращает к пустой библиотеке', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _settle(tester);
      await _start(tester);
      await _next(tester);
      await tester.tap(find.text('Отмена'));
      await _settle(tester);
      expect(find.byType(EvAddTorrent), findsNothing);
      expect(_step(tester), 'Лаунчер только что установлен');
    });

    testWidgets('кнопки полосы листают, диалог уходит вместе с шагом', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _settle(tester);
      await _start(tester);
      expect(find.text('1/8'), findsOneWidget);
      await tester.tap(find.text('Дальше'));
      await _settle(tester);
      expect(find.byType(EvAddTorrent), findsOneWidget);
      await tester.tap(find.text('Дальше'));
      await _settle(tester);
      expect(find.byType(EvAddTorrent), findsNothing);
      expect(find.text('3/8'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Назад').last);
      await _settle(tester);
      expect(find.text('2/8'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Выйти из сценария'));
      await _settle(tester);
      expect(find.byType(EvFlowBar), findsNothing);
      expect(find.byType(EvAddTorrent), findsNothing);
      expect(find.byType(EvHero), findsOneWidget);
    });

    testWidgets('из пустой библиотеки Ctrl+V открывает добавление', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await _settle(tester);
      await tester.ensureVisible(find.text('Пусто · первый запуск'));
      await tester.tap(find.text('Пусто · первый запуск'));
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await _settle(tester);
      expect(find.byType(EvLibraryEmpty), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _settle(tester);
      expect(find.byType(EvAddTorrent), findsOneWidget);
      expect(_step(tester), 'Вставили magnet-ссылку');
    });
  });
}

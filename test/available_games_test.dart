import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/downloads/available_games.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// «Можно скачать» — для многих единственное место, где неустановленная
/// игра вообще видна. Убрать её отсюда должно быть можно, не уходя на её
/// страницу, — но не одним нажатием: со ссылкой на раздачу уйдёт и она.
void main() {
  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  Future<TestHarness> show(WidgetTester tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(
      title: 'Ждёт очереди',
      source: const GameSource(
        kind: GameSourceKind.magnet,
        value: 'magnet:?xt=urn:btih:1234',
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: harness.settings),
          BlocProvider<LibraryBloc>.value(value: harness.library),
          BlocProvider<DownloadsBloc>.value(value: harness.downloads),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          locale: const Locale('ru'),
          theme: EvaporateTheme.dark(),
          home: Scaffold(
            body: BlocBuilder<LibraryBloc, LibraryState>(
              builder: (context, state) =>
                  AvailableGames(library: state, tasks: const []),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Добавление игры ставит отложенную запись библиотеки на 400 мс. Не
    // дать ей отработать — значит оставить таймер висеть, а тест падает
    // на этом уже при разборке дерева.
    await tester.pump(const Duration(milliseconds: 600));
    return harness;
  }

  testWidgets('у игры в списке есть чем её убрать', (tester) async {
    await show(tester);

    expect(find.text('Ждёт очереди'), findsOneWidget);
    expect(find.byTooltip('Удалить из библиотеки'), findsOneWidget);
  });

  // Вместе с игрой уходит и ссылка на раздачу: найти её заново человеку
  // будет негде, и делать это по одному промаху нельзя.
  testWidgets('удаление сначала спрашивает, а отказ ничего не меняет', (
    tester,
  ) async {
    final harness = await show(tester);

    await tester.tap(find.byTooltip('Удалить из библиотеки'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ждёт очереди'), findsWidgets);
    expect(find.text('Удалить из библиотеки'), findsWidgets);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(harness.library.state.games, hasLength(1));
  });

  // Само удаление здесь не доводят до конца, и это не упущение:
  // обработчик `GameRemoved` уходит на диск — убирает обложку, снимки,
  // папку, — а начатый в фейковом времени ввод-вывод не завершается
  // никогда. `Bloc.close()` при разборке ждал бы его вечно. Что удаление
  // делает, проверяет `library_bloc_test.dart` в настоящей зоне; здесь же
  // проверяется проводка: клавиша есть, вопрос задан, отказ ничего не
  // меняет.

  // Игру, которую ещё не качали, стирать нечем: папки установки у неё нет,
  // и выбор «вместе с файлами» был бы предложением ни о чём.
  testWidgets('нескачанной игре не предлагают стереть файлы', (tester) async {
    await show(tester);

    await tester.tap(find.byTooltip('Удалить из библиотеки'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить вместе с файлами'), findsNothing);
  });
}

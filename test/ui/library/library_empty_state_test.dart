import 'dart:io';

import 'package:evaporate/bloc/library_view/library_view_bloc.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/shelf.dart';
import 'package:evaporate/ui/library/library_empty_state.dart';
import 'package:evaporate/ui/library/library_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';
import '../../support/test_app.dart';

/// Пустая полка: три пути пополнить библиотеку — или ни одного, если
/// пусто только в поиске.
void main() {
  final l = LRu();

  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  testWidgets('пустая библиотека предлагает три пути', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);

    expect(find.text(l.libraryEmpty), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, l.findInstalledGames),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, l.addGameSource),
      findsOneWidget,
    );
    expect(find.text(l.libraryDropHint), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, l.addGameSource));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  // Поиск установленных держит страница: пока он идёт, полка бросков не
  // ловит. Своя копия поиска у пустой полки этого флага не знала бы.
  testWidgets('пустая полка зовёт тот же поиск, что панель', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);

    final empty = tester.widget<LibraryEmptyState>(
      find.byType(LibraryEmptyState),
    );
    final toolbar = tester.widget<LibraryToolbar>(find.byType(LibraryToolbar));
    expect(empty.onScan, same(toolbar.onScan));
  });

  testWidgets('клавиша поиска зовёт поиск установленных', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    var scans = 0;
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: harness.library),
          BlocProvider(create: (_) => LibraryViewBloc()),
        ],
        child: hostWidget(LibraryEmptyState(onScan: () => scans++)),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, l.findInstalledGames));
    expect(scans, 1);
  });

  // Поиск ничего не нашёл — библиотека не пуста, и пополнять её сейчас
  // незачем: клавиши только мешали бы.
  testWidgets('в пустом поиске путей пополнения нет', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(title: 'Альфа');
    await harness.pump(tester);

    tester
        .element(find.byType(LibraryToolbar))
        .read<LibraryViewBloc>()
        .add(const LibraryQueryChanged('нет такой'));
    await tester.pumpAndSettle();

    expect(find.text(l.nothingFound), findsOneWidget);
    expect(find.text(l.libraryDropHint), findsNothing);
    expect(
      find.widgetWithText(FilledButton, l.findInstalledGames),
      findsNothing,
    );
  });

  // Пустая полка отбора без всякого поиска — не «ничего не найдено»: у
  // «Продолжить» так пусто у каждого, кто ещё ничего не запускал.
  testWidgets('пустая полка без поиска говорит, почему пусто', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(title: 'Альфа');
    await harness.pump(tester);
    final view = tester
        .element(find.byType(LibraryToolbar))
        .read<LibraryViewBloc>();

    view.add(const LibraryShelfSelected(Shelf.recent));
    await tester.pumpAndSettle();
    expect(find.text(l.shelfRecentEmpty), findsOneWidget);
    expect(find.text(l.nothingFound), findsNothing);

    view.add(const LibraryShelfSelected(Shelf.installed));
    await tester.pumpAndSettle();
    expect(find.text(l.shelfEmpty), findsOneWidget);
    expect(find.text(l.nothingFound), findsNothing);
  });
}

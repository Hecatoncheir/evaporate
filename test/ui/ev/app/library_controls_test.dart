import 'dart:io';

import 'package:evaporate/bloc/library_view/library_view_bloc.dart';
import 'package:evaporate/l10n/app_localizations_en.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/shelf.dart';
import 'package:evaporate/ui/ev/app/ev_library_add_menu.dart';
import 'package:evaporate/ui/ev/app/ev_library_card.dart';
import 'package:evaporate/ui/ev/app/ev_library_empty.dart';
import 'package:evaporate/ui/ev/app/ev_library_search.dart';
import 'package:evaporate/ui/ev/widgets/ev_controls.dart';
import 'package:evaporate/ui/library/library_toolbar.dart';
import 'package:evaporate/ui/library/toolbar/library_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_app.dart';

void main() {
  final l = LRu();
  late Directory tmp;
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  Future<TestHarness> show(
    WidgetTester tester, {
    bool empty = false,
    Locale? locale,
  }) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (!empty) {
      harness.addGame(title: 'Alpha');
      harness.addGame(title: 'Beta');
    }
    await tester.pumpWidget(harness.buildApp(locale: locale));
    await tester.pumpAndSettle();
    return harness;
  }

  LibraryViewBloc view(WidgetTester tester) =>
      tester.element(find.byType(LibraryToolbar)).read<LibraryViewBloc>();
  Finder field() => find.descendant(
    of: find.byType(EvLibrarySearch),
    matching: find.byType(TextField),
  );

  testWidgets('сброс пустого поиска очищает поле и возвращает фокус', (
    tester,
  ) async {
    await show(tester);
    await tester.enterText(field(), 'missing');
    await tester.pumpAndSettle();
    expect(find.text(l.nothingFound), findsOneWidget);
    expect(find.byType(EvLibraryCard), findsNothing);
    final clear = find.descendant(
      of: find.byType(EvLibraryEmptyState),
      matching: find.widgetWithText(EvGhostButton, l.libraryClearSearch),
    );
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(view(tester).state.query, isEmpty);
    expect(tester.widget<TextField>(field()).controller!.text, isEmpty);
    expect(tester.widget<TextField>(field()).focusNode!.hasFocus, isTrue);
    expect(find.byType(EvLibraryCard), findsNWidgets(2));
  });

  testWidgets(
    'внешняя смена запроса доходит до поля, фильтры считают найденное',
    (tester) async {
      await show(tester);
      view(tester).add(const LibraryQueryChanged('Beta'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field()).controller!.text, 'Beta');
      final all = find.widgetWithText(TextButton, l.tabAll);
      expect(
        find.descendant(of: all, matching: find.text('1')),
        findsOneWidget,
      );
      expect(find.byType(EvLibraryCard), findsOneWidget);
      view(tester).add(const LibraryQueryChanged(''));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field()).controller!.text, isEmpty);
      expect(find.byType(EvLibraryCard), findsNWidgets(2));
    },
  );

  testWidgets('пустой фильтр возвращается ко всем играм без добавления', (
    tester,
  ) async {
    await show(tester);
    view(tester).add(const LibraryShelfSelected(Shelf.recent));
    await tester.pumpAndSettle();
    expect(find.text(l.shelfRecentEmpty), findsOneWidget);
    expect(find.text(l.libraryDropHint), findsNothing);
    final reset = find.widgetWithText(EvGhostButton, l.libraryResetFilters);
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(view(tester).state.shelf, Shelf.all);
    expect(find.byType(EvLibraryCard), findsNWidgets(2));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'Escape закрывает меню добавления и сохраняет возможность повторного открытия',
    (tester) async {
      await show(tester);
      final button = find.descendant(
        of: find.byType(EvLibraryAddMenu),
        matching: find.byType(EvGhostButton),
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final focus = tester.widget<EvGhostButton>(button).focusNode!;
      focus.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNWidgets(2));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNWidgets(2));
    },
  );

  testWidgets(
    'английская пустая библиотека содержит только подключённые подсказки',
    (tester) async {
      final en = LEn();
      await show(tester, empty: true, locale: const Locale('en'));
      expect(find.text(en.libraryEmpty), findsOneWidget);
      expect(find.text(en.libraryDropHint), findsOneWidget);
      expect(find.text('Ctrl+O'), findsNothing);
      expect(find.text('Ctrl+V'), findsNothing);
      expect(find.text('Ни одной игры'), findsNothing);
      expect(find.text('Вставить magnet-ссылку'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Ctrl+F и Enter ведут от панели к выбранной карточке', (
    tester,
  ) async {
    final harness = await show(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LibrarySearchField>(find.byType(LibrarySearchField))
          .focusNode
          .hasFocus,
      isTrue,
    );
    await tester.enterText(field(), 'Beta');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final beta = harness.library.state.games.firstWhere(
      (game) => game.title == 'Beta',
    );
    expect(primaryFocus!.debugLabel, 'game:${beta.id}');
    expect(harness.nav.state.selectedGameId, beta.id);
    expect(harness.nav.state.openedGameId, isNull);
  });
}

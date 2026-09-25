import 'dart:io';

import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// Добавление игры — единственный вход в приложение: каталога содержимого
/// здесь нет, и всё, что попадает в библиотеку, проходит через этот диалог.
void main() {
  // Ищем по ключу перевода, а не по строке: правка формулировки в
  // ARB иначе роняет тест, ничего не сломав в приложении.
  final l = LRu();

  late Directory tmp;

  setUp(() async {
    tmp = await TestHarness.makeTempDir();
  });

  tearDown(() => TestHarness.removeTempDir(tmp));

  /// Пустая библиотека с открытым диалогом добавления.
  Future<TestHarness> withDialog(WidgetTester tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Magnet, .torrent или папка…'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    return harness;
  }

  Finder fieldWithLabel(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
    await tester.pumpAndSettle();
  }

  testWidgets('magnet-ссылка становится игрой в библиотеке', (tester) async {
    final harness = await withDialog(tester);

    await tester.enterText(
      fieldWithLabel('Magnet-ссылка'),
      'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
    );
    await tester.enterText(fieldWithLabel('Название'), 'Тихая гавань');
    await submit(tester);

    expect(find.byType(AlertDialog), findsNothing);
    final games = harness.library.state.games;
    expect(games, hasLength(1));
    expect(games.single.title, 'Тихая гавань');
    expect(games.single.download.source?.kind, GameSourceKind.magnet);
    expect(games.single.status, GameStatus.notInstalled);
  });

  // Имя раздачи лежит в параметре `dn`, и переписывать его руками — работа,
  // которую приложение обязано сделать за человека.
  testWidgets('название подставляется из dn, пока поле пустое', (tester) async {
    await withDialog(tester);

    await tester.enterText(
      fieldWithLabel('Magnet-ссылка'),
      'magnet:?xt=urn:btih:abc&dn=Hollow+Knight+Silksong',
    );
    await tester.pump();

    expect(find.text('Hollow Knight Silksong'), findsOneWidget);
  });

  testWidgets('своё название важнее того, что пришло в ссылке', (tester) async {
    final harness = await withDialog(tester);

    await tester.enterText(fieldWithLabel('Название'), 'Как я назвал сам');
    await tester.enterText(
      fieldWithLabel('Magnet-ссылка'),
      'magnet:?xt=urn:btih:abc&dn=Release.Name.From.Tracker',
    );
    await tester.pump();
    await submit(tester);

    expect(harness.library.state.games.single.title, 'Как я назвал сам');
  });

  testWidgets('ссылка без dn даёт игре имя по умолчанию', (tester) async {
    final harness = await withDialog(tester);

    await tester.enterText(fieldWithLabel('Magnet-ссылка'), 'magnet:?xt=btih');
    await submit(tester);

    expect(harness.library.state.games.single.title, 'Новая игра');
  });

  // Диалог, который молча закрывается на мусорном вводе, оставляет человека
  // гадать, добавилась игра или нет.
  testWidgets('чужая ссылка не закрывает диалог и объясняет причину', (
    tester,
  ) async {
    final harness = await withDialog(tester);

    await tester.enterText(
      fieldWithLabel('Magnet-ссылка'),
      'https://example.com/game.torrent',
    );
    await submit(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l.badMagnet), findsOneWidget);
    expect(harness.library.state.games, isEmpty);
  });

  testWidgets('пустая ссылка тоже считается неверной', (tester) async {
    final harness = await withDialog(tester);

    await submit(tester);

    expect(find.text(l.badMagnet), findsOneWidget);
    expect(harness.library.state.games, isEmpty);
  });

  testWidgets('без выбранного .torrent игра не заводится', (tester) async {
    final harness = await withDialog(tester);

    await tester.tap(find.text('.torrent'));
    await tester.pumpAndSettle();
    await submit(tester);

    expect(find.text(l.pickTorrent), findsOneWidget);
    expect(harness.library.state.games, isEmpty);
  });

  testWidgets('без выбранной папки игра не заводится', (tester) async {
    final harness = await withDialog(tester);

    await tester.tap(find.text(l.sourceFolder));
    await tester.pumpAndSettle();
    await submit(tester);

    expect(find.text(l.pickFolder), findsOneWidget);
    expect(harness.library.state.games, isEmpty);
  });

  // У локальной папки качать нечего, и галочка о загрузке для неё бессмысленна.
  testWidgets('для локальной папки о загрузке не спрашивают', (tester) async {
    await withDialog(tester);
    expect(find.text(l.startDownloadNow), findsOneWidget);

    await tester.tap(find.text(l.sourceFolder));
    await tester.pumpAndSettle();

    expect(find.text(l.startDownloadNow), findsNothing);
  });

  // Движок в тестовой сборке не поднимался. Галочка при этом обязана
  // погаснуть и сказать почему — иначе человек ждёт загрузку, которой нет.
  testWidgets('пока движок не готов, загрузку начать не предлагают', (
    tester,
  ) async {
    await withDialog(tester);

    final checkbox = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Начать загрузку сразу'),
    );

    expect(checkbox.onChanged, isNull);
    expect(checkbox.value, isFalse);
    expect(find.textContaining('Движок загрузок недоступен'), findsOneWidget);
  });

  testWidgets('отмена закрывает диалог, ничего не добавив', (tester) async {
    final harness = await withDialog(tester);

    await tester.enterText(fieldWithLabel('Magnet-ссылка'), 'magnet:?xt=btih');
    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(harness.library.state.games, isEmpty);
  });
}

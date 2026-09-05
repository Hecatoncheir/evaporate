import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/game_cover.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// Управление здесь специально сделано полностью клавиатурным и геймпадным,
/// а контраст каждого цвета выверен тестом по WCAG. Экранному диктору при
/// этом объявить было нечего: сетку читают по картинкам, и текста в плитке
/// с обложкой нет вовсе.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await TestHarness.makeTempDir();
  });

  tearDown(() => TestHarness.removeTempDir(tmp));

  /// Подписи всех узлов, попавших в дерево доступности.
  ///
  /// Через `find.bySemanticsLabel` такое не проверить: нам нужен не поиск
  /// известной подписи, а то, что подписи вообще есть и как они звучат.
  List<String> spokenLabels(WidgetTester tester) {
    final labels = <String>[];
    void walk(SemanticsNode node) {
      if (node.label.isNotEmpty) labels.add(node.label);
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(tester.binding.rootElement!.renderObject!.debugSemantics!);
    return labels;
  }

  testWidgets('плитка игры называет себя и своё состояние', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(title: 'Тихая гавань', status: GameStatus.installed);
    harness.addGame(title: 'Долгая дорога');
    await harness.pump(tester);

    final labels = spokenLabels(tester);
    expect(
      labels.any(
        (l) => l.contains('Тихая гавань') && l.contains('Установлена'),
      ),
      isTrue,
      reason: 'подпись плитки: $labels',
    );
    expect(
      labels.any(
        (l) => l.contains('Долгая дорога') && l.contains('Не установлена'),
      ),
      isTrue,
    );
    handle.dispose();
  });

  // Плитка объявляется одной фразой: название, состояние и значок тремя
  // объявлениями подряд читать невозможно.
  testWidgets('плитка объявляется одним узлом, а не россыпью', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(title: 'Одинокая', status: GameStatus.installed);
    await harness.pump(tester);

    final about = spokenLabels(tester)
        .where((l) => l.contains('Одинокая'))
        .toList();

    expect(about, hasLength(1));
    handle.dispose();
  });

  testWidgets('плитка объявляет себя кнопкой', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(title: 'Нажимаемая', status: GameStatus.installed);
    await harness.pump(tester);

    expect(
      tester.getSemantics(find.byType(GameCoverTile)),
      matchesSemantics(
        label: 'Нажимаемая, Установлена',
        isButton: true,
        // Действия обязаны пережить подпись: обёртка, скрывающая лишние
        // объявления, легко уносит вместе с ними и нажатие.
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('открытая игра не теряет подписи разделов', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    final id = harness.addGame(title: 'Открытая', status: GameStatus.installed);
    await harness.pump(tester);

    harness.nav.add(GameOpened(id));
    await tester.pumpAndSettle();

    final labels = spokenLabels(tester);
    expect(labels.any((l) => l.contains('Папки сохранений')), isTrue);
    handle.dispose();
  });
}

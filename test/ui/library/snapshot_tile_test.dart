import 'package:evaporate/core/format.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:evaporate/ui/library/saves/snapshot_tile.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Плитка снимка сохранений на странице игры.
///
/// Три действия у неё безвозвратные в разной степени, и самое опасное —
/// удаление. Спрашивает о нём вызывающий, а плитка отвечает за другое: что
/// клавиши на месте, подписаны и зовут каждая своё. Перепутай их местами —
/// подтверждение спросят об одном, а сделают другое.
void main() {
  // Ищем по ключу перевода, а не по строке: правка формулировки в
  // ARB иначе роняет тест, ничего не сломав в приложении.
  final l = LRu();

  final snapshot = SaveSnapshot(
    id: 's1',
    gameId: 'g1',
    gameTitle: 'Игра',
    createdAt: DateTime(2026, 9, 14, 3, 20),
    deviceName: 'Cougar',
    platform: currentPlatformKey(),
    sizeBytes: 140 * 1024 * 1024,
    fileCount: 128,
    archivePath: '',
    rules: const [],
  );

  var restored = 0;
  var exported = 0;
  var deleted = 0;

  setUp(() => restored = exported = deleted = 0);

  Future<void> show(WidgetTester tester) => tester.pumpWidget(
    hostWidget(
      SnapshotTile(
        snapshot: snapshot,
        onRestore: () => restored++,
        onExport: () => exported++,
        onDelete: () => deleted++,
      ),
    ),
  );

  testWidgets('снимок называет себя датой, устройством и объёмом', (
    tester,
  ) async {
    await show(tester);

    expect(find.text(formatDateTime(snapshot.createdAt)), findsOneWidget);
    expect(find.text(l.originManual), findsOneWidget);
    expect(find.textContaining('Cougar'), findsOneWidget);
    expect(find.textContaining('128 файлов'), findsOneWidget);
    expect(find.textContaining('140.0 MB'), findsOneWidget);
  });

  testWidgets('все три действия на месте и подписаны', (tester) async {
    await show(tester);

    expect(find.byTooltip('Восстановить'), findsOneWidget);
    expect(find.byTooltip('Экспортировать файл'), findsOneWidget);
    expect(find.byTooltip('Удалить'), findsOneWidget);
  });

  testWidgets('каждая клавиша зовёт своё и только своё', (tester) async {
    await show(tester);

    await tester.tap(find.byTooltip('Восстановить'));
    expect([restored, exported, deleted], [1, 0, 0]);

    await tester.tap(find.byTooltip('Экспортировать файл'));
    expect([restored, exported, deleted], [1, 1, 0]);

    await tester.tap(find.byTooltip('Удалить'));
    expect([restored, exported, deleted], [1, 1, 1]);
  });

  /// Подписи всех узлов дерева доступности — тем же обходом, что и в
  /// `semantics_test.dart`: нужен не поиск известной подписи, а то, как
  /// плитка звучит целиком.
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

  // Дата, источник, размер и число файлов лежат отдельными подписями, и
  // диктор читал бы их четырьмя объявлениями подряд. А вот клавиши обязаны
  // остаться своими: до них надо доходить и нажимать по отдельности.
  testWidgets('диктору плитка идёт одной фразой, а клавиши — врозь', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await show(tester);

    // Ровно одна подпись, и ровно та: подписи внутри плитки повторяли бы
    // уже сказанное, а `contains` этого не заметил бы.
    expect(spokenLabels(tester), [
      'Снимок от ${formatDateTime(snapshot.createdAt)}, Вручную, файлов: 128',
    ]);

    // А действия обязаны пережить это сокращение: обёртка, скрывающая
    // лишние объявления, легко уносит вместе с ними и нажатие.
    for (final tooltip in const [
      'Восстановить',
      'Экспортировать файл',
      'Удалить',
    ]) {
      final data = tester
          .getSemantics(find.byTooltip(tooltip))
          .getSemanticsData();
      expect(data.tooltip, tooltip, reason: tooltip);
      expect(data.hasAction(SemanticsAction.tap), isTrue, reason: tooltip);
    }

    handle.dispose();
  });
}

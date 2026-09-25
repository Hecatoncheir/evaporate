import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:evaporate/ui/saves/snapshot_history.dart';
import 'package:evaporate/ui/saves/snapshot_row.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Хронология снимков на экране сохранений.
void main() {
  final l = LRu();

  List<SnapshotEntry> entries(int count) {
    final start = DateTime(2026, 9, 1);
    return [
      for (var i = 0; i < count; i++)
        (
          Game(id: 'g$i', title: 'Игра $i', addedAt: start),
          SaveSnapshot(
            id: 's$i',
            gameId: 'g$i',
            gameTitle: 'Игра $i',
            createdAt: start.subtract(Duration(hours: i)),
            deviceName: 'стол',
            platform: 'windows',
            sizeBytes: 1024,
            archivePath: '',
            rules: const [],
          ),
        ),
    ];
  }

  Widget page(List<SnapshotEntry> list, {ThemeData? theme}) => hostWidget(
    CustomScrollView(slivers: [SnapshotHistory(entries: list)]),
    theme: theme,
  );

  // Лента — то же стекло, что соседние карточки, только сливером: фильтр у
  // неё обязан быть тот же, из темы схемы, а не своё число размытия.
  testWidgets('лента берёт фильтр стекла своей схемы', (tester) async {
    for (final (theme, glass) in [
      (EvaporateTheme.dark(), GlassSurfaceTheme.arclight),
      (EvaporateTheme.light(), GlassSurfaceTheme.cartridge),
    ]) {
      await tester.pumpWidget(page(entries(3), theme: theme));
      await tester.pumpAndSettle();

      expect(
        tester.layers.whereType<BackdropFilterLayer>().single.filter,
        GlassSurface.filterOf(glass),
      );
    }
  });

  // Снимков по двадцать на игру: у сложившейся библиотеки строк сотни, а
  // видно полтора десятка. Прежде `Column` строила их все на каждую
  // пересборку экрана.
  testWidgets('строки строятся по мере прокрутки, а не все разом', (
    tester,
  ) async {
    await tester.pumpWidget(page(entries(300)));

    final built = find
        .byType(SnapshotRow, skipOffstage: false)
        .evaluate()
        .length;
    expect(built, inInclusiveRange(1, 40));

    await tester.dragUntilVisible(
      find.text('Игра 299'),
      find.byType(CustomScrollView),
      const Offset(0, -2000),
    );
    expect(find.text('Игра 299'), findsOneWidget);
  });

  testWidgets('заголовок называет число снимков, пустой список — словами', (
    tester,
  ) async {
    await tester.pumpWidget(page(entries(3)));
    expect(find.text(l.allSnapshots), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(SnapshotRow), findsNWidgets(3));

    await tester.pumpWidget(page(const []));
    expect(find.text(l.noSnapshotsYet), findsOneWidget);
    expect(find.byType(SnapshotRow), findsNothing);
  });
}

import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/ui/downloads/task_stats.dart';
import 'package:evaporate/ui/labels.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Показания под ходом загрузки — одни на карточке загрузки и на странице
/// игры. Прежде у страницы была своя копия без отданного, и вклад в
/// раздачу там не показывался вовсе.
void main() {
  final l = LRu();

  testWidgets('рядом с остатком времени видно и отданное', (tester) async {
    const task = DownloadTask(
      id: 't',
      name: 'Игра',
      state: DownloadState.active,
      totalBytes: 1000,
      completedBytes: 400,
      uploadedBytes: 200,
      downloadSpeed: 100,
      connections: 7,
      seeders: 3,
    );

    await tester.pumpWidget(hostWidget(const TaskStats(task: task)));

    expect(find.text(l.etaLeft(formatEtaLabel(l, 6))), findsOneWidget);
    expect(find.text(l.peersCount(7)), findsOneWidget);
    expect(find.text(l.seedsCount(3)), findsOneWidget);
    expect(find.text(l.uploadedTotal(bytesLabel(l, 200))), findsOneWidget);
    expect(find.text(l.ratioValue('0.50')), findsOneWidget);
  });

  testWidgets('без метаданных остатка времени нет', (tester) async {
    const task = DownloadTask(
      id: 't',
      name: 'Игра',
      state: DownloadState.active,
      isMetadata: true,
      downloadSpeed: 100,
      totalBytes: 1000,
    );

    await tester.pumpWidget(hostWidget(const TaskStats(task: task)));

    expect(find.textContaining(l.etaLeft('')), findsNothing);
    expect(find.text(l.peersCount(0)), findsOneWidget);
  });
}

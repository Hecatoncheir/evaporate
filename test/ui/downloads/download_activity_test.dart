import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/ui/downloads/download_activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/download_history.dart';
import '../../support/host_widget.dart';

void main() {
  Widget app(DownloadTask task) => hostWidget(
    SizedBox(
      width: 720,
      // История одна на приложение: график и показания читают её сообща.
      child: withHistory(DownloadActivity(task: task), [task]),
    ),
  );

  testWidgets('панель загрузки показывает график и четыре показателя', (
    tester,
  ) async {
    const task = DownloadTask(
      id: 'one',
      name: 'Игра',
      state: DownloadState.active,
      totalBytes: 1024 * 1024 * 100,
      completedBytes: 1024 * 1024 * 42,
      downloadSpeed: 1024 * 1024 * 8,
      uploadSpeed: 1024 * 256,
    );

    await tester.pumpWidget(app(task));

    expect(find.text('СЕТЬ'), findsOneWidget);
    expect(find.text('ПИК'), findsOneWidget);
    expect(find.text('ДИСК'), findsOneWidget);
    expect(find.text('ОТДАЧА'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('42%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('панель не переполняется в узком окне', (tester) async {
    const task = DownloadTask(
      id: 'narrow',
      name: 'Игра',
      state: DownloadState.active,
      totalBytes: 1000,
      completedBytes: 500,
      downloadSpeed: 400,
    );

    await tester.pumpWidget(
      hostWidget(
        SizedBox(
          width: 300,
          child: withHistory(const DownloadActivity(task: task), [task]),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

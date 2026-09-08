import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/ui/downloads/download_activity.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(DownloadTask task) => MaterialApp(
    theme: EvaporateTheme.dark(),
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    locale: const Locale('ru'),
    home: Scaffold(
      body: SizedBox(width: 720, child: DownloadActivity(task: task)),
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
      MaterialApp(
        theme: EvaporateTheme.dark(),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        locale: const Locale('ru'),
        home: const Scaffold(
          body: SizedBox(width: 300, child: DownloadActivity(task: task)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/downloads/download_activity.dart';
import 'package:evaporate/ui/library/detail/downloading_header.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// Заголовок качающейся игры лежит поверх её же графика: страница отвечает
/// на «как идёт вот эта игра» одним взглядом.
void main() {
  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  const task = DownloadTask(
    id: 't1',
    name: 'Качается',
    state: DownloadState.active,
    totalBytes: 1000,
    completedBytes: 400,
    downloadSpeed: 5,
  );

  Future<void> show(WidgetTester tester, {String? description}) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

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
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: DownloadHistoryScope(
                task: task,
                child: DownloadingHeader(
                  game: Game(
                    id: 'g1',
                    title: 'Принц Персии',
                    addedAt: DateTime.now(),
                    description: description,
                    status: GameStatus.downloading,
                  ),
                  task: task,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('название лежит поверх графика, а не под ним', (tester) async {
    await show(tester);

    final chart = tester.getRect(find.byType(DownloadChart));
    final title = tester.getRect(find.text('Принц Персии'));

    expect(find.byType(DownloadChart), findsOneWidget);
    // Пересекаются по вертикали — значит, одно поверх другого, а не одно
    // под другим.
    expect(
      title.top < chart.bottom && title.bottom > chart.top,
      isTrue,
      reason: 'заголовок и график должны занимать одно место на экране',
    );
  });

  // Высоту задаёт заголовок, а не график: иначе короткое описание
  // оставляло бы под собой пустую полосу, а длинное обрезало бы подложку.
  testWidgets('подложка занимает ровно блок заголовка', (tester) async {
    await show(
      tester,
      description:
          'Отправьтесь навстречу приключениям в захватывающем платформере, '
          'действие которого разворачивается в мифологическом мире Персии.',
    );

    final block = tester.getRect(find.byType(DownloadingHeader));
    final chart = tester.getRect(find.byType(DownloadChart));

    expect(chart.height, closeTo(block.height, 1));
    expect(chart.width, closeTo(block.width, 1));
  });

  testWidgets('график остаётся фоном: числа читают не по нему', (tester) async {
    await show(tester);

    // Показания живут ниже, у клавиш. Здесь — только подложка.
    expect(find.textContaining('Б/с'), findsNothing);
    expect(find.byType(Opacity), findsWidgets);
  });
}

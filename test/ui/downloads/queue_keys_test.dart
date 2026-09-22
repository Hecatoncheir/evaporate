import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/ui/downloads/queue_list.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// Очередь переставляется и без мыши.
///
/// Прежде порядок меняло только перетаскивание, и с клавиатуры и
/// геймпада очередь было не переставить вовсе. Клавиши «выше» и «ниже»
/// стоят на карточке, и до них доходит обычный обход фокуса.
void main() {
  final l = LRu();
  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  DownloadTask waiting(String id) =>
      DownloadTask(id: id, name: id, state: DownloadState.waiting);

  testWidgets('клавиши ставят задачу перед нужным соседом', (tester) async {
    // Наблюдатель — до блоков: блок запоминает его при создании.
    final moves = <DownloadReordered>[];
    final previous = Bloc.observer;
    Bloc.observer = _Recording(moves);
    addTearDown(() => Bloc.observer = previous);
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: harness.library),
          BlocProvider.value(value: harness.downloads),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          locale: const Locale('ru'),
          theme: EvaporateTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: QueueList(
                queued: [waiting('a'), waiting('b'), waiting('c')],
                library: harness.library.state,
              ),
            ),
          ),
        ),
      ),
    );

    final downs = find.byTooltip(l.queueMoveDown);
    final ups = find.byTooltip(l.queueMoveUp);
    await tester.tap(downs.first);
    await tester.tap(ups.last);
    await tester.pump();

    expect(moves.map((m) => (m.id, m.beforeId)), [
      ('a', 'c'),
      ('c', 'b'),
    ], reason: '«ниже» — перед тем, кто через одного; «выше» — перед соседом');
  });
}

class _Recording extends BlocObserver {
  _Recording(this.moves);

  final List<DownloadReordered> moves;

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (event is DownloadReordered) moves.add(event);
  }
}

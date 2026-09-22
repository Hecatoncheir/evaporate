import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/ui/downloads/downloads_status_bar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// Скрытый раздел не перестраивается от чужих перемен.
///
/// Разделы живут в `IndexedStack` все разом, и загрузки, подписанные на
/// состояние целиком, перестраивались каждую секунду — на каждый снимок
/// задач от движка, — пока человек смотрел в библиотеку.
void main() {
  late Directory tmp;
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  testWidgets('скрытые загрузки не перестраиваются, показанные — свежие', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);
    final bar = find.byType(DownloadsStatusBar, skipOffstage: false);
    final before = tester.widget<DownloadsStatusBar>(bar);

    harness.downloads.add(
      const EngineTasksChanged([
        DownloadTask(id: 't', name: 'Игра', state: DownloadState.waiting),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<DownloadsStatusBar>(bar),
      same(before),
      reason: 'скрытый раздел перестроился от снимка задач',
    );

    harness.nav.add(const SectionSelected(AppSection.downloads));
    // Кадрами, а не `pumpAndSettle`: у показанных загрузок живые
    // украшения, и покоя там не бывает.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final shown = tester.widget<DownloadsStatusBar>(bar);
    expect(shown, isNot(same(before)));
    // Число — то, что лежит в блоке сейчас: движок обвязки настоящий и
    // свой снимок задач присылает сам.
    expect(
      shown.queued,
      harness.downloads.state.queued.length,
      reason: 'показанный раздел обязан видеть свежее',
    );
  });
}

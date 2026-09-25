import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/cover/cover_progress_strip.dart';
import 'package:evaporate/ui/library/cover/cover_status_badge.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/animated_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Что плитка говорит поверх обложки: значок состояния и полоса загрузки.
void main() {
  Future<EvaporatePalette> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      hostWidget(SizedBox.square(dimension: 200, child: child)),
    );
    return tester.element(find.byWidget(child)).colors;
  }

  Color badgeTone(WidgetTester tester) =>
      tester.widget<Icon>(find.byType(Icon)).color!;

  // Запущенная и установленная были одного цвета, и идущую игру в сетке
  // было не отличить.
  testWidgets('запущенная игра горит не тем тоном, что установленная', (
    tester,
  ) async {
    Game game(GameStatus status) =>
        Game(id: 'g', title: 'Игра', addedAt: DateTime(2026), status: status);

    final colors = await pump(
      tester,
      CoverStatusBadge(game: game(GameStatus.running)),
    );
    expect(badgeTone(tester), colors.primary);

    await pump(tester, CoverStatusBadge(game: game(GameStatus.installed)));
    expect(badgeTone(tester), colors.accent);

    await pump(tester, CoverStatusBadge(game: game(GameStatus.error)));
    expect(badgeTone(tester), colors.danger);
  });

  // Идущая загрузка, вставшая и сорвавшаяся выглядели одинаково: полоса
  // была одного огня, и отличала их только подпись.
  testWidgets('полоса загрузки — в цвете состояния задачи', (tester) async {
    Future<Color?> fill(DownloadState state) async {
      await pump(
        tester,
        CoverProgressStrip(
          task: DownloadTask(
            id: 't',
            name: 'Игра',
            state: state,
            totalBytes: 100,
            completedBytes: 40,
          ),
        ),
      );
      return tester
          .widget<AnimatedProgress>(find.byType(AnimatedProgress))
          .color;
    }

    final colors = await pump(tester, const SizedBox());
    expect(await fill(DownloadState.active), colors.accentFill);
    expect(await fill(DownloadState.paused), colors.warning);
    expect(await fill(DownloadState.error), colors.dangerFill);
    final waiting = await fill(DownloadState.waiting);
    expect(waiting, isNot(colors.accentFill));
    await tester.pump(const Duration(seconds: 1));
  });
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evaporate/bloc/download_history/download_history_bloc.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/ui/downloads/download_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// График скоростей.
///
/// Проверяется по нарисованному: столбцы сети однажды уже были на месте в
/// коде и высотой в шесть десятых пикселя на экране — общая с диском шкала
/// прижимала их к самому низу, и человек видел точки вместо графика.
void main() {
  const task = DownloadTask(
    id: 't1',
    name: 'debian.iso',
    state: DownloadState.active,
    totalBytes: 756000000,
    completedBytes: 253500000,
    downloadSpeed: 67,
  );

  /// Рисует график по готовой истории и меряет, насколько высоко от низа
  /// поднимается закрашенное в каждой колонке.
  Future<List<int>> heights(
    WidgetTester tester,
    List<SpeedSample> history,
  ) async {
    final bloc = _Prepared(history);
    addTearDown(bloc.close);

    final key = GlobalKey();
    await tester.pumpWidget(
      hostWidget(
        BlocProvider<DownloadHistoryBloc>.value(
          value: bloc,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: const SizedBox(
                width: 600,
                child: DownloadChart(task: task),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    late Uint8List bytes;
    late int w, h;
    await tester.runAsync(() async {
      final render =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      w = image.width;
      h = image.height;
      bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      image.dispose();
    });

    // Прозрачное даёт нули; всё закрашенное — нет.
    bool painted(int x, int y) {
      final i = (y * w + x) * 4;
      return bytes[i] != 0 || bytes[i + 1] != 0 || bytes[i + 2] != 0;
    }

    return [
      for (var x = 0; x < w; x++)
        () {
          // Идём снизу, пока закрашено подряд: так меряется именно столбец,
          // а не случайно задетая линия сетки выше.
          var up = 0;
          for (var y = h - 1; y >= 0 && painted(x, y); y--) {
            up++;
          }
          return up;
        }(),
    ];
  }

  // Движок сообщает скачанное рывками, и посчитанная из них скорость диска
  // то ноль, то всплеск во много раз выше сетевой. Задавать им общую шкалу
  // значит отдать весь график одному случайному всплеску.
  testWidgets('всплеск диска не давит столбцы сети', (tester) async {
    final bars = await heights(tester, [
      for (var i = 0; i < 30; i++)
        SpeedSample(download: 67, disk: i == 12 ? 12100 : 0),
    ]);

    expect(
      bars.reduce((a, b) => a > b ? a : b),
      greaterThan(40),
      reason: 'при ровной сети столбцы обязаны занимать высоту графика',
    );
  });

  testWidgets('столбцы растут вслед за скоростью сети', (tester) async {
    final bars = await heights(tester, [
      for (var i = 0; i < 30; i++)
        SpeedSample(download: i < 15 ? 100 : 1000, disk: 0),
    ]);

    // Слева вчетверо медленнее — и столбцы там заметно ниже.
    final left = bars.take(bars.length ~/ 2).reduce((a, b) => a > b ? a : b);
    final right = bars.skip(bars.length ~/ 2).reduce((a, b) => a > b ? a : b);
    expect(right, greaterThan(left * 2));
  });

  testWidgets('на пустой истории график не падает и столбцов не рисует', (
    tester,
  ) async {
    final bars = await heights(tester, const []);

    // Совсем ничего не нарисовать нельзя: рисовальщик подставляет одну
    // нулевую выборку, и круглый торец мазка оставляет от неё точку у
    // самого низа. Столбцов при этом быть не должно.
    expect(bars.every((up) => up < 6), isTrue);
    expect(tester.takeException(), isNull);
  });
}

/// История, поданная целиком: строить её выборка за выборкой значило бы
/// подделывать ещё и время между ними.
class _Prepared extends DownloadHistoryBloc {
  _Prepared(List<SpeedSample> history)
    : super(
        const DownloadTask(id: 't', name: 'n', state: DownloadState.active),
      ) {
    emit(DownloadSpeedHistory(samples: history));
  }
}

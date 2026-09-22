import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/download_history/download_history_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../labels.dart';
import '../theme.dart';

/// Один только график — без показаний вокруг.
///
/// Нужен странице игры: там он ложится подложкой под обложку, название и
/// описание. Точные числа по нему не читают, он отвечает на вопрос «идёт ли
/// и ровно ли идёт», и от фона этого довольно.
class DownloadChart extends StatelessWidget {
  const DownloadChart({super.key, required this.task, this.height = 116});

  final DownloadTask task;

  /// `null` — занять всё, что дали. Так график становится подложкой под
  /// заголовком страницы игры, высоту которой задаёт текст, а не он.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Semantics(
      label: l.speedChart,
      value: speedLabel(l, task.downloadSpeed),
      image: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child:
            BlocSelector<
              DownloadHistoryBloc,
              DownloadHistories,
              DownloadSpeedHistory
            >(
              selector: (histories) => histories.of(task.id),
              builder: (context, history) => CustomPaint(
                painter: _SpeedChartPainter(
                  samples: history.samples,
                  networkColor: context.colors.primary,
                  diskColor: context.colors.accent,
                  gridColor: context.colors.outline,
                ),
              ),
            ),
      ),
    );
  }
}

class _SpeedChartPainter extends CustomPainter {
  const _SpeedChartPainter({
    required this.samples,
    required this.networkColor,
    required this.diskColor,
    required this.gridColor,
  });

  final List<SpeedSample> samples;
  final Color networkColor;
  final Color diskColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _drawGrid(canvas, size);

    final values = samples.isEmpty
        ? const [SpeedSample(download: 0, disk: 0)]
        : samples;
    // Шкалу задаёт **только сеть**. Общая на два ряда губила то, ради чего
    // график и нужен: движок сообщает скачанное рывками, и посчитанная из
    // них скорость диска то ноль, то всплеск в сотню раз выше сетевой.
    // Один такой всплеск прижимал ровные 67 Б/с сети к шести десятым
    // пикселя — столбцы превращались в точки у самого низа.
    //
    // Линия диска остаётся на той же шкале и при всплеске упирается в
    // верх: это читается как «диск успевает с запасом», а больше от неё
    // здесь ничего и не спрашивают — точные числа стоят рядом показанием.
    var maximum = 1;
    for (final sample in values) {
      if (sample.download > maximum) maximum = sample.download;
    }

    _drawBars(canvas, size, values, maximum);
    _drawDiskLine(canvas, size, values, maximum);
  }

  /// Где стоит выборка [i] из [count].
  ///
  /// Свежее прижато к правому краю: пока минута не набралась, слева
  /// остаётся пустота, а не растянутые на всю ширину три столбца.
  static double _x(Size size, int count, int i) =>
      (DownloadHistoryBloc.length - count + i + 0.5) *
      (size.width / DownloadHistoryBloc.length);

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor.withValues(alpha: 0.42)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  /// Сеть — столбцами: рывок в ней виден сам по себе.
  void _drawBars(
    Canvas canvas,
    Size size,
    List<SpeedSample> values,
    int maximum,
  ) {
    final slot = size.width / DownloadHistoryBloc.length;
    final paint = Paint()
      ..color = networkColor.withValues(alpha: 0.62)
      ..strokeWidth = (slot * 0.62).clamp(1.0, 5.0)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < values.length; i++) {
      final height = values[i].download / maximum * (size.height - 4);
      final x = _x(size, values.length, i);
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - height),
        paint,
      );
    }
  }

  /// Диск — линией поверх столбцов, и только когда точек больше одной:
  /// линия из одной точки не рисуется ничем.
  void _drawDiskLine(
    Canvas canvas,
    Size size,
    List<SpeedSample> values,
    int maximum,
  ) {
    if (values.length < 2) return;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = _x(size, values.length, i);
      final y = (size.height - values[i].disk / maximum * (size.height - 4))
          .clamp(2.0, size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = diskColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedChartPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.networkColor != networkColor ||
      oldDelegate.diskColor != diskColor ||
      oldDelegate.gridColor != gridColor;
}

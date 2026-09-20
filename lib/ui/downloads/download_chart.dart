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
        child: BlocBuilder<DownloadHistoryBloc, DownloadSpeedHistory>(
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
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.42)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

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

    final slot = size.width / DownloadHistoryBloc.length;
    final barPaint = Paint()
      ..color = networkColor.withValues(alpha: 0.62)
      ..strokeWidth = (slot * 0.62).clamp(1.0, 5.0)
      ..strokeCap = StrokeCap.round;
    final offset = DownloadHistoryBloc.length - values.length;
    for (var i = 0; i < values.length; i++) {
      final height = values[i].download / maximum * (size.height - 4);
      final x = (offset + i + 0.5) * slot;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - height),
        barPaint,
      );
    }

    if (values.length < 2) return;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (offset + i + 0.5) * slot;
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

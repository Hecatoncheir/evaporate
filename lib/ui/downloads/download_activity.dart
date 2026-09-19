import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/download_history_cubit.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/animated_progress.dart';

/// Держит историю скоростей и кормит её задачей.
///
/// Внутрь ставят и график, и показания: на странице игры они разъезжаются
/// по разным местам — график ложится подложкой под обложку с названием, а
/// показания стоят у клавиш, — но история у них обязана быть одна.
class DownloadHistoryScope extends StatefulWidget {
  const DownloadHistoryScope({
    super.key,
    required this.task,
    required this.child,
  });

  final DownloadTask task;
  final Widget child;

  @override
  State<DownloadHistoryScope> createState() => _DownloadHistoryScopeState();
}

class _DownloadHistoryScopeState extends State<DownloadHistoryScope> {
  late final DownloadHistoryCubit _history = DownloadHistoryCubit(widget.task);

  @override
  void didUpdateWidget(covariant DownloadHistoryScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _history.sample(widget.task, oldWidget.task);
  }

  @override
  void dispose() {
    _history.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider.value(value: _history, child: widget.child);
}

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
        child: BlocBuilder<DownloadHistoryCubit, List<SpeedSample>>(
          builder: (context, history) => CustomPaint(
            painter: _SpeedChartPainter(
              samples: history,
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

/// Показания одной загрузки: скорость, пик, диск, отдача — и сколько
/// скачано из скольких.
///
/// График сюда входит не всегда: на странице игры он уехал подложкой под
/// заголовок, и рисовать его ещё раз здесь незачем.
class DownloadActivity extends StatelessWidget {
  const DownloadActivity({
    super.key,
    required this.task,
    this.showChart = true,
  });

  final DownloadTask task;
  final bool showChart;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Пока метаданных нет, размер раздачи неизвестен, и доля готовности
    // тоже: полоса в этом случае бежит без конца, а не стоит на нуле.
    final indeterminate = task.isMetadata || task.totalBytes == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metrics(context),
        if (showChart) ...[
          const SizedBox(height: 14),
          DownloadChart(task: task),
        ],
        const SizedBox(height: 14),
        _amounts(context, indeterminate: indeterminate),
        const SizedBox(height: 7),
        Semantics(
          value: indeterminate
              ? l.fetchingMetadata
              : percentLabel(l, task.progress),
          child: AnimatedProgress(
            value: indeterminate ? null : task.progress,
            height: 6,
            borderRadius: 4,
            busy: task.state == DownloadState.active,
          ),
        ),
      ],
    );
  }

  /// Четыре показания: сеть, её пик, диск и отдача.
  Widget _metrics(BuildContext context) {
    final l = L.of(context);
    // Историю читаем из общего Cubit: на странице игры по ней же рисуется
    // подложка под заголовком, и расходиться этим двум нельзя.
    final history = context.watch<DownloadHistoryCubit>();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Metric(
          icon: Icons.network_check_rounded,
          label: l.networkSpeed,
          value: speedLabel(l, task.downloadSpeed),
          color: context.colors.primary,
        ),
        _Metric(
          icon: Icons.speed_rounded,
          label: l.peakSpeed,
          value: speedLabel(l, history.peakOf(task)),
          color: context.colors.primary,
        ),
        _Metric(
          icon: Icons.storage_rounded,
          label: l.diskActivity,
          value: speedLabel(l, history.diskSpeed),
          color: context.colors.accent,
        ),
        _Metric(
          icon: Icons.upload_rounded,
          label: l.uploadSpeed,
          value: speedLabel(l, task.uploadSpeed),
          color: context.colors.textSecondary,
        ),
      ],
    );
  }

  /// Сколько скачано, сколько всего и какая доля готова.
  Widget _amounts(BuildContext context, {required bool indeterminate}) {
    final l = L.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            task.isMetadata
                ? l.fetchingMetadata
                : '${formatBytes(task.completedBytes)} / '
                      '${formatBytes(task.totalBytes)}',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (!indeterminate)
          Text(
            '${(task.progress * 100).round()}%',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 128),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: context.text.label),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: EvaporateTheme.monoFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
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

    final slot = size.width / DownloadHistoryCubit.length;
    final barPaint = Paint()
      ..color = networkColor.withValues(alpha: 0.62)
      ..strokeWidth = (slot * 0.62).clamp(1.0, 5.0)
      ..strokeCap = StrokeCap.round;
    final offset = DownloadHistoryCubit.length - values.length;
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

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/animated_progress.dart';

/// Живой график и основные показатели одной загрузки.
///
/// Движок присылает снимок примерно раз в секунду. История намеренно живёт
/// только в виджете: это данные для представления, их незачем сохранять между
/// запусками приложения или подмешивать в состояние самого торрент-клиента.
class DownloadActivity extends StatefulWidget {
  const DownloadActivity({super.key, required this.task});

  final DownloadTask task;

  @override
  State<DownloadActivity> createState() => _DownloadActivityState();
}

class _DownloadActivityState extends State<DownloadActivity> {
  static const _historyLength = 60;

  final List<_SpeedSample> _history = [];
  late DateTime _sampledAt;
  late int _completedBytes;

  @override
  void initState() {
    super.initState();
    _sampledAt = DateTime.now();
    _completedBytes = widget.task.completedBytes;
    _history.add(_SpeedSample(download: widget.task.downloadSpeed, disk: 0));
  }

  @override
  void didUpdateWidget(covariant DownloadActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    final task = widget.task;
    if (task.downloadSpeed == oldWidget.task.downloadSpeed &&
        task.completedBytes == oldWidget.task.completedBytes &&
        task.state == oldWidget.task.state) {
      return;
    }

    final now = DateTime.now();
    final elapsedUs = now.difference(_sampledAt).inMicroseconds;
    final delta = task.completedBytes - _completedBytes;
    final diskSpeed = elapsedUs <= 0 || delta <= 0
        ? 0
        : (delta * Duration.microsecondsPerSecond / elapsedUs).round();
    _history.add(
      _SpeedSample(
        download: task.state == DownloadState.paused ? 0 : task.downloadSpeed,
        disk: task.state == DownloadState.paused ? 0 : diskSpeed,
      ),
    );
    if (_history.length > _historyLength) _history.removeAt(0);
    _sampledAt = now;
    _completedBytes = task.completedBytes;
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final l = L.of(context);
    final indeterminate = task.isMetadata || task.totalBytes == 0;
    final peak = _history.fold<int>(
      task.downloadSpeed,
      (value, sample) => sample.download > value ? sample.download : value,
    );
    final disk = _history.last.disk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
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
              value: speedLabel(l, peak),
              color: context.colors.primary,
            ),
            _Metric(
              icon: Icons.storage_rounded,
              label: l.diskActivity,
              value: speedLabel(l, disk),
              color: context.colors.accent,
            ),
            _Metric(
              icon: Icons.upload_rounded,
              label: l.uploadSpeed,
              value: speedLabel(l, task.uploadSpeed),
              color: context.colors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Semantics(
          label: l.speedChart,
          value: speedLabel(l, task.downloadSpeed),
          image: true,
          child: SizedBox(
            height: 116,
            width: double.infinity,
            child: CustomPaint(
              painter: _SpeedChartPainter(
                samples: List.unmodifiable(_history),
                networkColor: context.colors.primary,
                diskColor: context.colors.accent,
                gridColor: context.colors.outline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
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
        ),
        const SizedBox(height: 7),
        Semantics(
          value: indeterminate
              ? l.fetchingMetadata
              : percentLabel(l, task.progress),
          child: AnimatedProgress(
            value: indeterminate ? null : task.progress,
            height: 6,
            borderRadius: 4,
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
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
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

class _SpeedSample {
  const _SpeedSample({required this.download, required this.disk});

  final int download;
  final int disk;
}

class _SpeedChartPainter extends CustomPainter {
  const _SpeedChartPainter({
    required this.samples,
    required this.networkColor,
    required this.diskColor,
    required this.gridColor,
  });

  final List<_SpeedSample> samples;
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
        ? const [_SpeedSample(download: 0, disk: 0)]
        : samples;
    var maximum = 1;
    for (final sample in values) {
      if (sample.download > maximum) maximum = sample.download;
      if (sample.disk > maximum) maximum = sample.disk;
    }

    final slot = size.width / _DownloadActivityState._historyLength;
    final barPaint = Paint()
      ..color = networkColor.withValues(alpha: 0.62)
      ..strokeWidth = (slot * 0.62).clamp(1.0, 5.0)
      ..strokeCap = StrokeCap.round;
    final offset = _DownloadActivityState._historyLength - values.length;
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
      final y = size.height - values[i].disk / maximum * (size.height - 4);
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

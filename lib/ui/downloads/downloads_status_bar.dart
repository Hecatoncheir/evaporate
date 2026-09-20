import 'package:flutter/material.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../services/download/download_engine.dart';
import '../theme.dart';
import 'downloads_readout.dart';
import 'engine_failure.dart';

/// Показания раздела и, если движок слёг, рассказ об этом.
///
/// Одним виджетом: и то и другое отвечает на вопрос «что сейчас
/// происходит», и стоит оно на странице подряд.
class DownloadsStatusBar extends StatelessWidget {
  const DownloadsStatusBar({
    super.key,
    required this.downloads,
    required this.queued,
    required this.maxConcurrent,
  });

  final DownloadsState downloads;

  /// Сколько задач ждёт очереди.
  final int queued;

  final int maxConcurrent;

  @override
  Widget build(BuildContext context) {
    final engine = downloads.engine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EvaporateLayout.inset(top: 14),
          child: DownloadsReadout(
            stats: downloads.stats,
            active: downloads.holdingSlots.length,
            queued: queued,
            maxConcurrent: maxConcurrent,
          ),
        ),
        if (engine.state == EngineState.failed)
          Padding(
            padding: EvaporateLayout.inset(top: 14),
            child: EngineFailure(message: engine.message),
          ),
      ],
    );
  }
}

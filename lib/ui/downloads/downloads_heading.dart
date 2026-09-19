import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../services/download/download_engine.dart';
import '../theme.dart';
import '../widgets/section_heading.dart';
import 'engine_status.dart';

/// Подпись раздела загрузок с состоянием движка и, если он встал,
/// клавишей перезапуска.
class DownloadsHeading extends StatelessWidget {
  const DownloadsHeading({super.key, required this.status});

  final EngineStatus status;

  @override
  Widget build(BuildContext context) {
    // Перезапуск теперь только здесь: движок принадлежит этому разделу, и
    // неполадку замечают тоже здесь. В настройках такая же клавиша стояла
    // второй, и две одинаковых заставляли искать между ними разницу.
    // Заодно она показывается не только на отказе: остановленный движок
    // поднять было нечем.
    final stalled =
        status.state == EngineState.failed ||
        status.state == EngineState.stopped;
    return SectionHeading(
      label: L.of(context).conceptDownloadsLabel,
      semanticsLabel: L.of(context).downloads,
      padding: EvaporateLayout.inset(top: 20),
      trailing: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          EngineStatusChip(status: status),
          if (stalled)
            OutlinedButton.icon(
              onPressed: () => context.read<DownloadsBloc>().add(
                const DownloadEngineRestartRequested(),
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(L.of(context).restartEngine),
            ),
        ],
      ),
    );
  }
}

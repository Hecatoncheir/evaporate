import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../models/download_task.dart';
import '../../services/download/download_engine.dart';
import '../theme.dart';
import '../../l10n/app_localizations.dart';
import 'available_games.dart';
import 'engine_status.dart';
import 'queue_column.dart';

/// Загрузки: что качается сейчас и что пойдёт следом.
///
/// Очередь пользователь выстраивает сам — перетаскиванием игры из левого
/// списка и перестановкой элементов внутри очереди.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsBloc>().state;
    final library = context.watch<LibraryBloc>().state;
    final maxConcurrent = context.select<SettingsBloc, int>(
      (bloc) => bloc.state.maxConcurrent,
    );

    // Порядок задач в состоянии — это и есть порядок очереди.
    final active = downloads.tasks
        .where((t) => !t.isQueued && t.state != DownloadState.complete)
        .toList();
    final queued = downloads.tasks.where((t) => t.isQueued).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L.of(context).conceptDownloadsLabel,
                style: TextStyle(
                  color: context.colors.primary,
                  fontFamily: EvaporateTheme.monoFontFamily,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    L.of(context).downloads.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: EvaporateTheme.displayFontFamily,
                      fontSize: 34,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                      // Заглавными и с разрядом: широкий шрифт держит название раздела
                      // как надпись на корпусе, а прижатые заглавные слипаются.
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  EngineStatusChip(status: downloads.engine),
                  const SizedBox(width: 10),
                  if (downloads.engine.state == EngineState.failed)
                    OutlinedButton.icon(
                      onPressed: () => context.read<DownloadsBloc>().add(
                        const DownloadEngineRestartRequested(),
                      ),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(L.of(context).restartEngine),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                L.of(context).concurrentAtOnce(maxConcurrent),
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (downloads.engine.state == EngineState.failed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: EngineFailure(message: downloads.engine.message),
          ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 280,
                child: AvailableGames(library: library, tasks: downloads.tasks),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: QueueColumn(
                  active: active,
                  queued: queued,
                  library: library,
                  allTasks: downloads.tasks,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

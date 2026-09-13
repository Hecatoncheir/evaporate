import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../models/download_task.dart';
import '../../services/download/download_engine.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/game_drop_target.dart';
import '../widgets/readout_panel.dart';
import '../../l10n/app_localizations.dart';
import 'available_games.dart';
import 'engine_status.dart';
import 'queue_column.dart';

/// Загрузки: что качается сейчас и что пойдёт следом.
///
/// Читается как прибор, тем же порядком, что и сохранения: сверху
/// показания — сколько сейчас едет, сколько отдаётся, сколько задач в
/// работе и сколько ждёт, — и лишь под ними подробности по каждой задаче.
/// Раньше ответ на главный вопрос «качается или встало» приходилось искать
/// внутри карточки, среди четырёх мелких цифр.
///
/// Очередь пользователь выстраивает сам — перетаскиванием игры из списка
/// источников и перестановкой внутри очереди. Поэтому список источников
/// остаётся на экране и в узком окне: без него очередь нечем пополнить.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  /// Ширина колонки источников. Уже — и названия релизов, которые здесь
  /// длинные, обрезаются до неузнаваемости.
  static const _sourcesWidth = 340.0;

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

    final sources = AvailableGames(library: library, tasks: downloads.tasks);
    final queue = QueueColumn(
      active: active,
      queued: queued,
      library: library,
      allTasks: downloads.tasks,
    );

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 980;
        // В низком окне полоса источников уступает место очереди: очередь
        // отвечает на вопрос «что происходит», а пополнить её можно и
        // перетаскиванием из библиотеки.
        final roomForSources = box.maxHeight >= 360;
        return Center(
          // Приёмник тот же, что в библиотеке: `.torrent` ложится в очередь,
          // папка становится установленной игрой. Человек бросает файл
          // туда, где сейчас смотрит, а смотрит он на загрузки чаще, чем на
          // сетку обложек, когда речь о раздаче.
          //
          // Страницу добавленной игры при этом не открываем: задача
          // появляется прямо здесь, и уводить с неё незачем.
          child: GameDropTarget(
            selectAfterDrop: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1340),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Heading(status: downloads.engine),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
                    child: _readout(
                      context,
                      stats: downloads.stats,
                      active: active.length,
                      queued: queued.length,
                      maxConcurrent: maxConcurrent,
                    ),
                  ),
                  if (downloads.engine.state == EngineState.failed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
                      child: EngineFailure(message: downloads.engine.message),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(width: _sourcesWidth, child: sources),
                                VerticalDivider(
                                  width: 1,
                                  color: context.colors.outline,
                                ),
                                Expanded(child: queue),
                              ],
                            )
                          : !roomForSources
                          ? queue
                          : Column(
                              children: [
                                // В узком окне источники остаются сверху
                                // полосой. Доли, а не фиксированная высота:
                                // при крупном масштабе интерфейса в
                                // минимальном окне полоса не влезала и
                                // выдавливала очередь за край.
                                Flexible(flex: 2, child: sources),
                                Divider(
                                  height: 1,
                                  color: context.colors.outline,
                                ),
                                Flexible(flex: 5, child: queue),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Показания движка: то, на что смотрят первым делом.
  Widget _readout(
    BuildContext context, {
    required EngineStats stats,
    required int active,
    required int queued,
    required int maxConcurrent,
  }) {
    final l = L.of(context);
    final colors = context.colors;
    final moving = stats.downloadSpeed > 0;
    return ReadoutPanel(
      cells: [
        ReadoutCell(
          label: l.networkSpeed,
          value: speedLabel(l, stats.downloadSpeed),
          // Идущая загрузка горит фирменным цветом, замершая — нет: это и
          // есть ответ на «качается или встало».
          color: moving ? colors.primary : null,
          dim: !moving,
        ),
        ReadoutCell(
          label: l.uploadSpeed,
          value: speedLabel(l, stats.uploadSpeed),
          dim: stats.uploadSpeed == 0,
        ),
        ReadoutCell(
          label: l.downloadsStatActive,
          value: '$active / $maxConcurrent',
          compact: true,
        ),
        ReadoutCell(
          label: l.downloadsStatQueued,
          value: '$queued',
          dim: queued == 0,
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.status});

  final EngineStatus status;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          L.of(context).conceptDownloadsLabel,
          style: TextStyle(
            color: context.colors.primary,
            fontFamily: EvaporateTheme.monoFontFamily,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              L.of(context).downloads.toUpperCase(),
              style: const TextStyle(
                fontFamily: EvaporateTheme.displayFontFamily,
                fontSize: 34,
                height: 1.0,
                fontWeight: FontWeight.w800,
                // Заглавными и с разрядом: широкий шрифт держит название
                // раздела как надпись на корпусе, а прижатые заглавные
                // слипаются.
                letterSpacing: 1.4,
              ),
            ),
            const Spacer(),
            EngineStatusChip(status: status),
            if (status.state == EngineState.failed) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => context.read<DownloadsBloc>().add(
                  const DownloadEngineRestartRequested(),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(L.of(context).restartEngine),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

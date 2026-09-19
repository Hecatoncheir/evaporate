import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../../services/download/download_engine.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/game_drop_target.dart';
import '../widgets/readout_panel.dart';
import '../widgets/section_heading.dart';
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

  /// Ниже этой ширины источники и очередь в строку не помещаются.
  static const _wideWidth = 980.0;

  /// В низком окне полоса источников уступает место очереди: очередь
  /// отвечает на вопрос «что происходит», а пополнить её можно и
  /// перетаскиванием из библиотеки.
  static const _sourcesHeight = 360.0;

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsBloc>().state;
    final library = context.watch<LibraryBloc>().state;
    final maxConcurrent = context.select<SettingsBloc, int>(
      (bloc) => bloc.state.maxConcurrent,
    );

    // Порядок задач в состоянии — это и есть порядок очереди.
    final active = downloads.inWork;
    final queued = downloads.queued;

    final sources = AvailableGames(library: library, tasks: downloads.tasks);
    final queue = QueueColumn(
      active: active,
      queued: queued,
      library: library,
      allTasks: downloads.tasks,
    );

    return LayoutBuilder(
      builder: (context, box) => Center(
        // Приёмник тот же, что в библиотеке: `.torrent` ложится в очередь,
        // папка становится установленной игрой. Человек бросает файл туда,
        // где сейчас смотрит, а смотрит он на загрузки чаще, чем на сетку
        // обложек, когда речь о раздаче.
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
                    active: downloads.holdingSlots.length,
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
                    child: _columns(
                      context,
                      box,
                      sources: sources,
                      queue: queue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Расставляет источники и очередь по размеру окна.
  Widget _columns(
    BuildContext context,
    BoxConstraints box, {
    required Widget sources,
    required Widget queue,
  }) {
    if (box.maxWidth >= _wideWidth) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: _sourcesWidth, child: sources),
          VerticalDivider(width: 1, color: context.colors.outline),
          Expanded(child: queue),
        ],
      );
    }
    if (box.maxHeight < _sourcesHeight) return queue;
    return Column(
      children: [
        // В узком окне источники остаются сверху полосой. Доли, а не
        // фиксированная высота: при крупном масштабе интерфейса в
        // минимальном окне полоса не влезала и выдавливала очередь за край.
        Flexible(flex: 2, child: sources),
        Divider(height: 1, color: context.colors.outline),
        Flexible(flex: 5, child: queue),
      ],
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
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
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

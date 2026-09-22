import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../theme.dart';
import '../widgets/game_drop_target.dart';
import '../widgets/watch_while_shown.dart';
import 'available_games.dart';
import 'downloads_columns.dart';
import 'downloads_heading.dart';
import 'downloads_status_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    final downloads = context.watchWhileShown<DownloadsBloc, DownloadsState>();
    final library = context.watchWhileShown<LibraryBloc, LibraryState>();
    final maxConcurrent = context.select<SettingsBloc, int>(
      (bloc) => bloc.state.maxConcurrent,
    );

    // Порядок задач в состоянии — это и есть порядок очереди.
    final active = downloads.inWork;
    final queued = downloads.queued;

    final sources = AvailableGames(library: library, tasks: downloads.tasks);
    final queue = QueueColumn(active: active, queued: queued, library: library);

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
            constraints: EvaporateLayout.contentConstraints,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DownloadsHeading(status: downloads.engine),
                DownloadsStatusBar(
                  downloads: downloads,
                  queued: queued.length,
                  maxConcurrent: maxConcurrent,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: EvaporateSpacing.panel),
                    child: DownloadsColumns(
                      page: box,
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
}

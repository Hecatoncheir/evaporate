import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../bloc/navigation/navigation_bloc.dart';
import '../../core/format.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/nav_tile.dart';

import 'package:file_selector/file_selector.dart';

import 'add_game_dialog.dart';
import 'scan_folder_dialog.dart';
import 'game_detail.dart';
import '../widgets/animated_progress.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryBloc>().state;
    final nav = context.read<NavigationBloc>();
    final selectedId = context.select<NavigationBloc, String?>(
      (bloc) => bloc.state.selectedGameId,
    );
    final games = _filter(library.games);

    // Выбор мог указывать на удалённую или отфильтрованную игру.
    final selected = games.isEmpty
        ? null
        : games.firstWhere(
            (g) => g.id == selectedId,
            orElse: () => games.first,
          );

    // Кнопке «Играть» на геймпаде нужно знать выбранную игру, поэтому
    // фактический выбор поднимается в общий блок навигации.
    if (selected?.id != selectedId) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) nav.add(GameSelected(selected?.id));
      });
    }

    return Row(
      children: [
        SizedBox(width: 300, child: _buildList(context, games, selected, nav)),
        const VerticalDivider(width: 1),
        Expanded(
          child: selected == null
              ? _buildEmpty(context, library.games.isEmpty)
              : GameDetail(key: ValueKey(selected.id), game: selected),
        ),
      ],
    );
  }

  List<Game> _filter(List<Game> games) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? [...games]
        : games.where((g) => g.title.toLowerCase().contains(query)).toList();
    filtered.sort((a, b) {
      // Сначала то, что происходит прямо сейчас, потом недавно запущенное.
      final byActivity = _activityRank(a).compareTo(_activityRank(b));
      if (byActivity != 0) return byActivity;
      final aPlayed = a.lastPlayed;
      final bPlayed = b.lastPlayed;
      if (aPlayed != null && bPlayed != null) return bPlayed.compareTo(aPlayed);
      if (aPlayed != null) return -1;
      if (bPlayed != null) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return filtered;
  }

  static int _activityRank(Game game) => switch (game.status) {
    GameStatus.running => 0,
    GameStatus.downloading => 1,
    GameStatus.paused => 2,
    GameStatus.error => 3,
    GameStatus.installed => 4,
    GameStatus.notInstalled => 5,
  };

  Widget _buildList(
    BuildContext context,
    List<Game> games,
    Game? selected,
    NavigationBloc nav,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    focusNode: nav.searchFocus,
                    onChanged: (value) => setState(() => _query = value),
                    // Enter в поиске уводит фокус в список — удобно и с
                    // клавиатуры, и с геймпадной экранной клавиатуры.
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    decoration: const InputDecoration(
                      hintText: 'Поиск  ( / )',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _scanFolder(context),
                icon: const Icon(Icons.folder_open_outlined, size: 19),
                tooltip: 'Найти игры в папке',
              ),
              IconButton.filled(
                onPressed: () => _addGame(context),
                icon: const Icon(Icons.add, size: 20),
                tooltip: 'Добавить игру',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: games.isEmpty
              ? Center(
                  child: Text(
                    'Ничего не найдено',
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final game = games[index];
                    return _GameListTile(
                      game: game,
                      isSelected: game.id == selected?.id,
                      onTap: () => nav.add(GameSelected(game.id)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context, bool libraryIsEmpty) {
    if (!libraryIsEmpty) {
      return const EmptyState(
        icon: Icons.videogame_asset_outlined,
        title: 'Выберите игру слева',
      );
    }
    return EmptyState(
      icon: Icons.videogame_asset_outlined,
      title: 'Библиотека пуста',
      description:
          'Добавьте игру: magnet-ссылкой, .torrent-файлом или указав '
          'папку с уже установленной игрой. Источники вы задаёте сами — '
          'каталога в приложении нет.',
      action: FilledButton.icon(
        onPressed: () => _addGame(context),
        icon: const Icon(Icons.add),
        label: const Text('Добавить игру'),
      ),
    );
  }

  /// Добавление по одной терпимо для трёх игр и мучительно для сорока.
  Future<void> _scanFolder(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final dir = await getDirectoryPath(confirmButtonText: 'Сканировать');
    if (dir == null || !context.mounted) return;

    final added = await showScanFolderDialog(context, dir);
    if (added == null || added == 0) return;
    messenger.showSnackBar(SnackBar(content: Text('Добавлено игр: $added')));
  }

  Future<void> _addGame(BuildContext context) async {
    final nav = context.read<NavigationBloc>();
    final addedId = await showAddGameDialog(context);
    if (addedId != null && mounted) nav.add(GameSelected(addedId));
  }
}

class _GameListTile extends StatelessWidget {
  const _GameListTile({
    required this.game,
    required this.isSelected,
    required this.onTap,
  });

  final Game game;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final task = context.select<DownloadsBloc, DownloadTask?>(
      (bloc) => bloc.state.taskForGame(game),
    );

    return NavTile(
      selected: isSelected,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.colors.surfaceHigh,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: context.colors.outline),
            ),
            alignment: Alignment.center,
            child: Text(
              game.title.characters.take(1).toString().toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                if (task != null && task.isRunning)
                  _MiniProgress(progress: task.progress, task: task)
                else
                  Text(
                    _subtitle(game),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (game.status == GameStatus.running)
            Icon(Icons.play_circle, size: 16, color: context.colors.accent),
        ],
      ),
    );
  }

  static String _subtitle(Game game) {
    if (game.status == GameStatus.error) return game.lastError ?? 'Ошибка';
    if (game.playtime.inMinutes > 0) {
      return 'Наиграно ${formatDuration(game.playtime)}';
    }
    return switch (game.status) {
      GameStatus.installed => 'Установлена',
      GameStatus.notInstalled => 'Не установлена',
      GameStatus.paused => 'Загрузка на паузе',
      _ => '',
    };
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.progress, required this.task});

  final double progress;
  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedProgress(value: progress == 0 ? null : progress, height: 3),
        const SizedBox(height: 3),
        Text(
          '${(progress * 100).toStringAsFixed(0)}% · '
          '${formatSpeed(task.downloadSpeed)}',
          style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

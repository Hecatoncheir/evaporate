import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'add_game_dialog.dart';

/// Пустая полка. Два случая, и путать их нельзя: в библиотеке нет ни одной
/// игры — или поиск ничего не нашёл. В первом человеку нужны пути
/// пополнить библиотеку, во втором они только мешают.
///
/// Путей три, как у прототипа: найти установленные, указать источник и
/// бросить в окно. Прежде была одна клавиша «добавить», и о поиске уже
/// установленных игр — самом частом начале — человек узнавал из меню
/// панели, если вообще узнавал.
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({super.key, required this.onScan});

  /// Поиск установленных игр — тот же, что у панели библиотеки: его держит
  /// страница, и пока он идёт, полка бросков не ловит.
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final libraryIsEmpty = context.select<LibraryBloc, bool>(
      (b) => b.state.games.isEmpty,
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(EvaporateSpacing.vast),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videogame_asset_outlined,
              size: EvaporateIconSize.hero,
              color: context.colors.accent,
            ),
            const SizedBox(height: EvaporateSpacing.panel),
            Text(
              libraryIsEmpty ? l.libraryEmpty : l.nothingFound,
              textAlign: TextAlign.center,
              style: context.text.title,
            ),
            if (libraryIsEmpty) ...[
              const SizedBox(height: EvaporateSpacing.gap),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  l.libraryEmptyNote,
                  textAlign: TextAlign.center,
                  style: context.text.prose.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: EvaporateSpacing.section),
              _Entries(onScan: onScan),
              const SizedBox(height: EvaporateSpacing.section),
              const _DropHint(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Два входа клавишами: поиск установленных — главный, источник — рядом.
class _Entries extends StatelessWidget {
  const _Entries({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: EvaporateSpacing.field,
      runSpacing: EvaporateSpacing.field,
      children: [
        FilledButton.icon(
          onPressed: onScan,
          icon: const Icon(Icons.folder_open_outlined),
          label: Text(l.findInstalledGames),
        ),
        OutlinedButton.icon(
          onPressed: () => showAddGameDialog(context),
          icon: const Icon(Icons.link),
          label: Text(l.addGameSource),
        ),
      ],
    );
  }
}

/// Третий вход — бросок в окно. Приёмник уже стоит вокруг всей полки
/// (`GameDropTarget`), поэтому здесь только подсказка, что так можно, и
/// не клавиша: нажимать на неё нечего, а остановка фокуса без действия
/// путала бы идущего с геймпада.
class _DropHint extends StatelessWidget {
  const _DropHint();

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(EvaporateSpacing.card),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.file_download_outlined, color: muted),
          const SizedBox(width: EvaporateSpacing.field),
          Flexible(
            child: Text(
              L.of(context).libraryDropHint,
              style: context.text.caption.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

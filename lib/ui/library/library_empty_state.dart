import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../bloc/library_view/library_view_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/shelf.dart';
import '../theme.dart';
import 'add_game_dialog.dart';

/// Пустая полка. Три случая, и путать их нельзя: в библиотеке нет ни одной
/// игры, поиск ничего не нашёл — или полка отбора пуста сама по себе. В
/// первом человеку нужны пути пополнить библиотеку, в остальных они только
/// мешают. Последний случай частый у «Продолжить»: пока ни одну игру не
/// запускали, на ней ничего нет, и «ничего не найдено» врало бы о поиске,
/// которого не было.
///
/// Путей три, как у прототипа: найти установленные, указать источник и
/// бросить в окно. Прежде была одна клавиша «добавить», и о поиске уже
/// установленных игр — самом частом начале — человек узнавал из меню
/// панели, если вообще узнавал.
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({super.key, required this.onScan});

  /// Поиск установленных игр — тот же, что у панели библиотеки: его держит
  /// страница, и пока он идёт, сетка бросков не ловит.
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final libraryIsEmpty = context.select<LibraryBloc, bool>(
      (b) => b.state.games.isEmpty,
    );
    final view = context.select<LibraryViewBloc, LibraryView>((b) => b.state);
    // Своей прокрутки нет: пустая полка — часть страницы, и не влезшее
    // уходит вверх вместе с ней.
    return Center(
      child: Padding(
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
              _title(l, libraryIsEmpty: libraryIsEmpty, view: view),
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

/// Почему на полке пусто.
String _title(L l, {required bool libraryIsEmpty, required LibraryView view}) {
  if (libraryIsEmpty) return l.libraryEmpty;
  if (view.query.trim().isNotEmpty) return l.nothingFound;
  return view.shelf == Shelf.recent ? l.shelfRecentEmpty : l.shelfEmpty;
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

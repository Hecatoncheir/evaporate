import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../bloc/saves/saves_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/catalog_progress.dart';
import '../../../models/game.dart';
import '../../theme.dart';
import 'find_paths_progress.dart';

/// «Найти пути» — одна клавиша с меню на два способа поиска.
///
/// В шапке карточки стояли три органа управления: «Из базы», значок
/// волшебной палочки без подписи и «Добавить». Первые два делают одно —
/// предлагают пути сохранений, — и чем они различаются, можно было узнать
/// только из всплывающей подсказки, которой на геймпаде нет вовсе.
///
/// Пока идёт поиск, вместо клавиши стоит его ход: первый заход качает
/// семнадцать мегабайт и разбирает их несколько секунд, а без слов это
/// выглядит зависанием.
class FindPathsButton extends StatelessWidget {
  const FindPathsButton({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final busy = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.isBusy(LibraryBloc.savePathsKey(game.id)),
    );
    final guessing = context.select<SavesBloc, bool>(
      (bloc) => bloc.state.isBusy(SavesBloc.suggestKey(game.id)),
    );
    final progress = context.select<LibraryBloc, CatalogProgress?>(
      (bloc) => bloc.state.savePathsProgress,
    );

    if (busy || guessing) {
      return FindPathsProgress(guessing: guessing, progress: progress);
    }

    return MenuAnchor(
      builder: (context, controller, _) => TextButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.travel_explore),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.findPaths),
            const Icon(Icons.arrow_drop_down, size: EvaporateIconSize.panel),
          ],
        ),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: () => context.read<LibraryBloc>().add(
            SavePathsLookupRequested(game, refresh: true),
          ),
          leadingIcon: const Icon(
            Icons.storage_outlined,
            size: EvaporateIconSize.panel,
          ),
          child: Text(l.fromDatabase),
        ),
        MenuItemButton(
          onPressed: () =>
              context.read<SavesBloc>().add(SavePathSuggestionsRequested(game)),
          leadingIcon: const Icon(
            Icons.auto_awesome,
            size: EvaporateIconSize.panel,
          ),
          child: Text(l.findFolderByTitle),
        ),
      ],
    );
  }
}

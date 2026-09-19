import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/catalog_progress.dart';
import '../../../models/game.dart';

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
  const FindPathsButton({
    super.key,
    required this.game,
    required this.onByTitle,
  });

  final Game game;
  final VoidCallback onByTitle;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final busy = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.isBusy(LibraryBloc.savePathsKey(game.id)),
    );
    final progress = context.select<LibraryBloc, CatalogProgress?>(
      (bloc) => bloc.state.savePathsProgress,
    );

    if (busy) {
      return TextButton.icon(
        onPressed: null,
        icon: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            // Пока размер неизвестен, полоса бежит сама, а не показывает
            // выдуманное число.
            value: progress?.fraction,
          ),
        ),
        label: Text(_lookupLabel(l, progress, busy: true)),
      );
    }

    return MenuAnchor(
      builder: (context, controller, _) => TextButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.travel_explore, size: 16),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.findPaths),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: () => context.read<LibraryBloc>().add(
            SavePathsLookupRequested(game, refresh: true),
          ),
          leadingIcon: const Icon(Icons.storage_outlined, size: 18),
          child: Text(l.fromDatabase),
        ),
        MenuItemButton(
          onPressed: onByTitle,
          leadingIcon: const Icon(Icons.auto_awesome, size: 18),
          child: Text(l.findFolderByTitle),
        ),
      ],
    );
  }
}

/// Подпись кнопки поиска путей.
///
/// Первый поиск качает семнадцать мегабайт и разбирает их несколько секунд.
/// Без слов о том, что происходит, это выглядит зависанием, поэтому подпись
/// меняется вместе с этапом.
String _lookupLabel(L l, CatalogProgress? progress, {required bool busy}) {
  if (!busy || progress == null) return l.fromDatabase;
  return switch (progress.phase) {
    CatalogPhase.parsing => l.databaseParsing,
    CatalogPhase.downloading =>
      progress.fraction == null
          ? l.databaseDownloading
          : l.databaseDownloadingPercent((progress.fraction! * 100).round()),
  };
}

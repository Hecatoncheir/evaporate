import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/catalog_progress.dart';

/// Ход поиска вместо клавиши: первый заход в базу качает семнадцать
/// мегабайт и разбирает их несколько секунд, а без слов это выглядит
/// зависанием.
class FindPathsProgress extends StatelessWidget {
  const FindPathsProgress({
    super.key,
    required this.guessing,
    required this.progress,
  });

  /// Идёт обход папок по названию игры, а не загрузка базы.
  final bool guessing;

  final CatalogProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return TextButton.icon(
      onPressed: null,
      icon: SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          // Пока размер неизвестен, полоса бежит сама, а не показывает
          // выдуманное число.
          value: guessing ? null : progress?.fraction,
        ),
      ),
      // Подписи у двух поисков разные: база качается мегабайтами и
      // рассказывает о себе процентами, а обход папок — просто идёт.
      label: Text(guessing ? l.searchingFolders : _lookupLabel(l, progress)),
    );
  }
}

/// Подпись кнопки поиска путей.
///
/// Первый поиск качает семнадцать мегабайт и разбирает их несколько секунд.
/// Без слов о том, что происходит, это выглядит зависанием, поэтому подпись
/// меняется вместе с этапом.
String _lookupLabel(L l, CatalogProgress? progress) {
  if (progress == null) return l.fromDatabase;
  return switch (progress.phase) {
    CatalogPhase.parsing => l.databaseParsing,
    CatalogPhase.downloading =>
      progress.fraction == null
          ? l.databaseDownloading
          : l.databaseDownloadingPercent((progress.fraction! * 100).round()),
  };
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/saves/saves_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../services/saves/save_manager.dart';
import '../theme.dart';
import 'sync_package_row.dart';

/// Что лежит в папке синхронизации: сам путь и найденные пакеты.
///
/// «Пусто» и «ещё не смотрели» — разные слова: второе не выдаёт незнание
/// за отсутствие пакетов ровно там, где человек решает, искать ли их
/// дальше.
class SyncFolderContents extends StatelessWidget {
  const SyncFolderContents({required this.folder, super.key});

  final String folder;

  @override
  Widget build(BuildContext context) {
    final packages = context.select<SavesBloc, List<SavePackageInfo>>(
      (bloc) => bloc.state.syncPackages,
    );
    final scannedOnce = context.select<SavesBloc, bool>(
      (bloc) => bloc.state.syncScanned,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(folder, style: context.text.path),
        const SizedBox(height: EvaporateSpacing.block),
        if (packages.isEmpty)
          Text(
            scannedOnce
                ? L.of(context).noPackagesFound
                : L.of(context).checkFolderHint,
            style: context.text.bodyMuted,
          )
        else
          for (final package in packages) SyncPackageRow(package: package),
      ],
    );
  }
}

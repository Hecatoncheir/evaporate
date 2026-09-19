import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/saves/saves_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../services/saves/save_manager.dart';
import '../theme.dart';
import '../widgets/section_card.dart';
import 'sync_package_row.dart';

/// Папка синхронизации: где лежат пакеты с других устройств и что с ними
/// делать.
///
/// Состояние берёт сама, а не получает от страницы: карточке нужны папка из
/// настроек и три поля из блока сохранений, и провести их сверху означало бы
/// шесть параметров, которые страница только передаёт дальше.
class SyncFolderCard extends StatelessWidget {
  const SyncFolderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsStore = context.read<SettingsBloc>();
    final folder = context.select<SettingsBloc, String?>(
      (bloc) => bloc.state.syncFolder,
    );
    final packages = context.select<SavesBloc, List<SavePackageInfo>>(
      (bloc) => bloc.state.syncPackages,
    );
    final scanning = context.select<SavesBloc, bool>(
      (bloc) => bloc.state.scanningSync,
    );
    final scannedOnce = context.select<SavesBloc, bool>(
      (bloc) => bloc.state.syncScanned,
    );
    void onScan() =>
        context.read<SavesBloc>().add(const SyncFolderScanRequested());

    return SectionCard(
      title: L.of(context).syncFolder,
      icon: Icons.sync,
      trailing: folder == null
          ? null
          : TextButton.icon(
              onPressed: scanning ? null : onScan,
              icon: scanning
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 16),
              label: Text(L.of(context).check),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (folder == null) ...[
            Text(L.of(context).syncFolderNote, style: context.text.paragraph),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                final dir = await getDirectoryPath();
                if (dir == null) return;
                settingsStore.add(
                  SettingsPatched((s) => s.copyWith(syncFolder: dir)),
                );
              },
              icon: const Icon(Icons.folder_outlined, size: 16),
              label: Text(L.of(context).chooseFolder),
            ),
          ] else ...[
            SelectableText(folder, style: context.text.path),
            const SizedBox(height: 14),
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
        ],
      ),
    );
  }
}

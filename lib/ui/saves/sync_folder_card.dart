import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../bloc/saves/saves_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../services/saves/save_manager.dart';
import '../feedback/confirm.dart';
import '../feedback/snack.dart';
import '../theme.dart';
import '../widgets/section_card.dart';

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
              for (final package in packages) _PackageRow(package: package),
          ],
        ],
      ),
    );
  }
}

/// Пакет с другого устройства: чей он, когда снят — и клавиша «применить».
class _PackageRow extends StatelessWidget {
  const _PackageRow({required this.package});

  final SavePackageInfo package;

  @override
  Widget build(BuildContext context) {
    final snapshot = package.snapshot;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
        border: Border.all(color: context.colors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(snapshot.gameTitle, style: context.text.bodyStrong),
                const SizedBox(height: 3),
                Text(
                  '${formatDateTime(snapshot.createdAt)} · '
                  '${snapshot.deviceName} · '
                  '${platformLabel(snapshot.platform)} · '
                  '${L.of(context).filesCount(snapshot.fileCount)}',
                  style: context.text.captionMuted,
                ),
              ],
            ),
          ),
          if (!package.isCompatible)
            Tooltip(
              message: L.of(context).noPathsForPlatform,
              child: Icon(
                Icons.warning_amber_rounded,
                size: 17,
                color: context.colors.warning,
              ),
            ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _apply(context),
            style: context.buttons.compactFilled,
            child: Text(L.of(context).apply),
          ),
        ],
      ),
    );
  }

  /// Импорт пакета и немедленное восстановление — путь «взял и играю дальше».
  Future<void> _apply(BuildContext context) async {
    final saves = context.read<SavesBloc>();
    final game = await _pickGame(context);
    if (game == null || !context.mounted) return;

    final ok = await confirm(
      context,
      title: L.of(context).applySaves,
      message: L
          .of(context)
          .applyNote(
            package.snapshot.gameTitle,
            formatDateTime(package.snapshot.createdAt),
            package.snapshot.deviceName,
            game.title,
          ),
      confirmLabel: L.of(context).apply,
    );
    if (!ok || !context.mounted) return;

    // Импорт и восстановление — одно событие; итог сообщит блок.
    saves.add(SyncPackageApplied(path: package.path, game: game));
  }

  Future<Game?> _pickGame(BuildContext context) async {
    final games = context.read<LibraryBloc>().state.games;
    if (games.isEmpty) {
      showError(context, L.of(context).addGameFirst);
      return null;
    }

    // Чаще всего игра уже есть под тем же названием — предлагаем её первой.
    final wanted = package.snapshot.gameTitle.trim().toLowerCase();
    final sorted = [...games]
      ..sort((a, b) {
        final aMatch = a.title.trim().toLowerCase() == wanted ? 0 : 1;
        final bMatch = b.title.trim().toLowerCase() == wanted ? 0 : 1;
        return aMatch.compareTo(bMatch);
      });

    return showDialog<Game>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L.of(context).whichGameToApply),
        content: SizedBox(
          width: 460,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final game = sorted[index];
              final matches = game.title.trim().toLowerCase() == wanted;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  matches
                      ? Icons.check_circle_outline
                      : Icons.videogame_asset_outlined,
                  size: 18,
                  color: matches ? context.colors.accent : null,
                ),
                title: Text(game.title, style: context.text.body),
                subtitle: game.saveProfile.isConfigured
                    ? null
                    : Text(
                        L.of(context).noSavePaths,
                        style: context.text.small.copyWith(
                          color: context.colors.warning,
                        ),
                      ),
                onTap: () => Navigator.pop(context, game),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L.of(context).cancel),
          ),
        ],
      ),
    );
  }
}

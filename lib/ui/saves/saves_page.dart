import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/format.dart';
import '../../models/game.dart';
import '../../models/save_snapshot.dart';
import '../../services/saves/save_manager.dart';
import '../../bloc/library/library_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Общий экран переноса сохранений: папка синхронизации, пакеты с других
/// устройств и все снимки библиотеки в одном списке.
class SavesPage extends StatefulWidget {
  const SavesPage({super.key});

  @override
  State<SavesPage> createState() => _SavesPageState();
}

class _SavesPageState extends State<SavesPage> {
  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryBloc>().state;
    final settings = context.watch<SettingsBloc>().state;

    final entries = <(Game, SaveSnapshot)>[];
    for (final game in library.games) {
      for (final snapshot in library.snapshotsFor(game.id)) {
        entries.add((game, snapshot));
      }
    }
    entries.sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      children: [
        const Text(
          'Сохранения',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Снимок сохранений — это один файл .evsave: положите его в облачную '
          'папку или на флешку, откройте на другом устройстве и продолжите '
          'с того же места.',
          style: TextStyle(
            color: EvaporateTheme.textSecondary,
            height: 1.5,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        const _BulkTransferCard(),
        _SyncFolderCard(
          folder: settings.syncFolder,
          packages: library.syncPackages,
          scanning: library.scanningSync,
          scannedOnce: library.syncScanned,
          onScan: () =>
              context.read<LibraryBloc>().add(const SyncFolderScanRequested()),
          onApply: _apply,
        ),
        SectionCard(
          title: 'Все снимки',
          icon: Icons.history,
          trailing: Text(
            '${entries.length}',
            style: const TextStyle(color: EvaporateTheme.textSecondary),
          ),
          child: entries.isEmpty
              ? const Text(
                  'Снимков пока нет. Откройте игру в библиотеке, задайте папку '
                  'сохранений и нажмите «Снять».',
                  style: TextStyle(
                    color: EvaporateTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                )
              : Column(
                  children: [
                    for (final (game, snapshot) in entries)
                      _SnapshotRow(game: game, snapshot: snapshot),
                  ],
                ),
        ),
      ],
    );
  }

  /// Импорт пакета и немедленное восстановление — путь «взял и играю дальше».
  Future<void> _apply(SavePackageInfo info) async {
    final library = context.read<LibraryBloc>();
    final game = await _pickGame(info);
    if (game == null || !mounted) return;

    final ok = await confirm(
      context,
      title: 'Применить сохранения?',
      message:
          'Снимок «${info.snapshot.gameTitle}» от '
          '${formatDateTime(info.snapshot.createdAt)} '
          '(устройство ${info.snapshot.deviceName}) будет распакован в папки '
          'сохранений игры «${game.title}».\n\n'
          'Текущие сохранения сначала попадут в резервный снимок.',
      confirmLabel: 'Применить',
    );
    if (!ok || !mounted) return;

    // Импорт и восстановление — одно событие; итог сообщит блок.
    library.add(SyncPackageApplied(path: info.path, game: game));
  }

  Future<Game?> _pickGame(SavePackageInfo info) async {
    final games = context.read<LibraryBloc>().state.games;
    if (games.isEmpty) {
      showError(context, 'Сначала добавьте игру в библиотеку.');
      return null;
    }

    // Чаще всего игра уже есть под тем же названием — предлагаем её первой.
    final wanted = info.snapshot.gameTitle.trim().toLowerCase();
    final sorted = [...games]
      ..sort((a, b) {
        final aMatch = a.title.trim().toLowerCase() == wanted ? 0 : 1;
        final bMatch = b.title.trim().toLowerCase() == wanted ? 0 : 1;
        return aMatch.compareTo(bMatch);
      });

    return showDialog<Game>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('В какую игру применить?'),
        content: SizedBox(
          width: 460,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final game = sorted[index];
              final matches = game.title.trim().toLowerCase() == wanted;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  matches
                      ? Icons.check_circle_outline
                      : Icons.videogame_asset_outlined,
                  size: 18,
                  color: matches ? EvaporateTheme.accent : null,
                ),
                title: Text(game.title, style: const TextStyle(fontSize: 13)),
                subtitle: game.saveProfile.isConfigured
                    ? null
                    : const Text(
                        'Пути сохранений не заданы',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: EvaporateTheme.warning,
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
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }
}

class _SyncFolderCard extends StatelessWidget {
  const _SyncFolderCard({
    required this.folder,
    required this.packages,
    required this.scanning,
    required this.scannedOnce,
    required this.onScan,
    required this.onApply,
  });

  final String? folder;
  final List<SavePackageInfo> packages;
  final bool scanning;
  final bool scannedOnce;
  final VoidCallback onScan;
  final void Function(SavePackageInfo) onApply;

  @override
  Widget build(BuildContext context) {
    final settingsStore = context.read<SettingsBloc>();

    return SectionCard(
      title: 'Папка синхронизации',
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
              label: const Text('Проверить'),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (folder == null) ...[
            const Text(
              'Укажите папку, которая синхронизируется между устройствами — '
              'Dropbox, iCloud, Syncthing. Новые снимки будут попадать туда '
              'автоматически, а на другом устройстве появятся в этом списке.',
              style: TextStyle(
                color: EvaporateTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                final dir = await getDirectoryPath();
                if (dir == null) return;
                settingsStore.add(
                  SettingsChanged(
                    settingsStore.state.copyWith(syncFolder: dir),
                  ),
                );
              },
              icon: const Icon(Icons.folder_outlined, size: 16),
              label: const Text('Выбрать папку'),
            ),
          ] else ...[
            SelectableText(
              folder!,
              style: const TextStyle(
                fontFamily: EvaporateTheme.monoFontFamily,
                fontSize: 12,
                color: EvaporateTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            if (packages.isEmpty)
              Text(
                scannedOnce ? 'Пакетов .evsave в папке не найдено.' : 'Нажмите «Проверить», чтобы посмотреть, что лежит в папке.',
                style: const TextStyle(
                  color: EvaporateTheme.textSecondary,
                  fontSize: 13,
                ),
              )
            else
              for (final package in packages)
                _PackageRow(package: package, onApply: () => onApply(package)),
          ],
        ],
      ),
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({required this.package, required this.onApply});

  final SavePackageInfo package;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final snapshot = package.snapshot;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: EvaporateTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EvaporateTheme.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.gameTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatDateTime(snapshot.createdAt)} · '
                  '${snapshot.deviceName} · '
                  '${platformLabel(snapshot.platform)} · '
                  '${snapshot.fileCount} файлов',
                  style: const TextStyle(
                    fontSize: 12,
                    color: EvaporateTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!package.isCompatible)
            const Tooltip(
              message:
                  'В пакете нет путей для этой платформы — '
                  'понадобится правило с той же меткой',
              child: Icon(
                Icons.warning_amber_rounded,
                size: 17,
                color: EvaporateTheme.warning,
              ),
            ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onApply,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.game, required this.snapshot});

  final Game game;
  final SaveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryBloc>();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: EvaporateTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EvaporateTheme.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatDateTime(snapshot.createdAt)} · '
                  '${snapshot.origin.label} · '
                  '${snapshot.deviceName} · '
                  '${formatBytes(snapshot.sizeBytes)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: EvaporateTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Экспортировать файл',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.ios_share, size: 17),
            onPressed: () async {
              final suggested =
                  safeFileName(snapshot.gameTitle) + SaveSnapshot.fileExtension;
              final location = await getSaveLocation(suggestedName: suggested);
              if (location == null) return;
              library.add(
                SnapshotExportRequested(
                  snapshot: snapshot,
                  destination: location.path,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Перенос всей библиотеки разом: снять сохранения всех игр в одну папку
/// и разложить их обратно на другом устройстве.
class _BulkTransferCard extends StatelessWidget {
  const _BulkTransferCard();

  @override
  Widget build(BuildContext context) {
    final busy = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.isBusy(LibraryBloc.bulkKey),
    );
    final configured = context.select<LibraryBloc, int>(
      (bloc) =>
          bloc.state.games.where((g) => g.saveProfile.isConfigured).length,
    );

    return SectionCard(
      title: 'Перенос всей библиотеки',
      icon: Icons.swap_horiz,
      trailing: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              'игр с путями: $configured',
              style: const TextStyle(
                fontSize: 12,
                color: EvaporateTheme.textSecondary,
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Выгрузка снимет свежие снимки всех игр, у которых заданы папки '
            'сохранений, и сложит их в одну папку. На другом устройстве '
            'загрузка разберёт её обратно, сопоставляя пакеты с играми по '
            'названию.',
            style: TextStyle(
              fontSize: 13,
              color: EvaporateTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton.icon(
                onPressed: busy ? null : () => _export(context),
                icon: const Icon(Icons.upload_outlined, size: 16),
                label: const Text('Выгрузить все'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _import(context),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Загрузить все'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final dir = await getDirectoryPath(confirmButtonText: 'Выгрузить');
    if (dir == null) return;
    library.add(BulkExportRequested(dir));
  }

  Future<void> _import(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final dir = await getDirectoryPath(confirmButtonText: 'Загрузить');
    if (dir == null || !context.mounted) return;

    final ok = await confirm(
      context,
      title: 'Загрузить все сохранения?',
      message:
          'Пакеты из папки будут разложены по играм с такими же названиями. '
          'Текущие сохранения каждой игры сначала попадут в резервный снимок.',
      confirmLabel: 'Загрузить',
    );
    if (!ok) return;
    library.add(BulkImportRequested(dir));
  }
}

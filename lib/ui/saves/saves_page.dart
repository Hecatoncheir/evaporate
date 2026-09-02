import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/format.dart';
import '../../models/game.dart';
import '../../models/save_snapshot.dart';
import '../../services/saves/save_manager.dart';
import '../../bloc/library/library_bloc.dart';
import '../../models/bulk_report.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../../l10n/app_localizations.dart';

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
        Text(
          L.of(context).saves,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          L.of(context).savesIntro,
          style: TextStyle(
            color: context.colors.textSecondary,
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
          title: L.of(context).allSnapshots,
          icon: Icons.history,
          trailing: Text(
            '${entries.length}',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          child: entries.isEmpty
              ? Text(
                  L.of(context).noSnapshotsYet,
                  style: TextStyle(
                    color: context.colors.textSecondary,
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
      title: L.of(context).applySaves,
      message: L
          .of(context)
          .applyNote(
            info.snapshot.gameTitle,
            formatDateTime(info.snapshot.createdAt),
            info.snapshot.deviceName,
            game.title,
          ),
      confirmLabel: L.of(context).apply,
    );
    if (!ok || !mounted) return;

    // Импорт и восстановление — одно событие; итог сообщит блок.
    library.add(SyncPackageApplied(path: info.path, game: game));
  }

  Future<Game?> _pickGame(SavePackageInfo info) async {
    final games = context.read<LibraryBloc>().state.games;
    if (games.isEmpty) {
      showError(context, L.of(context).addGameFirst);
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
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  matches
                      ? Icons.check_circle_outline
                      : Icons.videogame_asset_outlined,
                  size: 18,
                  color: matches ? context.colors.accent : null,
                ),
                title: Text(game.title, style: const TextStyle(fontSize: 13)),
                subtitle: game.saveProfile.isConfigured
                    ? null
                    : Text(
                        L.of(context).noSavePaths,
                        style: TextStyle(
                          fontSize: 11.5,
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
            Text(
              L.of(context).syncFolderNote,
              style: TextStyle(
                color: context.colors.textSecondary,
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
              label: Text(L.of(context).chooseFolder),
            ),
          ] else ...[
            SelectableText(
              folder!,
              style: TextStyle(
                fontFamily: EvaporateTheme.monoFontFamily,
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            if (packages.isEmpty)
              Text(
                scannedOnce
                    ? L.of(context).noPackagesFound
                    : L.of(context).checkFolderHint,
                style: TextStyle(
                  color: context.colors.textSecondary,
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
        color: context.colors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outline),
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
                  '${L.of(context).filesCount(snapshot.fileCount)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
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
            onPressed: onApply,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text(L.of(context).apply),
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
        color: context.colors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outline),
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
                  '${snapshotOriginLabel(L.of(context), snapshot.origin)} · '
                  '${snapshot.deviceName} · '
                  '${formatBytes(snapshot.sizeBytes)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: L.of(context).exportFile,
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
/// Подробности последней массовой операции.
///
/// Одной строкой «с ошибкой: 3» пользоваться нельзя: непонятно, какие игры и
/// почему. Для операции над всей библиотекой это важно — там легко не
/// заметить, что часть сохранений не перенеслась.
class _BulkReportView extends StatelessWidget {
  const _BulkReportView({required this.report});

  final BulkReport report;

  /// Константой быть не может: подписи зависят от языка.
  static String _title(L l, BulkOutcome outcome) => switch (outcome) {
    BulkOutcome.applied => l.outcomeApplied,
    BulkOutcome.conflicted => l.outcomeConflicted,
    BulkOutcome.unmatched => l.outcomeUnmatched,
    BulkOutcome.skipped => l.outcomeSkipped,
    BulkOutcome.failed => l.outcomeFailed,
  };

  @override
  Widget build(BuildContext context) {
    // Сначала то, из-за чего стоит беспокоиться.
    const order = [
      BulkOutcome.failed,
      BulkOutcome.conflicted,
      BulkOutcome.unmatched,
      BulkOutcome.applied,
      BulkOutcome.skipped,
    ];

    final groups = [
      for (final outcome in order)
        if (report.count(outcome) > 0) outcome,
    ];
    if (groups.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        // Раскрыт сразу, если есть о чём беспокоиться: спрятанное
        // предупреждение — почти то же самое, что его отсутствие.
        initiallyExpanded: report.hasProblems,
        title: Text(
          report.isExport
              ? L.of(context).reportExported
              : L.of(context).reportImported,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        children: [
          for (final outcome in groups) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Text(
                  '${_title(L.of(context), outcome)} — ${report.count(outcome)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: outcome == BulkOutcome.applied
                        ? context.colors.accent
                        : outcome == BulkOutcome.skipped
                        ? context.colors.textSecondary
                        : context.colors.warning,
                  ),
                ),
              ),
            ),
            for (final entry in report.withOutcome(outcome))
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, top: 1),
                  child: Text(
                    entry.detail == null
                        ? entry.title
                        : '${entry.title} — ${entry.detail}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

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
    final report = context.select<LibraryBloc, BulkReport?>(
      (bloc) => bloc.state.bulkReport,
    );

    return SectionCard(
      title: L.of(context).bulkTransfer,
      icon: Icons.swap_horiz,
      trailing: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              L.of(context).gamesWithPaths(configured),
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.of(context).bulkTransferNote,
            style: TextStyle(
              fontSize: 13,
              color: context.colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton.icon(
                onPressed: busy ? null : () => _export(context),
                icon: const Icon(Icons.upload_outlined, size: 16),
                label: Text(L.of(context).exportAll),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _import(context),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: Text(L.of(context).importAll),
              ),
            ],
          ),
          if (report != null && !report.isEmpty)
            _BulkReportView(report: report),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final dir = await getDirectoryPath(confirmButtonText: L.of(context).export);
    if (dir == null) return;
    library.add(BulkExportRequested(dir));
  }

  /// Спрашивает, как поступить с играми, где здешние сохранения новее.
  ///
  /// Возвращает `null`, если загрузку отменили. Разделение на два действия
  /// вместо галочки намеренное: это выбор, а не настройка, и человек должен
  /// сделать его осознанно в тот момент, когда он что-то значит.
  Future<bool?> _askAboutNewer(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L.of(context).importAllQuestion),
        content: Text(L.of(context).importAllNote),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(L.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(L.of(context).importOverwriteNewer),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(L.of(context).importSkipNewer),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final dir = await getDirectoryPath(confirmButtonText: L.of(context).import);
    if (dir == null || !context.mounted) return;

    final overwrite = await _askAboutNewer(context);
    if (overwrite == null) return;
    library.add(BulkImportRequested(dir, overwriteNewer: overwrite));
  }
}

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../bloc/library/library_bloc.dart';
import '../../models/catalog_progress.dart';
import '../../core/format.dart';
import '../../core/save_path_template.dart';
import '../../models/game.dart';
import '../../models/save_profile.dart';
import '../../models/save_snapshot.dart';
import '../../services/saves/save_path_finder.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../../l10n/app_localizations.dart';

/// Где лежат сохранения игры. Пути хранятся шаблонами, поэтому один и тот же
/// профиль работает на разных машинах и платформах.
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

class SavePathsSection extends StatelessWidget {
  const SavePathsSection({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final rules = game.saveProfile.rules;

    return SectionCard(
      title: L.of(context).savePaths,
      icon: Icons.folder_special_outlined,
      trailing: Row(
        children: [
          Builder(
            builder: (context) {
              final busy = context.select<LibraryBloc, bool>(
                (bloc) => bloc.state.isBusy(LibraryBloc.savePathsKey(game.id)),
              );
              final progress = context.select<LibraryBloc, CatalogProgress?>(
                (bloc) => bloc.state.savePathsProgress,
              );
              return TextButton.icon(
                onPressed: busy
                    ? null
                    : () => context.read<LibraryBloc>().add(
                        SavePathsLookupRequested(game),
                      ),
                icon: busy
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          // Пока размер неизвестен, полоса бежит сама, а не
                          // показывает выдуманное число.
                          value: progress?.fraction,
                        ),
                      )
                    : const Icon(Icons.travel_explore, size: 16),
                label: Text(_lookupLabel(L.of(context), progress, busy: busy)),
              );
            },
          ),
          IconButton(
            onPressed: () => _autoDetect(context),
            icon: const Icon(Icons.auto_awesome, size: 16),
            tooltip: L.of(context).findFolderByTitle,
            visualDensity: VisualDensity.compact,
          ),
          TextButton.icon(
            onPressed: () => _addRule(context),
            icon: const Icon(Icons.add, size: 16),
            label: Text(L.of(context).add),
          ),
        ],
      ),
      child: rules.isEmpty
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                L.of(context).noPathsSet,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
            )
          : Column(
              children: [
                for (final rule in rules)
                  _RuleTile(
                    rule: rule,
                    onRemove: () => _removeRule(context, rule),
                  ),
                const SizedBox(height: 10),
                _AutoSnapshotToggle(game: game),
              ],
            ),
    );
  }

  Future<void> _addRule(BuildContext context) async {
    final dir = await getDirectoryPath(confirmButtonText: L.of(context).choose);
    if (dir == null || !context.mounted) return;
    await _saveRule(context, template: SavePathTemplate.collapse(dir));
  }

  Future<void> _saveRule(
    BuildContext context, {
    required String template,
    // Значение по умолчанию обязано быть константой, а перевод ею
    // быть не может: подставляем ниже.
    String? label,
  }) async {
    final library = context.read<LibraryBloc>();
    final result = await showDialog<_RuleDraft>(
      context: context,
      builder: (_) =>
          _RuleDialog(template: template, label: label ?? L.of(context).saves),
    );
    if (result == null) return;

    final rule = SavePathRule(
      id: const Uuid().v4(),
      label: result.label,
      template: result.template,
      platform: result.currentPlatformOnly ? currentPlatformKey() : null,
    );
    library.add(
      GameUpdated(
        game.copyWith(
          saveProfile: game.saveProfile.copyWith(
            rules: [...game.saveProfile.rules, rule],
          ),
        ),
      ),
    );
  }

  void _removeRule(BuildContext context, SavePathRule rule) {
    final library = context.read<LibraryBloc>();
    library.add(
      GameUpdated(
        game.copyWith(
          saveProfile: game.saveProfile.copyWith(
            rules: game.saveProfile.rules
                .where((r) => r.id != rule.id)
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _autoDetect(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final suggestions = await SavePathFinder.suggest(game.title);
    if (!context.mounted) return;

    if (suggestions.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(L.of(context).noSimilarFolders)),
      );
      return;
    }

    final chosen = await showDialog<SavePathSuggestion>(
      context: context,
      builder: (_) => _SuggestionsDialog(suggestions: suggestions),
    );
    if (chosen == null || !context.mounted) return;
    await _saveRule(context, template: chosen.template, label: chosen.label);
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.onRemove});

  final SavePathRule rule;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final resolved = rule.resolve();
    final exists =
        Directory(resolved).existsSync() || File(resolved).existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            exists ? Icons.folder_outlined : Icons.folder_off_outlined,
            size: 17,
            color: exists
                ? context.colors.accent
                : context.colors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rule.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (rule.platform != null)
                      _Tag(
                        text: platformLabel(rule.platform!),
                        color: context.colors.textSecondary,
                      ),
                    if (!rule.isPortable) ...[
                      const SizedBox(width: 6),
                      _Tag(
                        text: L.of(context).notPortablePath,
                        color: context.colors.warning,
                      ),
                    ],
                    if (!exists) ...[
                      const SizedBox(width: 6),
                      _Tag(
                        text: L.of(context).missingOnDisk,
                        color: context.colors.textSecondary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                SelectableText(
                  rule.template,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                    fontFamily: EvaporateTheme.monoFontFamily,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
            tooltip: L.of(context).removePath,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _AutoSnapshotToggle extends StatelessWidget {
  const _AutoSnapshotToggle({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryBloc>();
    return Row(
      children: [
        Switch(
          value: game.saveProfile.autoSnapshotOnExit,
          onChanged: (value) => library.add(
            GameUpdated(
              game.copyWith(
                saveProfile: game.saveProfile.copyWith(
                  autoSnapshotOnExit: value,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            L.of(context).autoSnapshotOnExit,
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// Список снимков: восстановление, экспорт на другое устройство, импорт.
///
/// Виджет ничего не знает про ошибки и занятость — и то, и другое приходит
/// из состояния [LibraryBloc].
class SnapshotsSection extends StatelessWidget {
  const SnapshotsSection({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryBloc>().state;
    final snapshots = library.snapshotsFor(game.id);
    final busy = library.isBusy(LibraryBloc.snapshotKey(game.id));

    return SectionCard(
      title: L.of(context).snapshots,
      icon: Icons.history,
      trailing: Row(
        children: [
          TextButton.icon(
            onPressed: busy ? null : () => _import(context),
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: Text(L.of(context).importShort),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: busy || !game.saveProfile.isConfigured
                ? null
                : () =>
                      context.read<LibraryBloc>().add(SnapshotRequested(game)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined, size: 16),
            label: Text(L.of(context).takeSnapshot),
          ),
        ],
      ),
      child: snapshots.isEmpty
          ? Text(
              L.of(context).noSnapshotsNote,
              style: TextStyle(
                color: context.colors.textSecondary,
                height: 1.5,
                fontSize: 13,
              ),
            )
          : Column(
              children: [
                for (final snapshot in snapshots)
                  _SnapshotTile(
                    snapshot: snapshot,
                    onRestore: () => _restore(context, snapshot),
                    onExport: () => _export(context, snapshot),
                    onDelete: () => _delete(context, snapshot),
                  ),
              ],
            ),
    );
  }

  Future<void> _restore(BuildContext context, SaveSnapshot snapshot) async {
    final library = context.read<LibraryBloc>();
    final options = await showDialog<_RestoreOptions>(
      context: context,
      builder: (_) => _RestoreDialog(snapshot: snapshot, game: game),
    );
    if (options == null) return;

    library.add(
      SnapshotRestoreRequested(
        game: game,
        snapshot: snapshot,
        backupCurrent: options.backupCurrent,
        wipeTarget: options.wipeTarget,
      ),
    );
  }

  Future<void> _export(BuildContext context, SaveSnapshot snapshot) async {
    final library = context.read<LibraryBloc>();
    final suggested =
        safeFileName(
          '${snapshot.gameTitle} ${formatDateTime(snapshot.createdAt)}',
        ) +
        SaveSnapshot.fileExtension;

    final location = await getSaveLocation(suggestedName: suggested);
    if (location == null) return;
    library.add(
      SnapshotExportRequested(snapshot: snapshot, destination: location.path),
    );
  }

  Future<void> _delete(BuildContext context, SaveSnapshot snapshot) async {
    final library = context.read<LibraryBloc>();
    final ok = await confirm(
      context,
      title: L.of(context).deleteSnapshotQuestion,
      message: L
          .of(context)
          .deleteSnapshotNote(formatDateTime(snapshot.createdAt)),
      confirmLabel: L.of(context).delete,
      destructive: true,
    );
    if (!ok) return;
    library.add(SnapshotDeleted(snapshot));
  }

  Future<void> _import(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final group = XTypeGroup(
      label: L.of(context).savePackage,
      extensions: const ['evsave', 'zip'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null || !context.mounted) return;

    try {
      final info = await library.saveManager.inspectPackage(file.path);
      if (!context.mounted) return;

      final ok = await confirm(
        context,
        title: L.of(context).importSnapshotQuestion,
        message: L
            .of(context)
            .importSnapshotNote(
              info.snapshot.gameTitle,
              formatDateTime(info.snapshot.createdAt),
              info.snapshot.deviceName,
              platformLabel(info.snapshot.platform),
              info.snapshot.fileCount,
              game.title,
            ),
        confirmLabel: L.of(context).importAction,
      );
      if (!ok) return;
      library.add(SnapshotImportRequested(path: file.path, game: game));
    } on Object catch (error) {
      // Чтение чужого файла — единственное место, где ошибка возникает
      // до входа в кубит.
      if (context.mounted) showError(context, error);
    }
  }
}

class _SnapshotTile extends StatelessWidget {
  const _SnapshotTile({
    required this.snapshot,
    required this.onRestore,
    required this.onExport,
    required this.onDelete,
  });

  final SaveSnapshot snapshot;
  final VoidCallback onRestore;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
                Row(
                  children: [
                    Text(
                      formatDateTime(snapshot.createdAt),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Tag(
                      text: snapshotOriginLabel(L.of(context), snapshot.origin),
                      color: snapshot.origin == SnapshotOrigin.imported
                          ? context.colors.primary
                          : context.colors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${snapshot.deviceName} · '
                  '${platformLabel(snapshot.platform)} · '
                  '${L.of(context).filesCount(snapshot.fileCount)} · '
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
            onPressed: onRestore,
            icon: const Icon(Icons.restore, size: 17),
            tooltip: L.of(context).restore,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onExport,
            icon: const Icon(Icons.ios_share, size: 17),
            tooltip: L.of(context).exportFile,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 17),
            tooltip: L.of(context).delete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, color: color, height: 1.3),
      ),
    );
  }
}

// ------------------------------------------------------------- диалоги

class _RuleDraft {
  const _RuleDraft(this.label, this.template, this.currentPlatformOnly);

  final String label;
  final String template;
  final bool currentPlatformOnly;
}

class _RuleDialog extends StatefulWidget {
  const _RuleDialog({required this.template, required this.label});

  final String template;
  final String label;

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  late final _labelController = TextEditingController(text: widget.label);
  late final _templateController = TextEditingController(text: widget.template);
  bool _currentPlatformOnly = false;

  @override
  void dispose() {
    _labelController.dispose();
    _templateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final template = _templateController.text;
    final portable = SavePathTemplate.isPortable(template);

    return AlertDialog(
      title: Text(L.of(context).savePath),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                labelText: L.of(context).label,
                helperText: L.of(context).labelNote,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _templateController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontFamily: EvaporateTheme.monoFontFamily,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                labelText: L.of(context).pathTemplate,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              L.of(context).expandsTo(SavePathTemplate.expand(template)),
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            if (!portable) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 15,
                    color: context.colors.warning,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      L.of(context).absolutePathWarning,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.warning,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _currentPlatformOnly,
              onChanged: (value) =>
                  setState(() => _currentPlatformOnly = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(
                L
                    .of(context)
                    .onlyForPlatform(platformLabel(currentPlatformKey())),
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                L.of(context).onlyForPlatformNote,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L.of(context).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _RuleDraft(
              _labelController.text.trim().isEmpty
                  ? L.of(context).saves
                  : _labelController.text.trim(),
              _templateController.text.trim(),
              _currentPlatformOnly,
            ),
          ),
          child: Text(L.of(context).save),
        ),
      ],
    );
  }
}

class _SuggestionsDialog extends StatelessWidget {
  const _SuggestionsDialog({required this.suggestions});

  final List<SavePathSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L.of(context).similarFolders),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L.of(context).foundByTitleNote,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined, size: 18),
                    title: Text(
                      p.basename(suggestion.path),
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      L
                          .of(context)
                          .suggestionLine(
                            suggestion.template,
                            suggestion.fileCount,
                          ),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onTap: () => Navigator.pop(context, suggestion),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L.of(context).cancel),
        ),
      ],
    );
  }
}

class _RestoreOptions {
  const _RestoreOptions({
    required this.backupCurrent,
    required this.wipeTarget,
  });

  final bool backupCurrent;
  final bool wipeTarget;
}

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({required this.snapshot, required this.game});

  final SaveSnapshot snapshot;
  final Game game;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  bool _backup = true;
  bool _wipe = false;

  @override
  Widget build(BuildContext context) {
    final targets = _resolveTargets();

    return AlertDialog(
      title: Text(L.of(context).restoreSaves),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L
                  .of(context)
                  .snapshotFrom(
                    formatDateTime(widget.snapshot.createdAt),
                    widget.snapshot.deviceName,
                    platformLabel(widget.snapshot.platform),
                  ),
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            Text(
              L.of(context).filesGoHere,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            if (targets.isEmpty)
              Text(
                L.of(context).noTargetFolders,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.colors.warning,
                  height: 1.4,
                ),
              )
            else
              for (final entry in targets.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: EvaporateTheme.monoFontFamily,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _backup,
              onChanged: (value) => setState(() => _backup = value ?? true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(
                L.of(context).backupFirst,
                style: TextStyle(fontSize: 13),
              ),
            ),
            CheckboxListTile(
              value: _wipe,
              onChanged: (value) => setState(() => _wipe = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(
                L.of(context).wipeBeforeUnpack,
                style: TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                L.of(context).wipeNote,
                style: TextStyle(fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L.of(context).cancel),
        ),
        FilledButton(
          onPressed: targets.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _RestoreOptions(backupCurrent: _backup, wipeTarget: _wipe),
                ),
          child: Text(L.of(context).restore),
        ),
      ],
    );
  }

  /// Показываем заранее, куда именно попадут файлы: восстановление
  /// перезаписывает чужие сохранения, и это должно быть видно до нажатия.
  Map<String, String> _resolveTargets() {
    final local = widget.game.saveProfile.rulesForCurrentPlatform;
    final targets = <String, String>{};
    for (final rule in widget.snapshot.rules) {
      SavePathRule? match;
      for (final candidate in local) {
        if (candidate.id == rule.id) {
          match = candidate;
          break;
        }
      }
      match ??= local
          .where(
            (c) =>
                c.label.trim().toLowerCase() == rule.label.trim().toLowerCase(),
          )
          .firstOrNull;
      if (match == null && rule.appliesToCurrentPlatform()) match = rule;
      if (match != null) targets[match.label] = match.resolve();
    }
    return targets;
  }
}

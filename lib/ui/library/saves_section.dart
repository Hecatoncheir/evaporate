import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../bloc/library/library_bloc.dart';
import '../../bloc/saves/saves_bloc.dart';
import '../../core/format.dart';
import '../../core/save_path_template.dart';
import '../../l10n/app_localizations.dart';
import '../../models/catalog_progress.dart';
import '../../models/game.dart';
import '../../models/save_profile.dart';
import '../../models/save_snapshot.dart';
import '../../services/saves/save_path_finder.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'saves/auto_snapshot_toggle.dart';
import 'saves/restore_dialog.dart';
import 'saves/rule_dialog.dart';
import 'saves/rule_tile.dart';
import 'saves/snapshot_tile.dart';
import 'saves/suggestions_dialog.dart';
import 'saves/watched_folders.dart';

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
class _FindPathsButton extends StatelessWidget {
  const _FindPathsButton({required this.game, required this.onByTitle});

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
        mainAxisSize: MainAxisSize.min,
        children: [
          _FindPathsButton(game: game, onByTitle: () => _autoDetect(context)),
          TextButton.icon(
            onPressed: () => _addRule(context),
            icon: const Icon(Icons.add, size: 16),
            label: Text(L.of(context).add),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (game.ludusaviTemplates.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(L.of(context).savedManifestPaths),
              children: [
                for (final template in game.ludusaviTemplates)
                  ListTile(dense: true, title: SelectableText(template)),
              ],
            ),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                L.of(context).noPathsSet,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
            )
          else ...[
            for (final rule in rules)
              RuleTile(
                rule: rule,
                gameDir: game.installDir,
                onRemove: () => _removeRule(context, rule),
              ),
          ],
          if (rules.isNotEmpty || game.ludusaviTemplates.isNotEmpty) ...[
            const SizedBox(height: 10),
            AutoSnapshotToggle(game: game),
          ],
          WatchedFolders(game: game),
        ],
      ),
    );
  }

  Future<void> _addRule(BuildContext context) async {
    final dir = await getDirectoryPath(confirmButtonText: L.of(context).choose);
    if (dir == null || !context.mounted) return;
    await _saveRule(
      context,
      template: SavePathTemplate.collapse(dir, gameDir: game.installDir),
    );
  }

  Future<void> _saveRule(
    BuildContext context, {
    required String template,
    // Значение по умолчанию обязано быть константой, а перевод ею
    // быть не может: подставляем ниже.
    String? label,
  }) async {
    final library = context.read<LibraryBloc>();
    final result = await showDialog<RuleDraft>(
      context: context,
      builder: (_) => RuleDialog(
        template: template,
        // Свободная метка — та же, что дали бы найденному пути: иначе
        // второе правило игры открывалось бы с уже занятой.
        label:
            label ??
            game.saveProfile.rulesForNewPaths([template]).firstOrNull?.label ??
            SavePathRule.defaultLabel,
        gameDir: game.installDir,
        profile: game.saveProfile,
      ),
    );
    if (result == null) return;

    final rule = SavePathRule(
      id: const Uuid().v4(),
      label: result.label,
      template: result.template,
      platform: result.currentPlatformOnly ? currentPlatformKey() : null,
    );
    library.add(SaveRulesAdded(game.id, [rule]));
  }

  void _removeRule(BuildContext context, SavePathRule rule) {
    context.read<LibraryBloc>().add(SaveRuleRemoved(game.id, rule.id));
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
      builder: (_) => SuggestionsDialog(suggestions: suggestions),
    );
    if (chosen == null || !context.mounted) return;
    await _saveRule(context, template: chosen.template, label: chosen.label);
  }
}

/// Список снимков: восстановление, экспорт на другое устройство, импорт.
///
/// Виджет ничего не знает про ошибки и занятость — и то, и другое приходит
/// из состояния [SavesBloc].
class SnapshotsSection extends StatelessWidget {
  const SnapshotsSection({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final saves = context.watch<SavesBloc>().state;
    final snapshots = saves.snapshotsFor(game.id);
    final busy = saves.isBusy(SavesBloc.snapshotKey(game.id));

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
            onPressed:
                busy ||
                    (!game.saveProfile.isConfigured &&
                        game.ludusaviTemplates.isEmpty)
                ? null
                : () => context.read<SavesBloc>().add(SnapshotRequested(game)),
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
                  SnapshotTile(
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
    final saves = context.read<SavesBloc>();
    final options = await showDialog<RestoreOptions>(
      context: context,
      builder: (_) => RestoreDialog(snapshot: snapshot, game: game),
    );
    if (options == null) return;

    saves.add(
      SnapshotRestoreRequested(
        game: game,
        snapshot: snapshot,
        backupCurrent: options.backupCurrent,
        wipeTarget: options.wipeTarget,
      ),
    );
  }

  Future<void> _export(BuildContext context, SaveSnapshot snapshot) async {
    final saves = context.read<SavesBloc>();
    final suggested =
        safeFileName(
          '${snapshot.gameTitle} ${formatDateTime(snapshot.createdAt)}',
        ) +
        SaveSnapshot.fileExtension;

    final location = await getSaveLocation(suggestedName: suggested);
    if (location == null) return;
    saves.add(
      SnapshotExportRequested(snapshot: snapshot, destination: location.path),
    );
  }

  Future<void> _delete(BuildContext context, SaveSnapshot snapshot) async {
    final saves = context.read<SavesBloc>();
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
    saves.add(SnapshotDeleted(snapshot));
  }

  Future<void> _import(BuildContext context) async {
    final saves = context.read<SavesBloc>();
    final group = XTypeGroup(
      label: L.of(context).savePackage,
      extensions: const ['evsave', 'zip'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null || !context.mounted) return;

    try {
      final info = await saves.saveManager.inspectPackage(file.path);
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
      saves.add(SnapshotImportRequested(path: file.path, game: game));
    } on Object catch (error) {
      // Чтение чужого файла — единственное место, где ошибка возникает
      // до входа в кубит.
      if (context.mounted) showError(context, error);
    }
  }
}

// ------------------------------------------------------------- диалоги

import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/saves/saves_bloc.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../models/save_snapshot.dart';
import '../../feedback/confirm.dart';
import '../../labels.dart';
import '../../theme.dart';
import '../../widgets/busy_spinner.dart';
import '../../widgets/section_card.dart';
import 'restore_dialog.dart';
import 'restore_options.dart';
import 'snapshot_actions.dart';
import 'snapshot_tile.dart';

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

    // Разобранный пакет приходит из состояния, а спрашивают о нём здесь:
    // окно с вопросом — дело интерфейса, чтение чужого файла — нет.
    return BlocListener<SavesBloc, SavesState>(
      listenWhen: (before, after) =>
          after.pendingImport != null &&
          after.pendingImport != before.pendingImport,
      listener: (context, state) {
        final pending = state.pendingImport;
        if (pending == null || pending.game.id != game.id) return;
        unawaited(_askAboutImport(context, pending));
      },
      child: SectionCard(
        title: L.of(context).snapshots,
        icon: Icons.history,
        trailing: _SnapshotButtons(
          busy: busy,
          onImport: () => _import(context),
          // Снимать нечего, пока не сказано откуда.
          onTake:
              game.saveProfile.isConfigured ||
                  game.saveDiscovery.ludusaviTemplates.isNotEmpty
              ? () => context.read<SavesBloc>().add(SnapshotRequested(game))
              : null,
        ),
        child: snapshots.isEmpty
            ? Text(L.of(context).noSnapshotsNote, style: context.text.paragraph)
            : Column(
                children: [
                  for (final snapshot in snapshots)
                    SnapshotTile(
                      snapshot: snapshot,
                      onRestore: () => _restore(context, snapshot),
                      onExport: () => exportSnapshot(context, snapshot),
                      onDelete: () => deleteSnapshot(context, game, snapshot),
                    ),
                ],
              ),
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

  /// Выбор файла — дело окна, разбор пакета — дело блока: файл чужой, и
  /// прочитаться он может не до конца.
  Future<void> _import(BuildContext context) async {
    final saves = context.read<SavesBloc>();
    final group = XTypeGroup(
      label: L.of(context).savePackage,
      extensions: const ['evsave', 'zip'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    saves.add(SnapshotImportInspectRequested(path: file.path, game: game));
  }

  /// Спрашивает о разобранном пакете и заводит его, если согласились.
  Future<void> _askAboutImport(
    BuildContext context,
    PendingImport pending,
  ) async {
    final saves = context.read<SavesBloc>();
    final snapshot = pending.info.snapshot;
    final ok = await confirm(
      context,
      title: L.of(context).importSnapshotQuestion,
      message: L
          .of(context)
          .importSnapshotNote(
            snapshot.gameTitle,
            dateTimeLabel(L.of(context), snapshot.createdAt),
            snapshot.deviceName,
            platformLabel(snapshot.platform),
            snapshot.fileCount,
            pending.game.title,
          ),
      confirmLabel: L.of(context).importAction,
    );
    if (!ok) {
      saves.add(const SnapshotImportDismissed());
      return;
    }
    saves.add(
      SnapshotImportRequested(path: pending.info.path, game: pending.game),
    );
  }
}

/// Клавиши снимков в заголовке карточки. Переносом, а не строкой: строка
/// забирала бы у заголовка всю ширину и уводила клавиши под имя карточки
/// в любом окне.
class _SnapshotButtons extends StatelessWidget {
  const _SnapshotButtons({
    required this.busy,
    required this.onImport,
    required this.onTake,
  });

  final bool busy;
  final VoidCallback onImport;

  /// Нет — снять нельзя.
  final VoidCallback? onTake;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: EvaporateSpacing.line,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      TextButton.icon(
        onPressed: busy ? null : onImport,
        icon: const Icon(Icons.file_download_outlined),
        label: Text(L.of(context).importShort),
      ),
      FilledButton.icon(
        onPressed: busy ? null : onTake,
        style: context.buttons.compactFilled,
        icon: busy
            ? const BusySpinner()
            : const Icon(Icons.add_a_photo_outlined),
        label: Text(L.of(context).takeSnapshot),
      ),
    ],
  );
}

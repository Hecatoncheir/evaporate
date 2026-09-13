import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../core/format.dart';
import '../../../models/game.dart';
import '../../../models/save_snapshot.dart';
import '../../theme.dart';
import '../../../bloc/save_freshness_cubit.dart';
import '../../../l10n/app_localizations.dart';

class RestoreOptions {
  const RestoreOptions({required this.backupCurrent, required this.wipeTarget});

  final bool backupCurrent;
  final bool wipeTarget;
}

class RestoreDialog extends StatefulWidget {
  const RestoreDialog({super.key, required this.snapshot, required this.game});

  final SaveSnapshot snapshot;
  final Game game;

  @override
  State<RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<RestoreDialog> {
  bool _backup = true;
  bool _wipe = false;

  /// Здешние сохранения новее снимка настолько, что восстановление —
  /// это откат прогресса.
  ///
  /// Допуск тот же, что и у массового переноса: часы разных устройств
  /// расходятся, а время изменения файла хранится с разной точностью на
  /// разных файловых системах.
  bool _isNewer(DateTime? local) =>
      local != null &&
      local.isAfter(
        widget.snapshot.createdAt.add(LibraryBloc.conflictTolerance),
      );

  @override
  Widget build(BuildContext context) {
    // Чтение диска живёт в Cubit: виджету не положено ни держать
    // асинхронность, ни ловить её ошибки — это правило блоков, и модальное
    // окно от него не освобождено.
    return BlocProvider(
      create: (context) =>
          SaveFreshnessCubit(context.read<LibraryBloc>().saveManager)
            ..read(widget.game),
      child: Builder(builder: _content),
    );
  }

  Widget _content(BuildContext context) {
    // Спрашиваем у менеджера, а не считаем сами: раскладывать файлы будет
    // он, и обещать здесь что-то своё значит обещать не то.
    final targets = context.read<LibraryBloc>().saveManager.previewTargets(
      widget.game,
      widget.snapshot,
    );

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
            // Массовый перенос такие расхождения ловит сам, а здесь до сих
            // пор молчали — притом что восстановить одну игру просят чаще,
            // чем переехать всей библиотекой.
            BlocBuilder<SaveFreshnessCubit, SaveFreshness>(
              builder: (context, freshness) {
                if (!freshness.known) return const SizedBox.shrink();
                final newer = _isNewer(freshness.changedAt);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      freshness.changedAt == null
                          ? L.of(context).localNeverChanged
                          : L
                                .of(context)
                                .localChangedAt(
                                  formatDateTime(freshness.changedAt!),
                                ),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: newer
                            ? context.colors.warning
                            : context.colors.textSecondary,
                      ),
                    ),
                    if (newer) ...[
                      const SizedBox(height: 4),
                      Text(
                        L.of(context).localNewerWarning,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: context.colors.warning,
                        ),
                      ),
                    ],
                  ],
                );
              },
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
                  RestoreOptions(backupCurrent: _backup, wipeTarget: _wipe),
                ),
          child: Text(L.of(context).restore),
        ),
      ],
    );
  }
}

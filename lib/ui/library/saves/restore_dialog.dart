import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../core/format.dart';
import '../../../models/game.dart';
import '../../../models/save_profile.dart';
import '../../../models/save_snapshot.dart';
import '../../theme.dart';
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

  /// Когда здешние сохранения менялись в последний раз.
  ///
  /// Читается с диска, поэтому появляется не сразу: до ответа строку не
  /// показываем вовсе — «неизвестно» здесь хуже молчания.
  DateTime? _localChange;
  bool _localRead = false;

  @override
  void initState() {
    super.initState();
    unawaited(_readLocalChange());
  }

  Future<void> _readLocalChange() async {
    final manager = context.read<LibraryBloc>().saveManager;
    try {
      final when = await manager.lastLocalChange(widget.game);
      if (mounted) setState(() => _localChange = when);
    } on Object {
      // Не прочиталось — просто не покажем строку.
    } finally {
      if (mounted) setState(() => _localRead = true);
    }
  }

  /// Здешние сохранения новее снимка настолько, что восстановление —
  /// это откат прогресса.
  ///
  /// Допуск тот же, что и у массового переноса: часы разных устройств
  /// расходятся, а время изменения файла хранится с разной точностью на
  /// разных файловых системах.
  bool get _localIsNewer {
    final local = _localChange;
    if (local == null) return false;
    return local.isAfter(
      widget.snapshot.createdAt.add(LibraryBloc.conflictTolerance),
    );
  }

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
            // Массовый перенос такие расхождения ловит сам, а здесь до сих
            // пор молчали — притом что восстановить одну игру просят чаще,
            // чем переехать всей библиотекой.
            if (_localRead) ...[
              const SizedBox(height: 6),
              Text(
                _localChange == null
                    ? L.of(context).localNeverChanged
                    : L
                          .of(context)
                          .localChangedAt(formatDateTime(_localChange!)),
                style: TextStyle(
                  fontSize: 12.5,
                  color: _localIsNewer
                      ? context.colors.warning
                      : context.colors.textSecondary,
                ),
              ),
              if (_localIsNewer) ...[
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
      if (match == null) continue;
      final resolved = match.resolve(gameDir: widget.game.installDir);
      if (resolved != null) targets[match.label] = resolved;
    }
    return targets;
  }
}

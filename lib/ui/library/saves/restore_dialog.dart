import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/save_freshness_cubit.dart';
import '../../../bloc/saves/saves_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../models/save_snapshot.dart';
import 'restore/restore_dialog_body.dart';
import 'restore_options.dart';

/// Окно восстановления снимка: что восстанавливаем, куда и на каких
/// условиях.
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

  @override
  Widget build(BuildContext context) {
    // Чтение диска живёт в Cubit: виджету не положено ни держать
    // асинхронность, ни ловить её ошибки — это правило блоков, и модальное
    // окно от него не освобождено.
    return BlocProvider(
      create: (context) =>
          SaveFreshnessCubit(context.read<SavesBloc>().saveManager)
            ..read(widget.game),
      child: Builder(
        builder: (context) {
          // Спрашиваем у менеджера, а не считаем сами: раскладывать файлы
          // будет он, и обещать здесь что-то своё значит обещать не то.
          final targets = context.read<SavesBloc>().saveManager.previewTargets(
            widget.game,
            widget.snapshot,
          );
          final l = L.of(context);

          return AlertDialog(
            title: Text(l.restoreSaves),
            content: RestoreDialogBody(
              snapshot: widget.snapshot,
              targets: targets,
              backup: _backup,
              wipe: _wipe,
              onBackup: (value) => setState(() => _backup = value),
              onWipe: (value) => setState(() => _wipe = value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.cancel),
              ),
              FilledButton(
                // Восстанавливать некуда — клавиша погашена, а куда именно
                // некуда, сказано выше списком целей.
                onPressed: targets.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context,
                        RestoreOptions(
                          backupCurrent: _backup,
                          wipeTarget: _wipe,
                        ),
                      ),
                child: Text(l.restore),
              ),
            ],
          );
        },
      ),
    );
  }
}

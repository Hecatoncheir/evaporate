import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/restore_preview/restore_preview_bloc.dart';
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
  var _options = const RestoreOptions(backupCurrent: true, wipeTarget: false);

  @override
  Widget build(BuildContext context) {
    // Чтение диска живёт в блоке: виджету не положено ни держать
    // асинхронность, ни ловить её ошибки — это правило блоков, и модальное
    // окно от него не освобождено.
    return BlocProvider(
      create: (context) =>
          RestorePreviewBloc(context.read<SavesBloc>().saveManager)..add(
            RestorePreviewRequested(
              game: widget.game,
              snapshot: widget.snapshot,
            ),
          ),
      child: BlocBuilder<RestorePreviewBloc, RestorePreview>(
        builder: (context, preview) {
          final l = L.of(context);

          return AlertDialog(
            title: Text(l.restoreSaves),
            content: RestoreDialogBody(
              snapshot: widget.snapshot,
              preview: preview,
              options: _options,
              onOptions: (patch) => setState(() => _options = patch(_options)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.cancel),
              ),
              FilledButton(
                // Восстанавливать некуда — клавиша погашена, а куда именно
                // некуда, сказано выше списком целей.
                onPressed: preview.targets.isEmpty
                    ? null
                    : () => Navigator.pop(context, _options),
                child: Text(l.restore),
              ),
            ],
          );
        },
      ),
    );
  }
}

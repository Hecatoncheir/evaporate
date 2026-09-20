import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/add_game/add_game_bloc.dart';
import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/busy_spinner.dart';
import 'add_game_fields.dart';

/// Окно «Добавить игру» изнутри: поля и клавиши под ними.
class AddGameDialogView extends StatelessWidget {
  const AddGameDialogView({
    super.key,
    required this.form,
    required this.magnetController,
    required this.titleController,
    required this.onMagnetChanged,
    required this.onPickTorrent,
    required this.onPickFolder,
  });

  final AddGameForm form;
  final TextEditingController magnetController;
  final TextEditingController titleController;

  /// Ссылку разбирает окно: из неё подставляется название, а это
  /// контроллер текста, то есть ресурс.
  final ValueChanged<String> onMagnetChanged;

  /// Системные окна выбора — тоже дело окна, а не блока.
  final VoidCallback onPickTorrent;
  final VoidCallback onPickFolder;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bloc = context.read<AddGameBloc>();
    final engine = context.watch<DownloadsBloc>().state.engine;

    return AlertDialog(
      title: Text(l.addGame),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: AddGameFields(
            kind: form.kind,
            onKind: (value) => bloc.add(AddGameKindChanged(value)),
            magnetController: magnetController,
            titleController: titleController,
            filePath: form.filePath,
            folderPath: form.folderPath,
            onMagnetChanged: onMagnetChanged,
            onTitleChanged: (value) => bloc.add(AddGameTitleChanged(value)),
            onPickTorrent: onPickTorrent,
            onPickFolder: onPickFolder,
            startImmediately: form.startImmediately,
            onStartImmediately: (value) =>
                bloc.add(AddGameStartImmediatelyChanged(start: value)),
            engine: engine,
            error: form.error,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: form.busy ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: form.busy
              ? null
              : () => bloc.add(const AddGameSubmitted()),
          child: form.busy ? const BusySpinner(size: 16) : Text(l.add),
        ),
      ],
    );
  }
}

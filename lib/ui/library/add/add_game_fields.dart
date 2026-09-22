import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/add_game/add_game_bloc.dart';
import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../services/download/download_engine.dart';
import '../../labels.dart';
import '../../theme.dart';
import 'source_fields.dart';
import 'source_kind_picker.dart';
import 'start_now_tile.dart';

/// Содержимое окна «Добавить игру»: откуда брать, что именно, как назвать и
/// ставить ли сразу в загрузку.
///
/// Форму и движок поля читают сами, и события блоку шлют сами: прежде окно
/// передавало сюда четырнадцать параметров, из которых одиннадцать ему не
/// были нужны вовсе. Снаружи приходит только то, что принадлежит окну, —
/// контроллеры текста и системные окна выбора.
class AddGameFields extends StatelessWidget {
  const AddGameFields({
    super.key,
    required this.magnetController,
    required this.titleController,
    required this.onMagnetChanged,
    required this.onPickTorrent,
    required this.onPickFolder,
  });

  final TextEditingController magnetController;
  final TextEditingController titleController;

  /// Ссылку разбирает окно: из неё подставляется название в контроллер.
  final ValueChanged<String> onMagnetChanged;
  final VoidCallback onPickTorrent;
  final VoidCallback onPickFolder;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bloc = context.read<AddGameBloc>();
    final form = context.watch<AddGameBloc>().state;
    final kind = form.kind;
    final engine = context.select<DownloadsBloc, EngineStatus>(
      (downloads) => downloads.state.engine,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SourceKindPicker(
          kind: kind,
          onChanged: (value) => bloc.add(AddGameKindChanged(value)),
        ),
        const SizedBox(height: EvaporateSpacing.section),
        SourceFields(
          kind: kind,
          magnetController: magnetController,
          filePath: form.filePath,
          folderPath: form.folderPath,
          onMagnetChanged: onMagnetChanged,
          onPickTorrent: onPickTorrent,
          onPickFolder: onPickFolder,
        ),
        const SizedBox(height: EvaporateSpacing.panel),
        TextField(
          controller: titleController,
          onChanged: (value) => bloc.add(AddGameTitleChanged(value)),
          decoration: InputDecoration(
            labelText: l.title,
            hintText: l.titleHint,
          ),
        ),
        // У папки на диске качать нечего: она уже установлена.
        if (kind != GameSourceKind.localFolder) ...[
          const SizedBox(height: EvaporateSpacing.gap),
          StartNowTile(
            value: form.startImmediately,
            ready: engine.isReady,
            engineState: engineStateLabel(l, engine.state),
            onChanged: (value) =>
                bloc.add(AddGameStartImmediatelyChanged(start: value)),
          ),
        ],
        if (form.error case final message?) ...[
          const SizedBox(height: EvaporateSpacing.field),
          Text(
            message,
            style: context.text.body.copyWith(color: context.colors.danger),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../bloc/add_game/add_game_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../theme.dart';
import 'path_picker_field.dart';

/// То, что принадлежит окну «Добавить игру», а не его блоку: контроллеры
/// текста и системные окна выбора — ресурсы, а не состояние.
///
/// Одним значением: прежде эти пять штук спускались поодиночке через три
/// виджета, и ни одному посередине не были нужны. Разбор ссылки — тоже
/// дело окна: из неё подставляется название, а это контроллер текста.
typedef AddGameInputs = ({
  TextEditingController magnet,
  TextEditingController title,
  ValueChanged<String> onMagnetChanged,
  VoidCallback pickTorrent,
  VoidCallback pickFolder,
});

/// Поля источника: своё для magnet-ссылки, файла раздачи и папки на диске.
class SourceFields extends StatelessWidget {
  const SourceFields({super.key, required this.form, required this.inputs});

  final AddGameForm form;
  final AddGameInputs inputs;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return switch (form.kind) {
      GameSourceKind.magnet => TextField(
        controller: inputs.magnet,
        maxLines: 3,
        minLines: 2,
        onChanged: inputs.onMagnetChanged,
        decoration: InputDecoration(
          labelText: l.sourceMagnet,
          hintText: 'magnet:?xt=urn:btih:...',
        ),
      ),
      GameSourceKind.torrentFile => PathPickerField(
        label: l.sourceTorrent,
        value: form.filePath,
        icon: Icons.description_outlined,
        onPick: inputs.pickTorrent,
      ),
      GameSourceKind.localFolder => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PathPickerField(
            label: l.gameFolder,
            value: form.folderPath,
            icon: Icons.folder_outlined,
            onPick: inputs.pickFolder,
          ),
          const SizedBox(height: EvaporateSpacing.gap),
          Text(l.localFolderNote, style: context.text.paragraph),
        ],
      ),
    };
  }
}

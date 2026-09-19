import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../theme.dart';
import '../../widgets/path_picker_field.dart';

/// Поля источника: своё для magnet-ссылки, файла раздачи и папки на диске.
class SourceFields extends StatelessWidget {
  const SourceFields({
    super.key,
    required this.kind,
    required this.magnetController,
    required this.filePath,
    required this.folderPath,
    required this.onMagnetChanged,
    required this.onPickTorrent,
    required this.onPickFolder,
  });

  final GameSourceKind kind;
  final TextEditingController magnetController;
  final String? filePath;
  final String? folderPath;
  final ValueChanged<String> onMagnetChanged;
  final VoidCallback onPickTorrent;
  final VoidCallback onPickFolder;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return switch (kind) {
      GameSourceKind.magnet => TextField(
        controller: magnetController,
        maxLines: 3,
        minLines: 2,
        onChanged: onMagnetChanged,
        decoration: InputDecoration(
          labelText: l.sourceMagnet,
          hintText: 'magnet:?xt=urn:btih:...',
        ),
      ),
      GameSourceKind.torrentFile => PathPickerField(
        label: l.sourceTorrent,
        value: filePath,
        icon: Icons.description_outlined,
        onPick: onPickTorrent,
      ),
      GameSourceKind.localFolder => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PathPickerField(
            label: l.gameFolder,
            value: folderPath,
            icon: Icons.folder_outlined,
            onPick: onPickFolder,
          ),
          const SizedBox(height: 8),
          Text(l.localFolderNote, style: context.text.paragraph),
        ],
      ),
    };
  }
}

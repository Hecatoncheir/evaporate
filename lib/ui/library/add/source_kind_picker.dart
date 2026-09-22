import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';

/// Откуда берём игру: magnet-ссылка, файл раздачи или папка на диске.
class SourceKindPicker extends StatelessWidget {
  const SourceKindPicker({
    super.key,
    required this.kind,
    required this.onChanged,
  });

  final GameSourceKind kind;
  final ValueChanged<GameSourceKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<GameSourceKind>(
      segments: [
        const ButtonSegment(
          value: GameSourceKind.magnet,
          icon: Icon(Icons.link),
          label: Text('Magnet'),
        ),
        const ButtonSegment(
          value: GameSourceKind.torrentFile,
          icon: Icon(Icons.description_outlined),
          label: Text('.torrent'),
        ),
        ButtonSegment(
          value: GameSourceKind.localFolder,
          icon: const Icon(Icons.folder_outlined),
          label: Text(L.of(context).sourceFolder),
        ),
      ],
      selected: {kind},
      onSelectionChanged: (value) => onChanged(value.first),
    );
  }
}

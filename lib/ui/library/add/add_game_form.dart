import 'package:flutter/material.dart';

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
class AddGameForm extends StatelessWidget {
  const AddGameForm({
    super.key,
    required this.kind,
    required this.onKind,
    required this.magnetController,
    required this.titleController,
    required this.filePath,
    required this.folderPath,
    required this.onMagnetChanged,
    required this.onPickTorrent,
    required this.onPickFolder,
    required this.startImmediately,
    required this.onStartImmediately,
    required this.engine,
    required this.error,
  });

  final GameSourceKind kind;
  final ValueChanged<GameSourceKind> onKind;
  final TextEditingController magnetController;
  final TextEditingController titleController;
  final String? filePath;
  final String? folderPath;
  final ValueChanged<String> onMagnetChanged;
  final VoidCallback onPickTorrent;
  final VoidCallback onPickFolder;
  final bool startImmediately;
  final ValueChanged<bool> onStartImmediately;

  /// Состояние движка: от него зависит, можно ли ставить загрузку сразу.
  final EngineStatus engine;

  /// Почему добавить не вышло; `null` — пока не пробовали.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SourceKindPicker(kind: kind, onChanged: onKind),
        const SizedBox(height: 20),
        SourceFields(
          kind: kind,
          magnetController: magnetController,
          filePath: filePath,
          folderPath: folderPath,
          onMagnetChanged: onMagnetChanged,
          onPickTorrent: onPickTorrent,
          onPickFolder: onPickFolder,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: l.title,
            hintText: l.titleHint,
          ),
        ),
        // У папки на диске качать нечего: она уже установлена.
        if (kind != GameSourceKind.localFolder) ...[
          const SizedBox(height: 8),
          StartNowTile(
            value: startImmediately,
            ready: engine.isReady,
            engineState: engineStateLabel(l, engine.state),
            onChanged: onStartImmediately,
          ),
        ],
        if (error case final message?) ...[
          const SizedBox(height: 12),
          Text(
            message,
            style: context.text.body.copyWith(color: context.colors.danger),
          ),
        ],
      ],
    );
  }
}

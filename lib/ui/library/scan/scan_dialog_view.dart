import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/scan/scan_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/launch/scan_session.dart';
import 'scan_dialog_body.dart';

/// Окно поиска изнутри: содержимое и клавиши под ним.
class ScanDialogView extends StatelessWidget {
  const ScanDialogView({
    super.key,
    required this.session,
    required this.scan,
    required this.dragging,
    required this.onDragging,
    required this.onPickFolder,
    required this.onAdd,
  });

  final ScanSession session;
  final ScanState scan;
  final bool dragging;
  final ValueChanged<bool> onDragging;
  final VoidCallback onPickFolder;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return AlertDialog(
      title: Text(l.gamesInFolder),
      content: ScanDialogBody(
        session: session,
        scan: scan,
        dragging: dragging,
        onDragging: onDragging,
        onPickFolder: onPickFolder,
      ),
      actions: [
        // Клавиши списком прямо здесь: `AlertDialog.actions` ждёт именно
        // список кнопок, и обёртка вокруг них сломала бы его раскладку
        // переполнения.
        if (scan.running)
          TextButton.icon(
            onPressed: () =>
                context.read<ScanBloc>().add(const ScanStopRequested()),
            icon: const Icon(Icons.stop_circle_outlined, size: 16),
            label: Text(l.scanStop),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: scan.selected.isEmpty ? null : onAdd,
          child: Text(l.addCount(scan.selected.length)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/scan/scan_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/launch/scan_session.dart';
import '../../theme.dart';
import 'scan_drop_area.dart';
import 'scan_progress.dart';
import 'scanned_games_list.dart';

/// Содержимое окна поиска: ход обхода, куда бросить папку и что нашлось.
class ScanDialogBody extends StatelessWidget {
  const ScanDialogBody({
    super.key,
    required this.session,
    required this.scan,
    required this.dragging,
    required this.onDragging,
    required this.onPickFolder,
  });

  final ScanSession session;
  final ScanState scan;

  /// Папку держат над окном. Это не состояние, а положение мыши, поэтому
  /// живёт у самого окна, а не в блоке.
  final bool dragging;

  final ValueChanged<bool> onDragging;
  final VoidCallback onPickFolder;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bloc = context.read<ScanBloc>();

    return SizedBox(
      width: EvaporateLayout.dialogWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScanProgress(session: session),
          const SizedBox(height: 12),
          ScanDropArea(
            dragging: dragging,
            wrongDrop: scan.wrongDrop,
            onTap: onPickFolder,
            onEntered: () => onDragging(true),
            onExited: () => onDragging(false),
            onDrop: (details) {
              onDragging(false);
              bloc.add(
                ScanFolderDropped([
                  for (final file in details.files) file.path,
                ]),
              );
            },
          ),
          if (scan.found.isNotEmpty) ...[
            const SizedBox(height: 12),
            Flexible(
              child: ScannedGamesList(
                games: scan.found,
                isSelected: scan.isSelected,
                onToggle: (game, {required selected}) =>
                    bloc.add(ScanGameToggled(game, selected: selected)),
              ),
            ),
          ] else if (!scan.running && scan.complete) ...[
            const SizedBox(height: 12),
            Text(
              l.scanNothingFound,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

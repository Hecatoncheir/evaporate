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
    required this.onPickFolder,
  });

  final ScanSession session;
  final ScanState scan;
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
          const SizedBox(height: EvaporateSpacing.field),
          ScanDropArea(onTap: onPickFolder),
          if (scan.found.isNotEmpty) ...[
            const SizedBox(height: EvaporateSpacing.field),
            Flexible(
              child: ScannedGamesList(
                games: scan.found,
                isSelected: scan.isSelected,
                onToggle: (game, {required selected}) =>
                    bloc.add(ScanGameToggled(game, selected: selected)),
              ),
            ),
          ] else if (!scan.running && scan.complete) ...[
            const SizedBox(height: EvaporateSpacing.field),
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

import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../services/launch/executable_finder.dart';
import '../../theme.dart';
import '../../widgets/info_row.dart';
import '../../widgets/section_card.dart';
import 'executable_picker_dialog.dart';

class FilesSection extends StatelessWidget {
  const FilesSection({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    // Найденное приходит из состояния, а спрашивают о нём здесь: обход
    // папки — не дело виджета, а окно с вопросом — не дело блока.
    return BlocListener<LibraryBloc, LibraryState>(
      listenWhen: (before, after) =>
          after.pendingExecutables != null &&
          after.pendingExecutables != before.pendingExecutables,
      listener: (context, state) {
        final pick = state.pendingExecutables;
        if (pick == null || pick.gameId != game.id) return;
        unawaited(_askWhatToRun(context, pick));
      },
      child: SectionCard(
        title: L.of(context).gameFiles,
        icon: Icons.folder_outlined,
        child: Column(
          children: [
            InfoRow(
              label: L.of(context).installFolder,
              value: game.installDir ?? L.of(context).notSet,
              monospace: game.installDir != null,
              valueColor: game.installDir == null
                  ? context.colors.textSecondary
                  : null,
            ),
            InfoRow(
              label: L.of(context).whatToRun,
              value: game.executablePath ?? L.of(context).notChosen,
              monospace: game.executablePath != null,
              valueColor: game.executablePath == null
                  ? context.colors.textSecondary
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickExecutable(context),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: Text(L.of(context).chooseFile),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: game.installDir == null
                      ? null
                      : () => context.read<LibraryBloc>().add(
                          GameExecutableDetectRequested(game.id),
                        ),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: Text(L.of(context).findAutomatically),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickExecutable(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final file = await openFile();
    if (file == null) return;
    library.add(GameExecutableSet(game.id, file.path));
  }

  /// Спрашивает, что запускать, из найденного блоком.
  Future<void> _askWhatToRun(BuildContext context, ExecutablePick pick) async {
    final library = context.read<LibraryBloc>();
    final dir = game.installDir;
    if (dir == null) return;

    final chosen = await showDialog<ExecutableCandidate>(
      context: context,
      builder: (context) =>
          ExecutablePickerDialog(candidates: pick.candidates, installDir: dir),
    );
    if (chosen == null) {
      library.add(const GameExecutablePickDismissed());
      return;
    }
    library.add(GameExecutableSet(game.id, chosen.path));
  }
}

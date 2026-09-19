import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../widgets/launcher_action_button.dart';

/// Игра ещё не скачана: начать загрузку или сперва выбрать, куда её класть.
class DownloadStartActions extends StatelessWidget {
  const DownloadStartActions({
    super.key,
    required this.game,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final Game game;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LauncherActionButton(onPressed: onPressed, icon: icon, label: label),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => _pickInstallDir(context),
          icon: const Icon(Icons.folder_outlined, size: 17),
          label: Text(L.of(context).setFolder),
        ),
      ],
    );
  }

  Future<void> _pickInstallDir(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final dir = await getDirectoryPath();
    if (dir == null) return;
    library.add(GameInstallDirSet(game.id, dir));
  }
}

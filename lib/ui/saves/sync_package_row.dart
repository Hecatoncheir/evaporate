import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../bloc/saves/saves_bloc.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../services/saves/save_manager.dart';
import '../feedback/confirm.dart';
import '../feedback/snack.dart';
import '../theme.dart';
import '../widgets/inset_tile.dart';
import 'pick_game_dialog.dart';

/// Пакет с другого устройства: чей он, когда снят — и клавиша «применить».
class SyncPackageRow extends StatelessWidget {
  const SyncPackageRow({super.key, required this.package});

  final SavePackageInfo package;

  @override
  Widget build(BuildContext context) {
    final snapshot = package.snapshot;
    return InsetTile(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(snapshot.gameTitle, style: context.text.bodyStrong),
                const SizedBox(height: 3),
                Text(
                  '${formatDateTime(snapshot.createdAt)} · '
                  '${snapshot.deviceName} · '
                  '${platformLabel(snapshot.platform)} · '
                  '${L.of(context).filesCount(snapshot.fileCount)}',
                  style: context.text.captionMuted,
                ),
              ],
            ),
          ),
          if (!package.isCompatible)
            Tooltip(
              message: L.of(context).noPathsForPlatform,
              child: Icon(
                Icons.warning_amber_rounded,
                size: 17,
                color: context.colors.warning,
              ),
            ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _apply(context),
            style: context.buttons.compactFilled,
            child: Text(L.of(context).apply),
          ),
        ],
      ),
    );
  }

  /// Импорт пакета и немедленное восстановление — путь «взял и играю дальше».
  Future<void> _apply(BuildContext context) async {
    final saves = context.read<SavesBloc>();
    final game = await _pickGame(context);
    if (game == null || !context.mounted) return;

    final ok = await confirm(
      context,
      title: L.of(context).applySaves,
      message: L
          .of(context)
          .applyNote(
            package.snapshot.gameTitle,
            formatDateTime(package.snapshot.createdAt),
            package.snapshot.deviceName,
            game.title,
          ),
      confirmLabel: L.of(context).apply,
    );
    if (!ok || !context.mounted) return;

    // Импорт и восстановление — одно событие; итог сообщит блок.
    saves.add(SyncPackageApplied(path: package.path, game: game));
  }

  Future<Game?> _pickGame(BuildContext context) async {
    final games = context.read<LibraryBloc>().state.games;
    if (games.isEmpty) {
      showError(context, L.of(context).addGameFirst);
      return null;
    }
    return showDialog<Game>(
      context: context,
      builder: (_) =>
          PickGameDialog(games: games, title: package.snapshot.gameTitle),
    );
  }
}

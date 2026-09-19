import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/saves/saves_bloc.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../models/save_snapshot.dart';
import '../feedback/confirm.dart';
import '../theme.dart';
import '../widgets/hover_builder.dart';
import '../widgets/tile_icon_button.dart';
import 'snapshot_summary.dart';

/// Строка снимка: чья игра, когда снят, чем снят — и что с ним можно сделать.
///
/// Под курсором строка подсвечивается: действия у неё по краю, и без
/// подсветки в длинном списке легко нажать «удалить» у соседнего снимка.
class SnapshotRow extends StatelessWidget {
  const SnapshotRow({super.key, required this.game, required this.snapshot});

  final Game game;
  final SaveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l = L.of(context);

    return HoverBuilder(
      child: SnapshotSummary(game: game, snapshot: snapshot),
      builder: (context, hovered, summary) => AnimatedContainer(
        duration: context.motion.fast,
        curve: EvaporateMotion.ease,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
        decoration: BoxDecoration(
          color: hovered
              ? Color.lerp(colors.surfaceHigh, colors.primary, 0.08)
              : colors.surfaceHigh,
          borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
          border: Border.all(
            color: hovered
                ? colors.primary.withValues(alpha: EvaporateAlpha.strong)
                : colors.outline,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: summary!),
            TileIconButton(
              icon: Icons.ios_share,
              tooltip: l.exportFile,
              onPressed: () => _export(context),
            ),
            TileIconButton(
              icon: Icons.delete_outline,
              tooltip: l.delete,
              // Тревожный цвет — только под курсором: ряд постоянно красных
              // корзин в списке читается как список ошибок.
              color: hovered ? colors.danger : colors.textSecondary,
              onPressed: () => _delete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final saves = context.read<SavesBloc>();
    final suggested =
        safeFileName(snapshot.gameTitle) + SaveSnapshot.fileExtension;
    final location = await getSaveLocation(suggestedName: suggested);
    if (location == null) return;
    saves.add(
      SnapshotExportRequested(snapshot: snapshot, destination: location.path),
    );
  }

  /// Удаление необратимо, поэтому спрашиваем — и называем в вопросе саму
  /// игру: в общем списке снимков разных игр одной даты недостаточно.
  Future<void> _delete(BuildContext context) async {
    final saves = context.read<SavesBloc>();
    final l = L.of(context);
    final ok = await confirm(
      context,
      title: l.deleteSnapshotQuestion,
      message:
          '${game.title}\n'
          '${l.deleteSnapshotNote(formatDateTime(snapshot.createdAt))}',
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!ok) return;
    saves.add(SnapshotDeleted(snapshot));
  }
}

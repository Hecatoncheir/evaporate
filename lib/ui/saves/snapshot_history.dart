import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/saves/saves_bloc.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../models/save_snapshot.dart';
import '../feedback/confirm.dart';
import '../labels.dart';
import '../library/saves/save_tag.dart';
import '../theme.dart';
import '../widgets/section_card.dart';

/// Снимок вместе с игрой, которой он принадлежит.
///
/// Список на этом экране общий на всю библиотеку, и одного снимка для
/// строки мало: название игры лежит в игре, а не в нём.
typedef SnapshotEntry = (Game game, SaveSnapshot snapshot);

/// Хронология: все снимки библиотеки, свежие сверху.
class SnapshotsCard extends StatelessWidget {
  const SnapshotsCard({super.key, required this.entries});

  final List<SnapshotEntry> entries;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: L.of(context).allSnapshots,
    icon: Icons.history,
    trailing: Text(
      '${entries.length}',
      style: context.text.figure.copyWith(color: context.colors.textSecondary),
    ),
    child: entries.isEmpty
        ? Text(L.of(context).noSnapshotsYet, style: context.text.paragraph)
        : Column(
            children: [
              for (final (game, snapshot) in entries)
                _SnapshotRow(game: game, snapshot: snapshot),
            ],
          ),
  );
}

/// Строка снимка: чья игра, когда снят, чем снят — и что с ним можно сделать.
///
/// Под курсором строка подсвечивается: действия у неё по краю, и без
/// подсветки в длинном списке легко нажать «удалить» у соседнего снимка.
class _SnapshotRow extends StatefulWidget {
  const _SnapshotRow({required this.game, required this.snapshot});

  final Game game;
  final SaveSnapshot snapshot;

  @override
  State<_SnapshotRow> createState() => _SnapshotRowState();
}

class _SnapshotRowState extends State<_SnapshotRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l = L.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: context.motion.fast,
        curve: EvaporateMotion.ease,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
        decoration: BoxDecoration(
          color: _hovered
              ? Color.lerp(colors.surfaceHigh, colors.primary, 0.08)
              : colors.surfaceHigh,
          borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
          border: Border.all(
            color: _hovered
                ? colors.primary.withValues(alpha: EvaporateAlpha.strong)
                : colors.outline,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: _summary(context)),
            IconButton(
              tooltip: l.exportFile,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.ios_share, size: 17),
              onPressed: _export,
            ),
            IconButton(
              tooltip: l.delete,
              visualDensity: VisualDensity.compact,
              // Тревожный цвет — только под курсором: ряд постоянно красных
              // корзин в списке читается как список ошибок.
              color: _hovered ? colors.danger : colors.textSecondary,
              icon: const Icon(Icons.delete_outline, size: 17),
              onPressed: _delete,
            ),
          ],
        ),
      ),
    );
  }

  /// Название игры, откуда взялся снимок и строка показаний под ними.
  Widget _summary(BuildContext context) {
    final colors = context.colors;
    final snapshot = widget.snapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                widget.game.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyStrong,
              ),
            ),
            const SizedBox(width: 8),
            SaveTag(
              text: snapshotOriginLabel(L.of(context), snapshot.origin),
              color: snapshot.origin == SnapshotOrigin.imported
                  ? colors.primary
                  : colors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${formatDateTime(snapshot.createdAt)} · '
          '${snapshot.deviceName} · '
          '${formatBytes(snapshot.sizeBytes)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // Моноширинный с табличными цифрами: иначе строка дёргалась бы
          // на каждом обновлении списка.
          style: context.text.pathSmall.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Future<void> _export() async {
    final saves = context.read<SavesBloc>();
    final suggested =
        safeFileName(widget.snapshot.gameTitle) + SaveSnapshot.fileExtension;
    final location = await getSaveLocation(suggestedName: suggested);
    if (location == null) return;
    saves.add(
      SnapshotExportRequested(
        snapshot: widget.snapshot,
        destination: location.path,
      ),
    );
  }

  /// Удаление необратимо, поэтому спрашиваем — и называем в вопросе саму
  /// игру: в общем списке снимков разных игр одной даты недостаточно.
  Future<void> _delete() async {
    final saves = context.read<SavesBloc>();
    final ok = await confirm(
      context,
      title: L.of(context).deleteSnapshotQuestion,
      message:
          '${widget.game.title}\n'
          '${L.of(context).deleteSnapshotNote(formatDateTime(widget.snapshot.createdAt))}',
      confirmLabel: L.of(context).delete,
      destructive: true,
    );
    if (!ok) return;
    saves.add(SnapshotDeleted(widget.snapshot));
  }
}

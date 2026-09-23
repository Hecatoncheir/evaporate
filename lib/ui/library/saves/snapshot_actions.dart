import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/saves/saves_bloc.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../models/save_snapshot.dart';
import '../../feedback/confirm.dart';
import '../../labels.dart';

/// Выгрузить снимок пакетом: куда — спрашивает система, сборку делает блок.
///
/// Имя предлагается с датой: снимков одной игры обычно несколько, и
/// выгруженные подряд иначе затирали бы друг друга.
Future<void> exportSnapshot(BuildContext context, SaveSnapshot snapshot) async {
  final saves = context.read<SavesBloc>();
  final when = dateTimeLabel(L.of(context), snapshot.createdAt);
  final suggested =
      safeFileName('${snapshot.gameTitle} $when') + SaveSnapshot.fileExtension;
  final location = await getSaveLocation(suggestedName: suggested);
  if (location == null) return;
  saves.add(
    SnapshotExportRequested(snapshot: snapshot, destination: location.path),
  );
}

/// Удаление необратимо, поэтому спрашиваем — и называем в вопросе саму
/// игру: в общем списке снимков разных игр одной даты недостаточно.
Future<void> deleteSnapshot(
  BuildContext context,
  Game game,
  SaveSnapshot snapshot,
) async {
  final saves = context.read<SavesBloc>();
  final l = L.of(context);
  final ok = await confirm(
    context,
    title: l.deleteSnapshotQuestion,
    message:
        '${game.title}\n'
        '${l.deleteSnapshotNote(dateTimeLabel(l, snapshot.createdAt))}',
    confirmLabel: l.delete,
    destructive: true,
  );
  if (!ok) return;
  saves.add(SnapshotDeleted(snapshot));
}

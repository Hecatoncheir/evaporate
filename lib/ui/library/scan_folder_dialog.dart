import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../bloc/library/library_bloc.dart';
import '../../models/game.dart';
import '../../services/launch/library_scanner.dart';
import '../../services/launch/scan_session.dart';
import '../theme.dart';
import '../../l10n/app_localizations.dart';

/// Показывает ход поиска и добавляет отмеченные игры.
///
/// Возвращает число добавленных игр.
///
/// Сессию заводит вызывающая сторона: пока человек выбирает папку в
/// системном окне, поиск уже идёт, и остановить или перенацелить его должен
/// тот, кто это окно открыл.
Future<int?> showScanFolderDialog(BuildContext context, ScanSession session) {
  return showDialog<int>(
    context: context,
    // Закрывать поиск случайным нажатием мимо окна незачем: он идёт долго,
    // и начинать заново обидно.
    barrierDismissible: false,
    builder: (_) => _ScanFolderDialog(session: session),
  );
}

class _ScanFolderDialog extends StatefulWidget {
  const _ScanFolderDialog({required this.session});

  final ScanSession session;

  @override
  State<_ScanFolderDialog> createState() => _ScanFolderDialogState();
}

class _ScanFolderDialogState extends State<_ScanFolderDialog> {
  /// Папки, которые человек снял сам. Отмечено по умолчанию всё, а находки
  /// приходят по ходу поиска — запоминать надо именно снятое, иначе новая
  /// находка воскрешала бы снятые галочки.
  final _unchecked = <String>{};

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  List<ScannedGame> get _games => widget.session.found;

  Set<String> get _selected => {
    for (final game in _games)
      if (!_unchecked.contains(game.installDir)) game.installDir,
  };

  void _add() {
    final library = context.read<LibraryBloc>();
    final games = _games.where((g) => _selected.contains(g.installDir));

    for (final game in games) {
      library.add(
        GameAdded(
          id: const Uuid().v4(),
          title: game.title,
          source: GameSource(
            kind: GameSourceKind.localFolder,
            value: game.installDir,
          ),
          installDir: game.installDir,
          executablePath: game.executablePath,
          status: GameStatus.installed,
          steamAppId: game.steamAppId,
        ),
      );
    }
    Navigator.pop(context, games.length);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final session = widget.session;
    final games = _games;

    return AlertDialog(
      title: Text(l.gamesInFolder),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Progress(session: session),
            if (games.isNotEmpty) ...[
              const SizedBox(height: 12),
              Flexible(child: _list(games)),
            ] else if (!session.isRunning && session.isComplete) ...[
              const SizedBox(height: 12),
              Text(
                l.scanNothingFound,
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (session.isRunning)
          TextButton.icon(
            onPressed: session.stop,
            icon: const Icon(Icons.stop_circle_outlined, size: 16),
            label: Text(l.scanStop),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _selected.isEmpty ? null : _add,
          child: Text(l.addCount(_selected.length)),
        ),
      ],
    );
  }

  Widget _list(List<ScannedGame> games) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          return CheckboxListTile(
            value: _selected.contains(game.installDir),
            onChanged: (checked) => setState(() {
              if (checked ?? false) {
                _unchecked.remove(game.installDir);
              } else {
                _unchecked.add(game.installDir);
              }
            }),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(game.title, style: const TextStyle(fontSize: 13.5)),
            subtitle: Text(
              game.executablePath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontFamily: EvaporateTheme.monoFontFamily,
                color: context.colors.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Что происходит прямо сейчас.
///
/// Обход дисков идёт секундами: окно с одной вертушкой ничем не отличается
/// от зависшего, а название осматриваемой папки показывает, что работа идёт
/// и сколько её осталось на глаз.
class _Progress extends StatelessWidget {
  const _Progress({required this.session});

  final ScanSession session;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final directory = session.directory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (session.isRunning) ...[
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                // Сколько всего папок, заранее неизвестно: считать их —
                // тот же обход, только дважды.
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  directory == null
                      ? l.scanFoundCount(session.found.length)
                      : l.scanLooking(p.basename(directory)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ] else if (!session.isComplete && session.found.isNotEmpty)
          Text(
            l.scanStopped,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: context.colors.textSecondary,
            ),
          )
        else
          Text(
            l.scanFoundCount(session.found.length),
            style: TextStyle(
              fontSize: 12.5,
              color: context.colors.textSecondary,
            ),
          ),
      ],
    );
  }
}

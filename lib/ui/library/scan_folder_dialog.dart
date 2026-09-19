import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../bloc/library/library_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../services/launch/library_scanner.dart';
import '../../services/launch/scan_session.dart';
import '../theme.dart';
import 'scan/scan_drop_area.dart';
import 'scan/scan_progress.dart';
import 'scan/scanned_games_list.dart';

/// Показывает ход поиска и добавляет отмеченные игры.
///
/// Возвращает число добавленных игр.
///
/// Поиск начинается сразу, ещё до того, как человек что-то выберет: пока он
/// смотрит на найденное, известные места уже осматриваются. Сузить поиск до
/// одной папки можно здесь же — бросив её в окно или выбрав в системном
/// окне, которое откроется по нажатию.
Future<int?> showScanFolderDialog(BuildContext context, ScanSession session) {
  return showDialog<int>(
    context: context,
    // Закрывать поиск случайным нажатием мимо окна незачем: он идёт долго,
    // и начинать заново обидно.
    barrierDismissible: false,
    builder: (_) => ScanFolderDialog(session: session),
  );
}

/// Окно поиска установленных игр: ход обхода и список найденного.
class ScanFolderDialog extends StatefulWidget {
  const ScanFolderDialog({super.key, required this.session});

  final ScanSession session;

  @override
  State<ScanFolderDialog> createState() => _ScanFolderDialogState();
}

class _ScanFolderDialogState extends State<ScanFolderDialog> {
  /// Папку держат над окном — показываем, что бросить её можно сюда.
  bool _dragging = false;

  /// Бросили не папку. Молчаливый отказ хуже всего: человек не поймёт,
  /// случилось что-нибудь или нет.
  bool _wrongDrop = false;

  /// Папки, которые человек снял сам. Отмечено по умолчанию всё, а находки
  /// приходят по ходу поиска — запоминать надо именно снятое, иначе новая
  /// находка воскрешала бы снятые галочки.
  final _unchecked = <String>{};

  /// Отмеченное вручную среди неуверенного. Реестр Windows знает всё
  /// установленное, и заранее отмечать оттуда нельзя: браузер добавился бы
  /// в библиотеку игрой, стоило нажать «Добавить».
  final _checked = <String>{};

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
      if (game.confident && !_unchecked.contains(game.installDir))
        game.installDir,
    for (final game in _games)
      if (!game.confident && _checked.contains(game.installDir))
        game.installDir,
  };

  /// Сужает поиск до одной папки, отменяя начатое.
  void _narrowTo(String directory) {
    setState(() => _wrongDrop = false);
    unawaited(widget.session.scanOnly(directory));
  }

  Future<void> _pickFolder() async {
    final directory = await getDirectoryPath(
      confirmButtonText: L.of(context).scan,
    );
    if (directory != null && mounted) _narrowTo(directory);
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    setState(() => _dragging = false);
    for (final file in details.files) {
      if (await Directory(file.path).exists()) {
        if (mounted) _narrowTo(file.path);
        return;
      }
    }
    if (mounted) setState(() => _wrongDrop = true);
  }

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

  /// Уверенно найденные игры отмечены сразу, поэтому у списка две
  /// половины: снятые с уверенных и поставленные на сомнительных.
  void _toggle(ScannedGame game, {required bool selected}) {
    setState(() {
      if (game.confident) {
        selected
            ? _unchecked.remove(game.installDir)
            : _unchecked.add(game.installDir);
      } else {
        selected
            ? _checked.add(game.installDir)
            : _checked.remove(game.installDir);
      }
    });
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
            ScanProgress(session: session),
            const SizedBox(height: 12),
            ScanDropArea(
              dragging: _dragging,
              wrongDrop: _wrongDrop,
              onTap: _pickFolder,
              onEntered: () => setState(() => _dragging = true),
              onExited: () => setState(() => _dragging = false),
              onDrop: _onDrop,
            ),
            if (games.isNotEmpty) ...[
              const SizedBox(height: 12),
              Flexible(
                child: ScannedGamesList(
                  games: games,
                  isSelected: (game) => _selected.contains(game.installDir),
                  onToggle: _toggle,
                ),
              ),
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
}

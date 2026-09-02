import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../bloc/library/library_bloc.dart';
import '../../models/game.dart';
import '../../services/launch/library_scanner.dart';
import '../theme.dart';

/// Показывает найденные в папке игры и добавляет отмеченные.
///
/// Возвращает число добавленных игр.
Future<int?> showScanFolderDialog(BuildContext context, String rootDir) {
  return showDialog<int>(
    context: context,
    builder: (_) => _ScanFolderDialog(rootDir: rootDir),
  );
}

class _ScanFolderDialog extends StatefulWidget {
  const _ScanFolderDialog({required this.rootDir});

  final String rootDir;

  @override
  State<_ScanFolderDialog> createState() => _ScanFolderDialogState();
}

class _ScanFolderDialogState extends State<_ScanFolderDialog> {
  List<ScannedGame>? _found;
  final _chosen = <String>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final library = context.read<LibraryBloc>();
    try {
      final found = await LibraryScanner.scan(
        widget.rootDir,
        existingDirs: LibraryScanner.installedDirs(library.state.games),
      );
      if (!mounted) return;
      setState(() {
        _found = found;
        // Отмечаем всё: пришли добавлять, а не отсеивать.
        _chosen
          ..clear()
          ..addAll(found.map((game) => game.installDir));
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _add() {
    final library = context.read<LibraryBloc>();
    final games = _found!.where((g) => _chosen.contains(g.installDir));

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
        ),
      );
    }
    Navigator.pop(context, games.length);
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;

    return AlertDialog(
      title: const Text('Игры в папке'),
      content: SizedBox(
        width: 520,
        child: switch ((found, _error)) {
          (_, final String error) => Text(
            error,
            style: TextStyle(color: context.colors.danger),
          ),
          (null, _) => const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator()),
          ),
          (final List<ScannedGame> games, _) when games.isEmpty => Text(
            'Ничего не нашлось. Игрой считается подпапка, в которой есть '
            'исполняемый файл; уже добавленные пропускаются.',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          (final List<ScannedGame> games, _) => _list(games),
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: (found == null || _chosen.isEmpty) ? null : _add,
          child: Text('Добавить: ${_chosen.length}'),
        ),
      ],
    );
  }

  Widget _list(List<ScannedGame> games) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          return CheckboxListTile(
            value: _chosen.contains(game.installDir),
            onChanged: (checked) => setState(() {
              if (checked ?? false) {
                _chosen.add(game.installDir);
              } else {
                _chosen.remove(game.installDir);
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

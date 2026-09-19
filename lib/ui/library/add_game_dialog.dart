import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../services/launch/executable_finder.dart';
import '../widgets/busy_spinner.dart';
import 'add/add_game_form.dart';

/// Возвращает идентификатор добавленной игры: событие ничего не возвращает,
/// а вызывающему нужно выделить новую игру в списке.
Future<String?> showAddGameDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _AddGameDialog(),
  );
}

class _AddGameDialog extends StatefulWidget {
  const _AddGameDialog();

  @override
  State<_AddGameDialog> createState() => _AddGameDialogState();
}

class _AddGameDialogState extends State<_AddGameDialog> {
  GameSourceKind _kind = GameSourceKind.magnet;
  final _titleController = TextEditingController();
  final _magnetController = TextEditingController();
  String? _filePath;
  String? _folderPath;
  bool _startImmediately = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _magnetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<DownloadsBloc>().state.engine;
    final l = L.of(context);

    return AlertDialog(
      title: Text(l.addGame),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: AddGameForm(
            kind: _kind,
            onKind: (value) => setState(() => _kind = value),
            magnetController: _magnetController,
            titleController: _titleController,
            filePath: _filePath,
            folderPath: _folderPath,
            onMagnetChanged: _onMagnetChanged,
            onPickTorrent: _pickTorrent,
            onPickFolder: _pickFolder,
            startImmediately: _startImmediately,
            onStartImmediately: (value) =>
                setState(() => _startImmediately = value),
            engine: engine,
            error: _error,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const BusySpinner(size: 16) : Text(l.add),
        ),
      ],
    );
  }

  /// В magnet-ссылке имя лежит в параметре `dn` — подставляем его в название.
  void _onMagnetChanged(String value) {
    if (_titleController.text.isNotEmpty) return;
    final name = _displayNameFromMagnet(value);
    if (name != null) _titleController.text = name;
  }

  static String? _displayNameFromMagnet(String magnet) {
    final match = RegExp(r'[?&]dn=([^&]+)').firstMatch(magnet);
    if (match == null) return null;
    try {
      return Uri.decodeComponent(match.group(1)!.replaceAll('+', ' '));
    } on FormatException {
      return null;
    }
  }

  Future<void> _pickTorrent() async {
    const group = XTypeGroup(label: 'Torrent', extensions: ['torrent']);
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return;
    setState(() {
      _filePath = file.path;
      if (_titleController.text.isEmpty) {
        _titleController.text = p.basenameWithoutExtension(file.path);
      }
    });
  }

  Future<void> _pickFolder() async {
    final dir = await getDirectoryPath();
    if (dir == null) return;
    setState(() {
      _folderPath = dir;
      if (_titleController.text.isEmpty) {
        _titleController.text = p.basename(dir);
      }
    });
  }

  /// Событие добавления обрабатывается асинхронно, поэтому перед запуском
  /// загрузки дожидаемся, пока игра действительно появится в состоянии.
  Future<void> _startIfRequested(
    LibraryBloc library,
    DownloadsBloc downloads,
    String id,
    GameSource source,
  ) async {
    if (!_startImmediately || !downloads.state.engine.isReady) return;
    var game = library.state.gameById(id);
    game ??= (await library.stream.firstWhere(
      (state) => state.gameById(id) != null,
    )).gameById(id);
    if (game == null) return;
    downloads.add(DownloadRequested(game: game, source: source));
  }

  Future<void> _submit() async {
    // До первого await: после него трогать context нельзя — виджет мог
    // исчезнуть, пока шла работа.
    final l = L.of(context);
    final library = context.read<LibraryBloc>();
    final downloads = context.read<DownloadsBloc>();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // id генерируем здесь: событие ничего не возвращает, а запустить
      // загрузку надо будет именно этой игре.
      final id = const Uuid().v4();
      final request = await _buildRequest(l, id);
      library.add(request.event);
      if (request.download != null) {
        await _startIfRequested(library, downloads, id, request.download!);
      }
      if (mounted) Navigator.pop(context, id);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _busy = false;
        });
      }
    }
  }

  /// Собирает то, что предстоит завести в библиотеке. Негодный ввод
  /// отвергает [_Rejected] с готовым для человека текстом.
  ///
  /// Проверки и название у каждого источника свои, а всё, что дальше, —
  /// одно на всех, поэтому развилка кончается здесь.
  Future<_AddRequest> _buildRequest(L l, String id) async {
    final title = _titleController.text.trim();

    switch (_kind) {
      case GameSourceKind.magnet:
        final magnet = _magnetController.text.trim();
        if (!magnet.startsWith('magnet:')) throw _Rejected(l.badMagnet);
        final source = GameSource(kind: GameSourceKind.magnet, value: magnet);
        return _AddRequest(
          event: GameAdded(
            id: id,
            title: title.isEmpty
                ? (_displayNameFromMagnet(magnet) ?? l.newGame)
                : title,
            source: source,
          ),
          download: source,
        );

      case GameSourceKind.torrentFile:
        final path = _filePath;
        if (path == null) throw _Rejected(l.pickTorrent);
        final source = GameSource(
          kind: GameSourceKind.torrentFile,
          value: path,
        );
        return _AddRequest(
          event: GameAdded(
            id: id,
            title: title.isEmpty ? p.basenameWithoutExtension(path) : title,
            source: source,
          ),
          download: source,
        );

      case GameSourceKind.localFolder:
        final dir = _folderPath;
        if (dir == null) throw _Rejected(l.pickFolder);
        if (!await Directory(dir).exists()) throw _Rejected(l.folderMissing);

        final candidates = await ExecutableFinder.scan(dir);
        return _AddRequest(
          event: GameAdded(
            id: id,
            title: title.isEmpty ? p.basename(dir) : title,
            source: GameSource(kind: GameSourceKind.localFolder, value: dir),
            installDir: dir,
            executablePath: candidates.isEmpty ? null : candidates.first.path,
            status: GameStatus.installed,
          ),
        );
    }
  }
}

/// Что завести в библиотеке и надо ли сразу ставить это в загрузку.
class _AddRequest {
  const _AddRequest({required this.event, this.download});

  final GameAdded event;

  /// Источник, который можно качать. У папки на диске его нет: она уже
  /// установлена.
  final GameSource? download;
}

/// Ввод, с которым игру не завести; [message] показывается как есть.
class _Rejected implements Exception {
  const _Rejected(this.message);

  final String message;

  @override
  String toString() => message;
}

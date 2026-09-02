import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/game.dart';
import '../../services/launch/executable_finder.dart';
import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../labels.dart';
import '../theme.dart';
import '../../l10n/app_localizations.dart';

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
    final downloads = context.watch<DownloadsBloc>().state;
    final engineReady = downloads.engine.isReady;

    return AlertDialog(
      title: Text(L.of(context).addGame),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<GameSourceKind>(
                segments: [
                  ButtonSegment(
                    value: GameSourceKind.magnet,
                    icon: Icon(Icons.link, size: 16),
                    label: Text('Magnet'),
                  ),
                  ButtonSegment(
                    value: GameSourceKind.torrentFile,
                    icon: Icon(Icons.description_outlined, size: 16),
                    label: Text('.torrent'),
                  ),
                  ButtonSegment(
                    value: GameSourceKind.localFolder,
                    icon: Icon(Icons.folder_outlined, size: 16),
                    label: Text(L.of(context).sourceFolder),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (value) =>
                    setState(() => _kind = value.first),
              ),
              const SizedBox(height: 20),
              ..._buildSourceFields(),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: L.of(context).title,
                  hintText: L.of(context).titleHint,
                ),
              ),
              if (_kind != GameSourceKind.localFolder) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _startImmediately && engineReady,
                  onChanged: engineReady
                      ? (value) =>
                            setState(() => _startImmediately = value ?? false)
                      : null,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: Text(L.of(context).startDownloadNow),
                  subtitle: engineReady
                      ? null
                      : Text(
                          L
                              .of(context)
                              .engineUnavailable(
                                engineStateLabel(
                                  L.of(context),
                                  downloads.engine.state,
                                ),
                              ),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.warning,
                          ),
                        ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: context.colors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(L.of(context).cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(L.of(context).add),
        ),
      ],
    );
  }

  List<Widget> _buildSourceFields() {
    switch (_kind) {
      case GameSourceKind.magnet:
        return [
          TextField(
            controller: _magnetController,
            maxLines: 3,
            minLines: 2,
            onChanged: _onMagnetChanged,
            decoration: InputDecoration(
              labelText: L.of(context).sourceMagnet,
              hintText: 'magnet:?xt=urn:btih:...',
            ),
          ),
        ];
      case GameSourceKind.torrentFile:
        return [
          _PathPicker(
            label: L.of(context).sourceTorrent,
            value: _filePath,
            icon: Icons.description_outlined,
            onPick: _pickTorrent,
          ),
        ];
      case GameSourceKind.localFolder:
        return [
          _PathPicker(
            label: L.of(context).gameFolder,
            value: _folderPath,
            icon: Icons.folder_outlined,
            onPick: _pickFolder,
          ),
          const SizedBox(height: 8),
          Text(
            L.of(context).localFolderNote,
            style: TextStyle(
              fontSize: 12,
              color: context.colors.textSecondary,
              height: 1.4,
            ),
          ),
        ];
    }
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
      final title = _titleController.text.trim();
      final id = const Uuid().v4();

      switch (_kind) {
        case GameSourceKind.magnet:
          final magnet = _magnetController.text.trim();
          if (!magnet.startsWith('magnet:')) {
            throw l.badMagnet;
          }
          final source = GameSource(kind: GameSourceKind.magnet, value: magnet);
          library.add(
            GameAdded(
              id: id,
              title: title.isEmpty
                  ? (_displayNameFromMagnet(magnet) ?? l.newGame)
                  : title,
              source: source,
            ),
          );
          await _startIfRequested(library, downloads, id, source);
          if (mounted) Navigator.pop(context, id);

        case GameSourceKind.torrentFile:
          final path = _filePath;
          if (path == null) throw l.pickTorrent;
          final source = GameSource(
            kind: GameSourceKind.torrentFile,
            value: path,
          );
          library.add(
            GameAdded(
              id: id,
              title: title.isEmpty ? p.basenameWithoutExtension(path) : title,
              source: source,
            ),
          );
          await _startIfRequested(library, downloads, id, source);
          if (mounted) Navigator.pop(context, id);

        case GameSourceKind.localFolder:
          final dir = _folderPath;
          if (dir == null) throw l.pickFolder;
          if (!await Directory(dir).exists()) throw l.folderMissing;

          final candidates = await ExecutableFinder.scan(dir);
          library.add(
            GameAdded(
              id: id,
              title: title.isEmpty ? p.basename(dir) : title,
              source: GameSource(kind: GameSourceKind.localFolder, value: dir),
              installDir: dir,
              executablePath: candidates.isEmpty ? null : candidates.first.path,
              status: GameStatus.installed,
            ),
          );
          if (mounted) Navigator.pop(context, id);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _busy = false;
        });
      }
    }
  }
}

class _PathPicker extends StatelessWidget {
  const _PathPicker({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPick,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.colors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ?? L.of(context).tapToChoose,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: value == null
                          ? context.colors.textSecondary
                          : context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_horiz, size: 18),
          ],
        ),
      ),
    );
  }
}

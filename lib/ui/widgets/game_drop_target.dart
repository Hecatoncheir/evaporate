import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../bloc/navigation/navigation_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../services/launch/drop_import.dart';
import '../library/drop_overlay.dart';

/// Приёмник сброшенных в окно файлов.
///
/// Чем оказалось сброшенное, решает [DropImport]: папка — установленная
/// игра, `.torrent` — игра в очереди загрузки, остальное помечается
/// неподходящим и не проглатывается молча.
///
/// Один виджет на оба экрана, где это уместно. Библиотека и загрузки
/// принимают одно и то же, и расходиться им незачем: человек бросает файл
/// туда, где сейчас смотрит, а не туда, где по нашему замыслу полагается.
///
/// Magnet-ссылку сюда не притащить, и это не недоделка: `desktop_drop`
/// читает на macOS только file-URL, на Windows — только `CF_HDROP`, а
/// ссылка из браузера приходит как `public.url` и до приложения не
/// доезжает. Её вставляют в «Добавить игру».
class GameDropTarget extends StatefulWidget {
  const GameDropTarget({
    super.key,
    required this.child,
    this.enabled = true,
    this.selectAfterDrop = true,
  });

  final Widget child;

  /// Пока открыто системное окно выбора папки, брошенное принадлежит ему.
  final bool enabled;

  /// Подсветить добавленную игру в сетке библиотеки.
  ///
  /// Страницу это не открывает — за неё отвечает `GameOpened`, — но
  /// витрина следует за выбором, и в библиотеке так и нужно: иначе
  /// брошенная игра затеряется среди прочих. С экрана загрузок выбор в
  /// соседнем разделе не трогаем: человек его там оставил, а увиденное им
  /// сейчас — очередь, и она пополнится сама.
  final bool selectAfterDrop;

  @override
  State<GameDropTarget> createState() => _GameDropTargetState();
}

class _GameDropTargetState extends State<GameDropTarget> {
  bool _dragging = false;
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    // Разделы живут в `IndexedStack` все разом — невидимый не выброшен, а
    // только не нарисован, — и приёмник на каждом из них ловил бы один и
    // тот же сброс. Один файл добавлялся бы дважды.
    //
    // Отличаем видимый по `TickerMode`: `FadeIndexedStack` включает его
    // ровно текущему разделу. Тот же признак слушают украшения, чтобы не
    // жечь батарею за спиной, — заводить второй незачем.
    final visible = TickerMode.valuesOf(context).enabled && widget.enabled;

    return DropTarget(
      onDragEntered: (_) {
        if (visible) setState(() => _dragging = true);
      },
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        if (!visible) return;
        _handleDrop(context, [for (final f in details.files) f.path]);
      },
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (_dragging) const Positioned.fill(child: DropOverlay()),
        ],
      ),
    );
  }

  Future<void> _handleDrop(BuildContext context, List<String> paths) async {
    if (_importing || paths.isEmpty) return;
    setState(() => _importing = true);

    // До первого await: после него context трогать нельзя.
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final library = context.read<LibraryBloc>();
    final downloads = context.read<DownloadsBloc>();
    final nav = context.read<NavigationBloc>();

    try {
      final candidates = await DropImport.inspect(paths);
      var added = 0;
      var queued = 0;
      String? lastId;

      for (final candidate in candidates) {
        if (candidate.kind == DropKind.unsupported) continue;

        final id = _addGame(library, candidate);
        added++;
        lastId = id;

        if (candidate.kind == DropKind.torrent &&
            await _startDownload(library, downloads, id, candidate.source)) {
          queued++;
        }
      }

      if (added == 0) {
        messenger.showSnackBar(SnackBar(content: Text(l.dropNothing)));
        return;
      }
      if (widget.selectAfterDrop && lastId != null) {
        nav.add(GameSelected(lastId));
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(_dropMessage(l, added: added, queued: queued)),
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// Заводит игру из брошенного в окно файла и возвращает её id.
  ///
  /// Папка — уже установленная игра, `.torrent` — ещё не скачанная.
  String _addGame(LibraryBloc library, DropCandidate candidate) {
    final id = const Uuid().v4();
    final installed = candidate.kind == DropKind.folder;
    library.add(
      GameAdded(
        id: id,
        title: candidate.title,
        source: candidate.source,
        installDir: installed ? candidate.path : null,
        executablePath: candidate.executablePath,
        status: installed ? GameStatus.installed : GameStatus.notInstalled,
      ),
    );
    return id;
  }

  /// Одной строкой: сколько игр завели и сколько из них поставили качаться.
  String _dropMessage(L l, {required int added, required int queued}) =>
      queued == 0
      ? l.dropAdded(added)
      : '${l.dropAdded(added)}, ${l.dropQueued(queued)}';

  /// Событие добавления обрабатывается асинхронно, поэтому перед запуском
  /// загрузки дожидаемся, пока игра действительно появится в состоянии.
  ///
  /// Возвращает `false`, когда движок не готов: игра всё равно добавлена,
  /// и загрузку можно запустить руками позже.
  Future<bool> _startDownload(
    LibraryBloc library,
    DownloadsBloc downloads,
    String id,
    GameSource? source,
  ) async {
    if (source == null) return false;
    if (!downloads.state.engine.isReady) return false;
    var game = library.state.gameById(id);
    game ??= (await library.stream.firstWhere(
      (state) => state.gameById(id) != null,
    )).gameById(id);
    if (game == null) return false;
    downloads.add(DownloadRequested(game: game, source: source));
    return true;
  }
}

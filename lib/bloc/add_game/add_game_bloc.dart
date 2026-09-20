import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/game.dart';
import '../../services/launch/executable_finder.dart';
import '../downloads/downloads_bloc.dart';
import '../library/library_bloc.dart';

part 'add_game_event.dart';
part 'add_game_state.dart';

/// Окно «Добавить игру», пока его заполняют.
///
/// Блок, а не состояние окна: проверки ввода решают, заведётся игра или
/// нет, обход папки в поисках исполняемого файла асинхронен, а ждать
/// появления игры в чужом состоянии виджету и вовсе не положено.
class AddGameBloc extends Bloc<AddGameEvent, AddGameForm> {
  AddGameBloc({
    required this.library,
    required this.downloads,
    L Function()? localizations,
  }) : _localizations = localizations ?? _defaultLocalizations,
       super(const AddGameForm()) {
    on<AddGameKindChanged>(
      (event, emit) => emit(state.copyWith(kind: event.kind)),
    );
    on<AddGameMagnetChanged>(
      (event, emit) => emit(state.copyWith(magnet: event.magnet)),
    );
    on<AddGameTitleChanged>(
      (event, emit) => emit(state.copyWith(title: event.title)),
    );
    on<AddGameTorrentPicked>(
      (event, emit) => emit(state.copyWith(filePath: event.path)),
    );
    on<AddGameFolderPicked>(
      (event, emit) => emit(state.copyWith(folderPath: event.path)),
    );
    on<AddGameStartImmediatelyChanged>(
      (event, emit) => emit(state.copyWith(startImmediately: event.start)),
    );
    on<AddGameSubmitted>(_onSubmitted);
  }

  final LibraryBloc library;
  final DownloadsBloc downloads;
  final L Function() _localizations;

  static L _defaultLocalizations() => LRu();

  L get _l => _localizations();

  Future<void> _onSubmitted(
    AddGameSubmitted event,
    Emitter<AddGameForm> emit,
  ) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, error: null));

    // id заводим здесь: событие ничего не возвращает, а запустить загрузку
    // надо будет именно этой игре — и назвать её вызывающему тоже.
    final id = const Uuid().v4();
    final AddRequest request;
    try {
      request = await _buildRequest(id);
    } on AddGameRejected catch (rejected) {
      emit(state.copyWith(busy: false, error: rejected.message));
      return;
    }

    library.add(request.event);
    await _startIfRequested(id, request.download);
    emit(state.copyWith(busy: false, addedId: id));
  }

  /// Ставит загрузку, если её просили и движку есть чем её взять.
  ///
  /// Событие добавления обрабатывается асинхронно, поэтому перед запуском
  /// дожидаемся, пока игра действительно появится в состоянии библиотеки:
  /// двум блокам порядок обработки никто не обещал.
  Future<void> _startIfRequested(String id, GameSource? source) async {
    if (source == null || !state.startImmediately) return;
    if (!downloads.state.engine.isReady) return;
    final game =
        library.state.gameById(id) ??
        (await library.stream.firstWhere((state) => state.gameById(id) != null))
            .gameById(id);
    if (game == null) return;
    downloads.add(DownloadRequested(game: game, source: source));
  }

  /// Собирает то, что предстоит завести в библиотеке. Негодный ввод
  /// отвергает [AddGameRejected] с готовым для человека текстом.
  ///
  /// Проверки и название у каждого источника свои, а всё, что дальше, —
  /// одно на всех, поэтому развилка кончается здесь.
  Future<AddRequest> _buildRequest(String id) async => switch (state.kind) {
    GameSourceKind.magnet => _fromMagnet(id),
    GameSourceKind.torrentFile => _fromTorrent(id),
    GameSourceKind.localFolder => await _fromFolder(id),
  };

  AddRequest _fromMagnet(String id) {
    final magnet = state.magnet.trim();
    if (!magnet.startsWith('magnet:')) throw AddGameRejected(_l.badMagnet);
    final source = GameSource(kind: GameSourceKind.magnet, value: magnet);
    return AddRequest(
      event: GameAdded(
        id: id,
        title: _title(magnetDisplayName(magnet) ?? _l.newGame),
        source: source,
      ),
      download: source,
    );
  }

  AddRequest _fromTorrent(String id) {
    final path = state.filePath;
    if (path == null) throw AddGameRejected(_l.pickTorrent);
    final source = GameSource(kind: GameSourceKind.torrentFile, value: path);
    return AddRequest(
      event: GameAdded(
        id: id,
        title: _title(p.basenameWithoutExtension(path)),
        source: source,
      ),
      download: source,
    );
  }

  /// У папки на диске источника для загрузки нет: она уже установлена, и
  /// запускать в ней остаётся только то, что найдётся внутри.
  Future<AddRequest> _fromFolder(String id) async {
    final dir = state.folderPath;
    if (dir == null) throw AddGameRejected(_l.pickFolder);
    if (!await Directory(dir).exists()) {
      throw AddGameRejected(_l.folderMissing);
    }

    final candidates = await ExecutableFinder.scan(dir);
    return AddRequest(
      event: GameAdded(
        id: id,
        title: _title(p.basename(dir)),
        source: GameSource(kind: GameSourceKind.localFolder, value: dir),
        installDir: dir,
        executablePath: candidates.isEmpty ? null : candidates.first.path,
        status: GameStatus.installed,
      ),
    );
  }

  /// Название: своё, а если его не написали — предложенное источником.
  String _title(String fallback) {
    final title = state.title.trim();
    return title.isEmpty ? fallback : title;
  }
}

/// Имя из magnet-ссылки: оно лежит в параметре `dn`.
///
/// Отдельной функцией, потому что нужно дважды — подставить в поле, пока
/// человек вставляет ссылку, и взять названием, если поле так и осталось
/// пустым.
String? magnetDisplayName(String magnet) {
  final match = RegExp(r'[?&]dn=([^&]+)').firstMatch(magnet);
  if (match == null) return null;
  try {
    return Uri.decodeComponent(match.group(1)!.replaceAll('+', ' '));
  } on ArgumentError {
    // Ссылку человек вставляет откуда угодно, и битая доля процентов в
    // имени — не повод уронить набор: `decodeComponent` на «%%%» бросает
    // `ArgumentError`, а не `FormatException`, как можно подумать.
    return null;
  } on FormatException {
    return null;
  }
}

/// Что завести в библиотеке и надо ли сразу ставить это в загрузку.
class AddRequest {
  const AddRequest({required this.event, this.download});

  final GameAdded event;

  /// Источник, который можно качать. У папки на диске его нет: она уже
  /// установлена.
  final GameSource? download;
}

/// Ввод, с которым игру не завести; [message] показывается как есть.
class AddGameRejected implements Exception {
  const AddGameRejected(this.message);

  final String message;

  @override
  String toString() => message;
}

import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/json_store.dart';
import '../../models/game.dart';
import '../../models/save_profile.dart';
import '../../models/save_snapshot.dart';
import '../../services/launch/game_launcher.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/saves/save_manager.dart';
import '../notice.dart';
import '../settings/settings_bloc.dart';

part 'library_event.dart';
part 'library_state.dart';

/// Библиотека игр и их сохранений — единственный источник правды для UI.
///
/// Ошибки наружу не выбрасываются: обработчики кладут результат в [Notice],
/// а экраны показывают его через `BlocListener`.
class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  LibraryBloc({
    required AppPaths paths,
    required this.settings,
    SaveManager? saveManager,
    GameLauncher? launcher,
    NotificationService? notifications,
  }) : notifications = notifications ?? const NoopNotificationService(),
       _store = JsonStore(paths.libraryFile),
       _saves = saveManager ?? SaveManager(paths: paths),
       _launcher = launcher ?? GameLauncher(),
       super(const LibraryState()) {
    on<LibraryLoadRequested>(_onLoadRequested);
    on<GameAdded>(_onGameAdded);
    on<GameUpdated>(_onGameUpdated);
    on<GameRemoved>(_onGameRemoved);
    on<GameLaunchRequested>(_onLaunchRequested);
    on<GameStopRequested>(_onStopRequested);
    on<GameExited>(_onGameExited);
    on<RunningGamesChanged>(_onRunningGamesChanged);
    on<SnapshotRequested>(_onSnapshotRequested);
    on<SnapshotRestoreRequested>(_onRestoreRequested);
    on<SnapshotImportRequested>(_onImportRequested);
    on<SnapshotExportRequested>(_onExportRequested);
    on<SnapshotDeleted>(_onSnapshotDeleted);
    on<SyncFolderScanRequested>(_onSyncScanRequested);
    on<SyncPackageApplied>(_onSyncPackageApplied);

    _launcher.runningIds.addListener(_pushRunningGames);
  }

  final SettingsBloc settings;

  /// Автоснимок после выхода из игры молчалив по замыслу, но его провал
  /// пользователь обязан заметить — иначе узнает, только потеряв прогресс.
  final NotificationService notifications;
  final JsonStore _store;
  final SaveManager _saves;
  final GameLauncher _launcher;

  Timer? _persistTimer;
  int _noticeSeq = 0;

  /// Чтение манифеста чужого `.evsave` состояния не меняет, поэтому диалог
  /// подтверждения обращается к менеджеру напрямую.
  SaveManager get saveManager => _saves;

  GameLauncher get launcher => _launcher;

  static String snapshotKey(String gameId) => 'snapshot:$gameId';

  static String launchKey(String gameId) => 'launch:$gameId';

  void _pushRunningGames() =>
      add(RunningGamesChanged(_launcher.runningIds.value));

  Notice _notice(String message, {bool isError = false}) =>
      Notice(message: message, seq: ++_noticeSeq, isError: isError);

  void _notifySystem(AppNotification notification) {
    if (!settings.state.systemNotifications) return;
    unawaited(notifications.show(notification));
  }

  Set<String> _withBusy(String key, bool value) {
    final next = Set<String>.from(state.busy);
    if (value) {
      next.add(key);
    } else {
      next.remove(key);
    }
    return next;
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), persist);
  }

  Future<void> persist() async {
    _persistTimer?.cancel();
    await _store.write({
      'version': 1,
      'games': state.games.map((g) => g.toJson()).toList(),
      'snapshots': state.snapshots.map(
        (key, value) => MapEntry(key, value.map((s) => s.toJson()).toList()),
      ),
    });
  }

  // ---------------------------------------------------------------- игры

  Future<void> _onLoadRequested(
    LibraryLoadRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final json = await _store.read();
    if (json == null) {
      emit(state.copyWith(loaded: true));
      return;
    }
    final games = (json['games'] as List<dynamic>? ?? [])
        .map((e) => Game.fromJson(e as Map<String, dynamic>))
        .toList();
    final snapshots = <String, List<SaveSnapshot>>{};
    (json['snapshots'] as Map<String, dynamic>? ?? {}).forEach((gameId, value) {
      snapshots[gameId] = (value as List<dynamic>)
          .map((e) => SaveSnapshot.fromJson(e as Map<String, dynamic>))
          .toList();
    });
    emit(state.copyWith(games: games, snapshots: snapshots, loaded: true));
  }

  void _onGameAdded(GameAdded event, Emitter<LibraryState> emit) {
    final title = event.title.trim();
    final game = Game(
      id: event.id,
      title: title.isEmpty ? 'Без названия' : title,
      addedAt: DateTime.now(),
      source: event.source,
      installDir: event.installDir,
      executablePath: event.executablePath,
      status: event.status,
      saveProfile: SaveProfile(
        autoSnapshotOnExit: settings.state.autoSnapshotOnExit,
      ),
    );
    emit(state.copyWith(games: [...state.games, game]));
    _schedulePersist();
  }

  void _onGameUpdated(GameUpdated event, Emitter<LibraryState> emit) {
    final index = state.games.indexWhere((g) => g.id == event.game.id);
    if (index == -1) return;
    final games = [...state.games];
    games[index] = event.game;
    emit(state.copyWith(games: games));
    _schedulePersist();
  }

  Future<void> _onGameRemoved(
    GameRemoved event,
    Emitter<LibraryState> emit,
  ) async {
    final game = event.game;
    final snapshots = Map<String, List<SaveSnapshot>>.from(state.snapshots);
    final removed = snapshots.remove(game.id) ?? const <SaveSnapshot>[];
    emit(
      state.copyWith(
        games: state.games.where((g) => g.id != game.id).toList(),
        snapshots: snapshots,
      ),
    );
    await persist();

    for (final snapshot in removed) {
      try {
        await _saves.deleteSnapshot(snapshot);
      } on Object {
        // Файл мог быть уже удалён вручную.
      }
    }
    if (event.deleteFiles && game.installDir != null) {
      final dir = Directory(game.installDir!);
      // Не удаляем что-то за пределами папки установки — страховка от опечаток.
      if (await dir.exists() &&
          p.isWithin(settings.state.installDir, dir.path)) {
        await dir.delete(recursive: true);
      }
    }
  }

  // ------------------------------------------------------------- запуск

  Future<void> _onLaunchRequested(
    GameLaunchRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final game = event.game;
    final key = launchKey(game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      await _launcher.launch(
        game,
        onExit: (exited, played, exitCode) => add(
          GameExited(gameId: exited.id, played: played, exitCode: exitCode),
        ),
      );
      final index = state.games.indexWhere((g) => g.id == game.id);
      if (index != -1) {
        final games = [...state.games];
        games[index] = game.copyWith(
          status: GameStatus.running,
          lastError: null,
        );
        emit(state.copyWith(games: games, busy: _withBusy(key, false)));
        _schedulePersist();
        return;
      }
      emit(state.copyWith(busy: _withBusy(key, false)));
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  Future<void> _onStopRequested(
    GameStopRequested event,
    Emitter<LibraryState> emit,
  ) async {
    await _launcher.terminate(event.game.id);
  }

  void _onGameExited(GameExited event, Emitter<LibraryState> emit) {
    final current = state.gameById(event.gameId);
    if (current == null) return;

    // Меньше минуты — обычно неудачный запуск, не засоряем статистику.
    final counted = event.played.inSeconds >= 60 ? event.played : Duration.zero;
    final updated = current.copyWith(
      status: GameStatus.installed,
      playtime: current.playtime + counted,
      lastPlayed: DateTime.now(),
    );
    final games = [...state.games];
    games[games.indexWhere((g) => g.id == event.gameId)] = updated;
    emit(state.copyWith(games: games));
    _schedulePersist();

    if (updated.saveProfile.autoSnapshotOnExit &&
        updated.saveProfile.isConfigured) {
      add(SnapshotRequested(updated, origin: SnapshotOrigin.autoOnExit));
    }
  }

  void _onRunningGamesChanged(
    RunningGamesChanged event,
    Emitter<LibraryState> emit,
  ) {
    emit(state.copyWith(runningIds: event.ids));
  }

  // -------------------------------------------------------------- сейвы

  Future<void> _onSnapshotRequested(
    SnapshotRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final game = event.game;
    final silent = event.origin == SnapshotOrigin.autoOnExit;
    final key = snapshotKey(game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));

    try {
      final snapshot = await _saves.createSnapshot(
        game,
        origin: event.origin,
        note: event.note,
      );

      if (settings.state.autoExportToSync &&
          settings.state.syncFolder != null) {
        try {
          await _exportToSyncFolder(snapshot);
        } on Object {
          // Папка синхронизации могла отвалиться — снимок уже сохранён локально.
        }
      }

      emit(
        state.copyWith(
          snapshots: _withSnapshot(snapshot),
          busy: _withBusy(key, false),
          notice: silent
              ? state.notice
              : _notice(
                  'Снимок готов: ${snapshot.fileCount} файлов, '
                  '${_formatSize(snapshot.sizeBytes)}',
                ),
        ),
      );
      await _prune(game, emit);
      await persist();
    } on SaveException catch (error) {
      if (silent) {
        // Молчаливый автоснимок провалился — единственный способ сообщить.
        _notifySystem(
          AppNotification(
            title: 'Сохранения не сняты',
            body: '«${game.title}»: ${error.message}',
            kind: NotificationKind.saveFailed,
          ),
        );
      }
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: silent ? state.notice : _notice(error.message, isError: true),
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  Map<String, List<SaveSnapshot>> _withSnapshot(SaveSnapshot snapshot) {
    final snapshots = Map<String, List<SaveSnapshot>>.from(state.snapshots);
    snapshots[snapshot.gameId] = [snapshot, ...?snapshots[snapshot.gameId]];
    return snapshots;
  }

  Future<void> _prune(Game game, Emitter<LibraryState> emit) async {
    final keep = game.saveProfile.keepSnapshots;
    if (keep <= 0) return;
    final list = state.snapshots[game.id];
    if (list == null || list.length <= keep) return;

    final excess = list.sublist(keep);
    final snapshots = Map<String, List<SaveSnapshot>>.from(state.snapshots);
    snapshots[game.id] = list.sublist(0, keep);
    emit(state.copyWith(snapshots: snapshots));

    for (final snapshot in excess) {
      try {
        await _saves.deleteSnapshot(snapshot);
      } on Object {
        // Пропускаем: ротация не критична.
      }
    }
  }

  Future<void> _onRestoreRequested(
    SnapshotRestoreRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final key = snapshotKey(event.game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      final report = await _saves.restoreSnapshot(
        game: event.game,
        snapshot: event.snapshot,
        backupCurrent: event.backupCurrent,
        wipeTarget: event.wipeTarget,
      );
      emit(
        state.copyWith(
          snapshots: report.backup == null
              ? state.snapshots
              : _withSnapshot(report.backup!),
          busy: _withBusy(key, false),
          notice: report.isComplete
              ? _notice(
                  'Восстановлено ${report.filesWritten} файлов '
                  '(${_formatSize(report.bytesWritten)}).',
                )
              : _notice(
                  'Часть путей не сопоставилась: '
                  '${report.unresolved.join(', ')}. Остальное восстановлено.',
                  isError: true,
                ),
        ),
      );
      await persist();
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  Future<void> _onImportRequested(
    SnapshotImportRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final key = snapshotKey(event.game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      final snapshot = await _saves.importPackage(event.path, game: event.game);
      emit(
        state.copyWith(
          snapshots: _withSnapshot(snapshot),
          busy: _withBusy(key, false),
          notice: _notice('Снимок импортирован'),
        ),
      );
      await persist();
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  Future<void> _onExportRequested(
    SnapshotExportRequested event,
    Emitter<LibraryState> emit,
  ) async {
    try {
      await _saves.exportSnapshot(event.snapshot, event.destination);
      emit(state.copyWith(notice: _notice('Сохранено: ${event.destination}')));
    } on Object catch (error) {
      emit(state.copyWith(notice: _notice(error.toString(), isError: true)));
    }
  }

  Future<void> _onSnapshotDeleted(
    SnapshotDeleted event,
    Emitter<LibraryState> emit,
  ) async {
    final list = state.snapshots[event.snapshot.gameId];
    if (list != null) {
      final snapshots = Map<String, List<SaveSnapshot>>.from(state.snapshots);
      snapshots[event.snapshot.gameId] = list
          .where((s) => s.id != event.snapshot.id)
          .toList();
      emit(state.copyWith(snapshots: snapshots));
    }
    try {
      await _saves.deleteSnapshot(event.snapshot);
    } on Object catch (error) {
      emit(state.copyWith(notice: _notice(error.toString(), isError: true)));
    }
    await persist();
  }

  Future<File> _exportToSyncFolder(SaveSnapshot snapshot) async {
    final folder = settings.state.syncFolder;
    if (folder == null) {
      throw SaveException('Папка синхронизации не задана в настройках.');
    }
    final safeTitle = snapshot.gameTitle
        .replaceAll(RegExp(r'[^\w\s.-]', unicode: true), '_')
        .trim();
    final name =
        '$safeTitle - ${snapshot.deviceName}${SaveSnapshot.fileExtension}';
    return _saves.exportSnapshot(snapshot, p.join(folder, name));
  }

  Future<void> _onSyncScanRequested(
    SyncFolderScanRequested event,
    Emitter<LibraryState> emit,
  ) async {
    final folder = settings.state.syncFolder;
    if (folder == null) {
      emit(state.copyWith(syncPackages: const [], syncScanned: true));
      return;
    }
    emit(state.copyWith(scanningSync: true));
    try {
      final packages = await _saves.scanSyncFolder(folder);
      emit(
        state.copyWith(
          syncPackages: packages,
          scanningSync: false,
          syncScanned: true,
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          scanningSync: false,
          syncScanned: true,
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  Future<void> _onSyncPackageApplied(
    SyncPackageApplied event,
    Emitter<LibraryState> emit,
  ) async {
    final key = snapshotKey(event.game.id);
    emit(state.copyWith(busy: _withBusy(key, true)));
    try {
      final snapshot = await _saves.importPackage(event.path, game: event.game);
      emit(state.copyWith(snapshots: _withSnapshot(snapshot)));

      final report = await _saves.restoreSnapshot(
        game: event.game,
        snapshot: snapshot,
      );
      emit(
        state.copyWith(
          snapshots: report.backup == null
              ? state.snapshots
              : _withSnapshot(report.backup!),
          busy: _withBusy(key, false),
          notice: report.isComplete
              ? _notice('Готово: ${report.filesWritten} файлов восстановлено.')
              : _notice(
                  'Не сопоставились пути: ${report.unresolved.join(', ')}.',
                  isError: true,
                ),
        ),
      );
      await persist();
    } on Object catch (error) {
      emit(
        state.copyWith(
          busy: _withBusy(key, false),
          notice: _notice(error.toString(), isError: true),
        ),
      );
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Future<void> close() {
    // Отложенная запись не должна пропасть вместе с таймером.
    if (_persistTimer?.isActive ?? false) unawaited(persist());
    _persistTimer?.cancel();
    _launcher.runningIds.removeListener(_pushRunningGames);
    _launcher.dispose();
    return super.close();
  }
}

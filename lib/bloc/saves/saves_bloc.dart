import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/format.dart';
import '../../core/json_store.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/bulk_report.dart';
import '../../models/game.dart';
import '../../models/save_profile.dart';
import '../../models/save_snapshot.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/saves/bulk_transfer.dart';
import '../../services/saves/save_activity_watch.dart';
import '../../services/saves/save_manager.dart';
import '../../services/saves/save_path_finder.dart';
import '../../services/saves/save_path_globs.dart';
import '../../services/system/app_log.dart';
import '../bloc_common.dart';
import '../library/library_bloc.dart';
import '../notice.dart';
import '../settings/settings_bloc.dart';

part 'saves_event.dart';
part 'saves_state.dart';
part 'saves_snapshots.dart';
part 'saves_hints.dart';
part 'saves_bulk.dart';

/// Снимки сохранений: снятие, разворачивание, ротация и перенос всей
/// библиотеки разом.
///
/// Отдельный блок, а не часть [LibraryBloc]: половина того состояния была
/// про сохранения, и любое движение по ним перестраивало сетку обложек —
/// страница библиотеки подписана на своё состояние целиком.
///
/// **Зависимость строго в одну сторону.** Сохранениям нужны игры и их
/// профили, поэтому они знают библиотеку. Библиотека о них не знает вовсе:
/// что случилось с игрой, она публикует ([LibraryBloc.gameExits],
/// [LibraryBloc.gameRemovals]), а подписывается на это уже блок сохранений.
/// Иначе два блока держали бы друг друга за руки, и разорвать их снова
/// было бы нечем.
///
/// Правку игры блок считает у себя и пользуется ею сразу, а библиотеке
/// шлёт [SaveRulesAdded] вдогонку: событие ничего не возвращает, и ждать, пока
/// оно доедет до чужого состояния, значило бы вставить паузу в середину
/// каждой операции.
class SavesBloc extends Bloc<SavesEvent, SavesState>
    with NoticeBloc<SavesState>, BusyBloc<SavesEvent, SavesState> {
  SavesBloc({
    required AppPaths paths,
    required this.library,
    required this.settings,
    JsonStore? store,
    JsonStore? legacyStore,
    SaveManager? saveManager,
    NotificationService? notifications,
    L Function()? localizations,
    List<SaveRoot> Function()? saveRoots,
    AppLog Function()? log,
  }) : _localizations = localizations ?? _defaultLocalizations,
       _log = log ?? _appLog,
       notifications = notifications ?? const NoopNotificationService(),
       _store = store ?? JsonStore(paths.snapshotsFile),
       _legacyStore = legacyStore ?? JsonStore(paths.libraryFile),
       _saves = saveManager ?? SaveManager(paths: paths, log: log),
       _saveRoots = saveRoots ?? SavePathFinder.roots,
       super(const SavesState()) {
    // Собирается здесь, а не в списке инициализации: там на _saves,
    // от которого он зависит, ссылаться ещё нельзя.
    _bulk = BulkTransfer(saves: _saves, localizations: _localizations);

    on<SavesLoadRequested>(_onLoadRequested);
    on<SnapshotTaken>(_onSnapshotTaken);
    on<GameSnapshotsDropped>(_onGameSnapshotsDropped);
    on<SnapshotRequested>(_onSnapshotRequested);
    on<SnapshotRestoreRequested>(_onRestoreRequested);
    on<SnapshotImportInspectRequested>(_onImportInspectRequested);
    on<SnapshotImportDismissed>(_onImportDismissed);
    on<SnapshotImportRequested>(_onImportRequested);
    on<SnapshotExportRequested>(_onExportRequested);
    on<SnapshotDeleted>(_onSnapshotDeleted);
    on<SaveHintsRequested>(_onSaveHintsRequested);
    on<SavePathSuggestionsRequested>(_onSavePathSuggestionsRequested);
    on<SavePathsPresenceRequested>(_onSavePathsPresenceRequested);
    on<SaveHintsAccepted>(_onSaveHintsAccepted);
    on<SaveHintsDismissed>(_onSaveHintsDismissed);
    on<BulkExportRequested>(_onBulkExport);
    on<BulkImportRequested>(_onBulkImport);
    on<SyncFolderScanRequested>(_onSyncScanRequested);
    on<SyncPackageApplied>(_onSyncPackageApplied);

    library.beforeLaunch = snapshotBeforeLaunch;
    _exits = library.gameExits.listen(_afterGameExit);
    _removals = library.gameRemovals.listen(
      (gameId) => add(GameSnapshotsDropped(gameId)),
    );
  }

  /// Откуда брать игры и куда сообщать об их правке.
  final LibraryBloc library;
  final SettingsBloc settings;

  /// Автоснимок после выхода из игры молчалив по замыслу, но его провал
  /// пользователь обязан заметить — иначе узнает, только потеряв прогресс.
  final NotificationService notifications;

  /// Откуда брать переводы для уведомлений.
  ///
  /// У блока нет `BuildContext`, поэтому локализация приходит извне функцией:
  /// язык может смениться на ходу, и держать один объект нельзя. По умолчанию
  /// русский — тесты проверяют текст уведомлений и языка не задают.
  final L Function() _localizations;

  L get _l => _localizations();

  /// Куда писать о том, что гасится молча: уборка хранилища, удаление
  /// снимков. Функцией, а не глобалом: глобал один на весь прогон, и
  /// тест, поставивший свой журнал, отбирает его у соседнего файла —
  /// тесты идут параллельно.
  final AppLog Function() _log;

  static AppLog _appLog() => AppLog.instance;

  /// Где смотреть следы работы игры. Подменяется в тестах: настоящие
  /// «Документы» и `AppData` там обходить незачем и небезопасно.
  final List<SaveRoot> Function() _saveRoots;

  final JsonStore _store;

  /// Библиотечный файл — только на чтение и только ради переезда: до 0.33
  /// снимки лежали в нём вместе с играми.
  final JsonStore _legacyStore;

  final SaveManager _saves;

  /// Перенос сохранений всей библиотеки: единственная операция, идущая по
  /// всем играм разом, и единственная со своим счётом исходов.
  late final BulkTransfer _bulk;

  late final StreamSubscription<GameExit> _exits;
  late final StreamSubscription<String> _removals;

  Timer? _persistTimer;
  bool _closing = false;

  /// Записи списка снимков, которые эта сборка не прочла, — как лежали.
  ///
  /// По игре: список нечитаемых записей или само значение, если и списком
  /// оно не было. Пишутся обратно нетронутыми: непонятое — не значит
  /// испорченное, его могла оставить сборка новее, и выбросить его значило
  /// бы потерять снимок, который она прочтёт.
  final Map<String, Object?> _unread = {};

  /// Список снимков прочитан не целиком — уборке хранилища до конца сеанса
  /// хода нет.
  ///
  /// Список — единственное, что говорит уборке, какое содержимое живо, и
  /// прочитанный не целиком он называет мёртвым всё, на что ссылалось
  /// непрочитанное. Уборка следом за первым же снимком уносила содержимое
  /// всех таких снимков, а карантинная копия списка оставалась ссылаться в
  /// пустоту. Чего не поняли — не удаляем.
  bool _listDamaged = false;

  /// Чтение манифеста чужого `.evsave` состояния не меняет, поэтому диалог
  /// подтверждения обращается к менеджеру напрямую.
  // ignore: avoid_public_bloc_methods
  SaveManager get saveManager => _saves;

  static L _defaultLocalizations() => LRu();

  static String snapshotKey(String gameId) => 'snapshot:$gameId';

  /// Ключ занятости поиска папок по названию игры.
  static String suggestKey(String gameId) => 'suggest:$gameId';

  /// Ключ занятости для операций над всей библиотекой сразу.
  static const bulkKey = 'bulk';

  /// Допуск на расхождение часов при массовой загрузке. Само правило живёт
  /// в [BulkTransfer]; здесь — чтобы на него можно было сослаться, зная
  /// только блок.
  static const conflictTolerance = BulkTransfer.defaultConflictTolerance;

  /// Короче этого запуск не считаем игрой: сейвы за такое время не заводят.
  static const _shortestWatchedSession = Duration(seconds: 30);

  @override
  String get logTag => 'сохранения';

  void _notifySystem(AppNotification notification) {
    if (!settings.state.systemNotifications) return;
    unawaited(notifications.show(notification));
  }

  /// Добавляет игре правила у себя и сообщает о них библиотеке.
  ///
  /// Возвращает поправленную игру, потому что пользоваться ею нужно тут же:
  /// событие ничего не возвращает, и дожидаться, пока оно доедет до чужого
  /// состояния, значило бы вставить паузу в середину операции. Библиотеке
  /// уходят сами правила, а не игра: она применит их к своей текущей игре
  /// и ничего из пришедшего тем временем не затрёт.
  Game _addRules(
    Game game,
    List<SavePathRule> rules, {
    List<String> resolvedPaths = const [],
  }) {
    library.add(SaveRulesAdded(game.id, rules, resolvedPaths: resolvedPaths));
    return game.copyWith(
      saveDiscovery: game.saveDiscovery.copyWith(
        ludusaviResolvedPaths: {
          ...game.saveDiscovery.ludusaviResolvedPaths,
          ...resolvedPaths,
        }.toList(),
      ),
      saveProfile: game.saveProfile.copyWith(
        rules: [...game.saveProfile.rules, ...rules],
      ),
    );
  }

  Future<void> persist() async {
    _persistTimer?.cancel();
    await _store.write({'version': 1, 'snapshots': _snapshotsJson()});
  }

  /// Снимки для записи — вместе с тем, что прочитать не удалось.
  ///
  /// Нечитаемое значение игры, не бывшее списком, уступает место только
  /// свежим снимкам той же игры: дописать к нему нечего.
  Map<String, Object?> _snapshotsJson() => {
    ..._unread,
    for (final MapEntry(key: gameId, value: list) in state.snapshots.entries)
      gameId: [
        ...list.map((s) => s.toJson()),
        if (_unread[gameId] case final List<Object?> raw) ...raw,
      ],
  };

  /// Читает список снимков, а на первом запуске после обновления —
  /// забирает его из библиотечного файла.
  ///
  /// Переезд односторонний и молчаливый: свой файл появляется при первой
  /// же записи, а библиотека перестаёт записывать ключ `snapshots` — тот
  /// просто исчезает из неё сам. Отдельного шага «мигрировать» нет, потому
  /// что и мигрировать нечего: список читается один раз при старте.
  Future<void> _onLoadRequested(
    SavesLoadRequested event,
    Emitter<SavesState> emit,
  ) async {
    final own = await _readSnapshots(_store);
    if (own != null) {
      emit(state.copyWith(snapshots: own, loaded: true));
      _reportDamage(emit);
      return;
    }

    final inherited = await _readSnapshots(_legacyStore) ?? const {};
    emit(state.copyWith(snapshots: inherited, loaded: true));
    _reportDamage(emit);
    // Записываем сразу, даже пустое: иначе на каждом запуске мы бы снова
    // читали библиотечный файл в поисках того, чего там уже нет.
    await persist();
  }

  /// Снимки из документа; null — документа нет или ключа в нём нет.
  ///
  /// Испорченные записи пропускаются поштучно: снимок, который не читается,
  /// не повод потерять остальные. Но и сами они не выбрасываются — ложатся
  /// в [_unread] и пишутся обратно как были.
  Future<Map<String, List<SaveSnapshot>>?> _readSnapshots(
    JsonStore store,
  ) async {
    final raw = await store.readAs((json) => json['snapshots']);
    if (raw == null) return null;
    if (raw is! Map<String, dynamic>) {
      // Ключ есть, но не тот, что ждали: файл целиком откладываем в
      // сторону, как любой непрочитанный.
      await store.quarantine();
      return null;
    }

    final snapshots = <String, List<SaveSnapshot>>{};
    raw.forEach((gameId, value) {
      if (value is! List) {
        _unread[gameId] = value;
        return;
      }
      final recovered = <SaveSnapshot>[];
      final unread = <Object?>[];
      for (final entry in value) {
        final snapshot = _snapshotOrNull(entry);
        snapshot == null ? unread.add(entry) : recovered.add(snapshot);
      }
      snapshots[gameId] = recovered;
      if (unread.isNotEmpty) _unread[gameId] = unread;
    });
    return snapshots;
  }

  static SaveSnapshot? _snapshotOrNull(Object? entry) {
    try {
      return SaveSnapshot.fromJson(entry as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  /// Прочитано не всё — уборку запрещаем и говорим об этом человеку.
  ///
  /// Сообщением, как у библиотеки: молча это кончалось потерей содержимого
  /// снимков, о которой узнавали в день восстановления.
  void _reportDamage(Emitter<SavesState> emit) {
    final quarantined = _store.recoveryPath ?? _legacyStore.recoveryPath;
    if (quarantined == null && _unread.isEmpty) return;
    _listDamaged = true;
    _log().write(
      'список снимков прочитан не целиком '
      '(нечитаемых записей у игр: ${_unread.length}, '
      'копия: ${quarantined ?? 'нет'}); уборка хранилища — до перезапуска нет',
    );
    final text = quarantined == null
        ? _l.noticeSnapshotsPartlyRead
        : _l.noticeSnapshotsRecovered(quarantined);
    emit(state.copyWith(notice: notice(text, isError: true)));
  }

  /// Игру удалили из библиотеки — её снимки больше никому не нужны.
  Future<void> _onGameSnapshotsDropped(
    GameSnapshotsDropped event,
    Emitter<SavesState> emit,
  ) async {
    // Нечитаемые записи уходят вместе с игрой: хранить их больше незачем, а
    // уборка до перезапуска всё равно стоит.
    final hadUnread = _unread.remove(event.gameId) != null;
    final removed = state.snapshots[event.gameId];
    if (removed == null) {
      if (hadUnread) await persist();
      return;
    }

    final snapshots = Map<String, List<SaveSnapshot>>.from(state.snapshots);
    snapshots.remove(event.gameId);
    emit(
      state.copyWith(
        snapshots: snapshots,
        saveHints: _withoutHints(event.gameId),
      ),
    );
    await persist();

    for (final snapshot in removed) {
      try {
        await _saves.deleteSnapshot(snapshot);
      } on Object catch (error) {
        _log().write('удаление снимков игры ${event.gameId}', error);
      }
    }
    await _collectGarbage();
  }

  Map<String, List<SavePathSuggestion>> _withoutHints(String gameId) => {
    for (final entry in state.saveHints.entries)
      if (entry.key != gameId) entry.key: entry.value,
  };

  /// Убирает содержимое снимков, на которое больше никто не ссылается.
  ///
  /// Хранилище общее для всех игр, а список живых ссылок целиком виден
  /// только отсюда: снимок можно выкинуть у одной игры, а его файлы —
  /// оставаться нужными другой, если обе привезли один и тот же пакет.
  Future<void> _collectGarbage() async {
    if (_listDamaged) return;
    try {
      final (:moved, :purged) = await _saves.collectGarbage(
        state.snapshots.values.expand((list) => list),
      );
      // Только когда и правда убрали: уборка идёт следом за каждым снимком
      // и чаще всего не находит ничего, а журнал, полный нулей, никто
      // читать не станет. Зато «куда делись гигабайты» — вопрос, который
      // задают через неделю, и ответ на него должен где-то лежать.
      if (moved > 0) {
        _log().write(
          'уборка хранилища снимков вынесла в корзину ${formatBytes(moved)}',
        );
      }
      if (purged > 0) {
        _log().write(
          'уборка хранилища снимков освободила ${formatBytes(purged)}',
        );
      }
    } on Object catch (error) {
      // Уборка — дело подсобное: не вышло, значит место освободится позже.
      _log().write('уборка хранилища снимков', error);
    }
  }

  /// Снимает сейв до того, как игра начнёт работать.
  ///
  /// Автоснимок после выхода бесполезен против игры, которая портит своё
  /// сохранение при старте: к моменту выхода портить уже нечего, и снимок
  /// закрепит испорченное. Поэтому снимаем именно до запуска и именно
  /// дожидаясь: снимок, снятый параллельно со стартом игры, застаёт файлы
  /// в неизвестном состоянии, а значит, не годится ни на что.
  ///
  /// Провал запускать не мешает: играть человек собрался, а резервная
  /// копия — услуга, а не условие. Молча провалиться она при этом не
  /// вправе — об этом сообщает система, как и о неудавшемся автоснимке
  /// после выхода.
  ///
  /// Не событием, а методом: библиотека обязана его дождаться, а события
  /// не дожидаются. Записать снятое в состояние — уже дело события.
  Future<void> snapshotBeforeLaunch(Game game) async {
    final profile = game.saveProfile;
    if (!profile.autoSnapshotOnLaunch) return;
    final discovered = game.saveDiscovery.ludusaviTemplates;
    if (!profile.isConfigured && discovered.isEmpty) return;

    try {
      final snapshot = await _saves.createSnapshot(
        game,
        origin: SnapshotOrigin.autoOnLaunch,
      );
      add(SnapshotTaken(snapshot));
    } on SaveNothingFoundException {
      // Сейвов ещё нет — первый запуск. Сохранять нечего, и это не беда.
    } on Object catch (error) {
      _notifySystem(
        AppNotification(
          title: _l.noticeSnapshotFailed,
          body: _l.noticeSaveFailedBody(
            game.title,
            error is SaveException ? error.message : error.toString(),
          ),
          kind: NotificationKind.saveFailed,
        ),
      );
    }
  }

  /// Кладёт уже снятый снимок в состояние и подрезает лишние.
  Future<void> _onSnapshotTaken(
    SnapshotTaken event,
    Emitter<SavesState> emit,
  ) async {
    emit(state.copyWith(snapshots: _withSnapshot(event.snapshot)));
    await _prune(event.snapshot.gameId, emit);
    await persist();
  }

  /// Что делать с сохранениями после выхода из игры.
  ///
  /// Решение принимается здесь, а не в библиотеке: она сообщает только
  /// факт — кто вышел и сколько отыграл.
  void _afterGameExit(GameExit exit) {
    if (_closing) return;
    final game = exit.game;

    if (game.saveProfile.autoSnapshotOnExit &&
        (game.saveProfile.isConfigured ||
            game.saveDiscovery.ludusaviTemplates.isNotEmpty)) {
      add(SnapshotRequested(game, origin: SnapshotOrigin.autoOnExit));
    }

    // Слишком короткий сеанс — обычно неудачный запуск: игра не успела
    // ничего записать, а обход папок стоит секунд.
    if (exit.played >= _shortestWatchedSession) {
      add(
        SaveHintsRequested(
          game: game,
          since: DateTime.now().subtract(exit.played),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _closing = true;
    library.beforeLaunch = null;
    await _exits.cancel();
    await _removals.cancel();
    // Отложенную запись именно дожидаемся: запущенная и брошенная, она не
    // успевает лечь на диск, и последний снимок теряется при выходе.
    final pending = _persistTimer?.isActive ?? false;
    _persistTimer?.cancel();
    if (pending) await persist();
    await _store.flush();
    return super.close();
  }
}

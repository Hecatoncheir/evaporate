part of 'saves_bloc.dart';

/// Пакет, который уже разобрали, но ещё не приняли.
class PendingImport extends Equatable {
  const PendingImport({required this.game, required this.info});

  /// Игра, к которой его прикладывают.
  final Game game;

  final SavePackageInfo info;

  @override
  List<Object?> get props => [game.id, info.path];
}

/// Снимки сохранений и всё, что вокруг них.
///
/// Отдельно от [LibraryState], потому что смотрят на это в других местах:
/// страница сохранений, карточка игры и диалог восстановления. Пока оба
/// списка лежали в одном состоянии, снятый снимок перестраивал сетку
/// обложек — библиотека подписана на своё состояние целиком.
class SavesState extends Equatable implements BusyState<SavesState> {
  const SavesState({
    this.snapshots = const {},
    this.saveHints = const {},
    this.pathPresence = const {},
    this.pendingImport,
    this.syncPackages = const [],
    this.scanningSync = false,
    this.syncScanned = false,
    this.bulkReport,
    this.busy = const {},
    this.loaded = false,
    this.notice,
  });

  /// Снимки по играм, свежий первым.
  final Map<String, List<SaveSnapshot>> snapshots;

  /// Папки, изменившиеся, пока игра работала, — по игре. Это догадка, и
  /// пока человек её не подтвердил, правилом она не становится.
  final Map<String, List<SavePathSuggestion>> saveHints;

  /// Лежит ли на диске папка правила — по развёрнутому пути.
  ///
  /// Пусто — не «нет», а «не знаем»: пока проверка не прошла, говорить
  /// человеку «на диске нет» нельзя. Раньше это спрашивалось у диска прямо
  /// в `build`, дважды на каждое правило и на каждый кадр.
  final Map<String, bool> pathPresence;

  /// Разобранный пакет, о котором ещё спрашивают человека.
  ///
  /// Чтение чужого файла — настоящий ввод-вывод, и упасть оно умеет: у
  /// виджета для этого нет ни `Notice`, ни журнала.
  final PendingImport? pendingImport;

  /// Пакеты `.evsave`, найденные в папке синхронизации.
  final List<SavePackageInfo> syncPackages;
  final bool scanningSync;
  final bool syncScanned;

  /// Итог последней массовой операции: одной строкой «с ошибкой: 3»
  /// пользоваться нельзя — непонятно, какие игры и почему.
  final BulkReport? bulkReport;

  /// Ключи выполняющихся операций — виджетам не нужен собственный `_busy`.
  @override
  final Set<String> busy;
  final bool loaded;
  @override
  final Notice? notice;

  List<SaveSnapshot> snapshotsFor(String gameId) =>
      snapshots[gameId] ?? const <SaveSnapshot>[];

  int get totalSnapshotCount =>
      snapshots.values.fold(0, (sum, list) => sum + list.length);

  bool isBusy(String key) => busy.contains(key);

  List<SavePathSuggestion> hintsFor(String gameId) =>
      saveHints[gameId] ?? const <SavePathSuggestion>[];

  /// Все снимки перечисленных игр, свежие сверху.
  ///
  /// Экран сохранений показывает их одним списком: это ответ на вопрос
  /// «что у меня вообще сохранено», а не «что сохранено у этой игры» — на
  /// него отвечает карточка на странице самой игры.
  ///
  /// Статикой над двумя полями, а не методом состояния: экран выбирает из
  /// состояний только игры и снимки и пересобирается, когда меняются они.
  /// Прежде он подписывался на состояния целиком, и сортировка всех
  /// снимков библиотеки шла на каждое сообщение и каждую занятость.
  static List<(Game, SaveSnapshot)> entriesOf(
    List<Game> games,
    Map<String, List<SaveSnapshot>> snapshots,
  ) {
    final entries = <(Game, SaveSnapshot)>[
      for (final game in games)
        for (final snapshot in snapshots[game.id] ?? const <SaveSnapshot>[])
          (game, snapshot),
    ];
    entries.sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
    return entries;
  }

  /// `null` — ещё не проверяли.
  bool? pathExists(String? resolved) =>
      resolved == null ? null : pathPresence[resolved];

  SavesState copyWith({
    Map<String, List<SaveSnapshot>>? snapshots,
    Map<String, List<SavePathSuggestion>>? saveHints,
    Map<String, bool>? pathPresence,
    Object? pendingImport = _unset,
    List<SavePackageInfo>? syncPackages,
    bool? scanningSync,
    bool? syncScanned,
    Object? bulkReport = _unset,
    Set<String>? busy,
    bool? loaded,
    Object? notice = _unset,
  }) {
    return SavesState(
      snapshots: snapshots ?? this.snapshots,
      saveHints: saveHints ?? this.saveHints,
      pathPresence: pathPresence ?? this.pathPresence,
      pendingImport: pendingImport == _unset
          ? this.pendingImport
          : pendingImport as PendingImport?,
      syncPackages: syncPackages ?? this.syncPackages,
      scanningSync: scanningSync ?? this.scanningSync,
      syncScanned: syncScanned ?? this.syncScanned,
      bulkReport: bulkReport == _unset
          ? this.bulkReport
          : bulkReport as BulkReport?,
      busy: busy ?? this.busy,
      loaded: loaded ?? this.loaded,
      notice: notice == _unset ? this.notice : notice as Notice?,
    );
  }

  @override
  SavesState withBusy(Set<String> busy, {Notice? notice}) =>
      copyWith(busy: busy, notice: notice ?? this.notice);

  @override
  List<Object?> get props => [
    snapshots,
    saveHints,
    pathPresence,
    pendingImport,
    syncPackages,
    scanningSync,
    syncScanned,
    bulkReport,
    busy,
    loaded,
    notice,
  ];

  static const _unset = Object();
}

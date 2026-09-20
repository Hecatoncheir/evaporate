part of 'library_bloc.dart';

/// События сравниваются **по тому, о чём они**, а не по всему содержимому:
/// в `props` идут `game.id` и `snapshot.id`, а не сами объекты. Иначе
/// сравнение свелось бы к тождеству ссылок — ни `Game`, ни `SaveSnapshot`
/// не `Equatable`, — и «то же событие о той же игре» никогда не совпало бы
/// само с собой. Ничего, кроме тестов, события здесь не сравнивает, и
/// трансформеры, которым равенство важно (`droppable`, `restartable`), не
/// используются.
sealed class LibraryEvent extends Equatable {
  const LibraryEvent();

  @override
  List<Object?> get props => [];
}

final class LibraryLoadRequested extends LibraryEvent {
  const LibraryLoadRequested();
}

/// Идентификатор генерирует вызывающая сторона: диалогу добавления нужно
/// сразу знать, какую игру выделять, а событие ничего не возвращает.
final class GameAdded extends LibraryEvent {
  const GameAdded({
    required this.id,
    required this.title,
    this.source,
    this.installDir,
    this.executablePath,
    this.status = GameStatus.notInstalled,
    this.steamAppId,
  });

  final String id;
  final String title;
  final GameSource? source;
  final String? installDir;
  final String? executablePath;
  final GameStatus status;

  /// Точный идентификатор Steam, если он известен заранее.
  ///
  /// Его приносят манифесты Steam с диска. С ним поиск по названию не нужен
  /// вовсе, а пути сохранений ищутся по идентификатору — то есть без риска
  /// подставить сейвы другой игры с похожим именем.
  final int? steamAppId;

  @override
  List<Object?> get props => [
    id,
    title,
    steamAppId,
    source,
    installDir,
    executablePath,
    status,
  ];
}

// Правки игры — намерения, а не снимки.
//
// Прежде правку несла целая игра, `GameUpdated(game)`, захваченная в миг
// отправки. Между захватом и обработкой проходили ожидания — системный
// диалог выбора файла, ответ Steam, выход из игры, — и снимок затирал всё,
// что успело прийти за это время: оценку, кадры, наигранное время. Список
// полей, которые обработчик спасал поимённо, отставал от модели при
// каждом новом поле. Теперь событие называет, что меняется, а блок
// применяет это к **текущей** игре: затереть чужое ему нечем.

/// Состояние игры сменилось: загрузка встала на паузу, пошла дальше или
/// сорвалась. [lastError] пишется только вместе с [GameStatus.error].
final class GameStatusChanged extends LibraryEvent {
  const GameStatusChanged(this.gameId, this.status, {this.lastError});

  final String gameId;
  final GameStatus status;
  final String? lastError;

  @override
  List<Object?> get props => [gameId, status, lastError];
}

/// Движок принял раздачу: игра качается из [source] задачей [taskId].
final class GameDownloadStarted extends LibraryEvent {
  const GameDownloadStarted(this.gameId, this.source, this.taskId);

  final String gameId;
  final GameSource source;
  final String taskId;

  @override
  List<Object?> get props => [gameId, source, taskId];
}

/// Игру заново связали с задачей движка: после перезапуска у задач новые
/// идентификаторы, а infohash раздачи по magnet приходит не сразу.
final class GameDownloadLinked extends LibraryEvent {
  const GameDownloadLinked(this.gameId, {this.taskId, this.infoHash});

  final String gameId;
  final String? taskId;
  final String? infoHash;

  @override
  List<Object?> get props => [gameId, taskId, infoHash];
}

/// Загрузку сняли — отменой или из самого движка: игра снова не
/// установлена.
final class GameDownloadDropped extends LibraryEvent {
  const GameDownloadDropped(this.gameId);

  final String gameId;

  @override
  List<Object?> get props => [gameId];
}

/// Загрузка закончилась и прошла проверку: игра установлена в
/// [installDir]. [executablePath] — догадка, и уже выбранный человеком файл
/// она не заменяет. [metadataQuery] — имя раздачи, по которому искать игру
/// в Steam.
final class GameDownloadFinished extends LibraryEvent {
  const GameDownloadFinished(
    this.gameId, {
    required this.installDir,
    required this.sizeBytes,
    this.executablePath,
    this.metadataQuery,
  });

  final String gameId;
  final String installDir;
  final int sizeBytes;
  final String? executablePath;
  final String? metadataQuery;

  @override
  List<Object?> get props => [
    gameId,
    installDir,
    sizeBytes,
    executablePath,
    metadataQuery,
  ];
}

/// Загрузка закончилась, но проверку не прошла: игра в [installDir] есть,
/// а объявить её готовой нельзя.
final class GameDownloadRejected extends LibraryEvent {
  const GameDownloadRejected(
    this.gameId, {
    required this.installDir,
    required this.reason,
  });

  final String gameId;
  final String installDir;
  final String reason;

  @override
  List<Object?> get props => [gameId, installDir, reason];
}

/// Человек выбрал, что запускать.
/// Завести в библиотеку отмеченное в окне поиска.
///
/// Одним событием, а не по одному на игру: их бывают десятки, и каждое
/// откладывало бы свою запись на диск и свой поиск метаданных.
final class ScannedGamesAdded extends LibraryEvent {
  const ScannedGamesAdded(this.games);

  final List<ScannedGame> games;

  @override
  List<Object?> get props => [
    [for (final game in games) game.installDir],
  ];
}

/// В окно бросили файлы или папки.
///
/// Разбор и заведение игр — в блоке: у приёмника нет ни журнала, ни
/// `Notice`, а исключение из разбора уходило в никуда.
final class FilesDropped extends LibraryEvent {
  const FilesDropped(this.paths, {required this.select});

  final List<String> paths;

  /// Подсветить добавленное в сетке библиотеки.
  final bool select;

  @override
  List<Object?> get props => [paths, select];
}

/// Показать папку установки игры в системном проводнике.
///
/// Событием, а не вызовом из виджета: команда отличается системой, отказ
/// приходит исключением, и сказать о нём человеку должен тот же `Notice`,
/// что и обо всём остальном.
final class GameFolderOpenRequested extends LibraryEvent {
  const GameFolderOpenRequested(this.gameId);

  final String gameId;

  @override
  List<Object?> get props => [gameId];
}

final class GameExecutableSet extends LibraryEvent {
  const GameExecutableSet(this.gameId, this.path);

  final String gameId;
  final String path;

  @override
  List<Object?> get props => [gameId, path];
}

/// Человек указал, куда игра уже установлена. Что в ней запускать, блок
/// ищет сам, если это ещё не выбрано.
final class GameInstallDirSet extends LibraryEvent {
  const GameInstallDirSet(this.gameId, this.dir);

  final String gameId;
  final String dir;

  @override
  List<Object?> get props => [gameId, dir];
}

/// Правила сохранений, добавленные к уже заданным.
///
/// Несёт готовые правила, а не шаблоны: тот, кто их добавил, мог уже снять
/// по ним снимок, и id с метками у правил в библиотеке обязаны быть теми же.
/// Правило с шаблоном, который у игры уже есть, пропускается.
/// [resolvedPaths] — развёрнутые пути базы, которые больше не предлагать.
final class SaveRulesAdded extends LibraryEvent {
  const SaveRulesAdded(
    this.gameId,
    this.rules, {
    this.resolvedPaths = const [],
  });

  final String gameId;
  final List<SavePathRule> rules;
  final List<String> resolvedPaths;

  @override
  List<Object?> get props => [gameId, rules, resolvedPaths];
}

final class SaveRuleRemoved extends LibraryEvent {
  const SaveRuleRemoved(this.gameId, this.ruleId);

  final String gameId;
  final String ruleId;

  @override
  List<Object?> get props => [gameId, ruleId];
}

/// Когда снимать сохранения самому; `null` — не трогать.
final class AutoSnapshotChanged extends LibraryEvent {
  const AutoSnapshotChanged(this.gameId, {this.onExit, this.onLaunch});

  final String gameId;
  final bool? onExit;
  final bool? onLaunch;

  @override
  List<Object?> get props => [gameId, onExit, onLaunch];
}

final class GameRemoved extends LibraryEvent {
  const GameRemoved(this.game, {this.deleteFiles = false});

  final Game game;
  final bool deleteFiles;

  @override
  List<Object?> get props => [game.id, deleteFiles];
}

final class GameLaunchRequested extends LibraryEvent {
  const GameLaunchRequested(this.game);

  final Game game;

  @override
  List<Object?> get props => [game.id];
}

final class GameStopRequested extends LibraryEvent {
  const GameStopRequested(this.game);

  final Game game;

  @override
  List<Object?> get props => [game.id];
}

/// Процесс игры завершился. Событие приходит из колбэка лаунчера — это тот
/// случай, ради которого события удобнее методов: внешний источник просто
/// кладёт факт в очередь, а блок решает, что с ним делать.
final class GameExited extends LibraryEvent {
  const GameExited({
    required this.gameId,
    required this.played,
    required this.exitCode,
  });

  final String gameId;
  final Duration played;
  final int exitCode;

  @override
  List<Object?> get props => [gameId, played, exitCode];
}

/// Набор запущенных игр изменился (из лаунчера).
final class RunningGamesChanged extends LibraryEvent {
  const RunningGamesChanged(this.ids);

  final Set<String> ids;

  @override
  List<Object?> get props => [ids];
}

/// Завести игру в Steam как стороннюю — то же, что «Добавить стороннюю
/// игру в мою библиотеку» в самом Steam.
final class SteamShortcutRequested extends LibraryEvent {
  const SteamShortcutRequested(this.game);

  final Game game;

  @override
  List<Object?> get props => [game.id];
}

/// Подтянуть описание и обложку из каталога Steam по имени раздачи.
final class SteamLookupRequested extends LibraryEvent {
  const SteamLookupRequested(this.game, {this.query, this.automatic = false});

  final Game game;

  /// Имя раздачи, если оно отличается от названия игры в библиотеке.
  final String? query;
  final bool automatic;

  @override
  List<Object?> get props => [game.id, query, automatic];
}

/// Поискать метаданные заново для всех игр, которым их не хватает.
///
/// Автоматический поиск после неудачи не повторяется — и правильно: иначе
/// приложение при каждом запуске долбилось бы в Steam за играми, которых там
/// нет. Но первый запуск мог прийтись на офлайн, и тогда без обложек
/// оставалась вся библиотека сразу, а кнопка поиска есть только у отдельной
/// игры. Это то же самое действие, но разом и по воле человека.
final class MetadataRetryRequested extends LibraryEvent {
  const MetadataRetryRequested();

  @override
  List<Object?> get props => const [];
}

/// Сходить в Steam за всеми играми разом, даже если у них всё на месте.
///
/// [MetadataRetryRequested] спрашивает только про нехватку, и этого хватает,
/// пока точки данных не меняются. Но они меняются: сперва к обложке и
/// описанию добавилась оценка, потом кадры из игры, — и у сложившейся
/// библиотеки нехватки нет, цепочка у неё пройдена до конца. Прежде под
/// каждую новую точку правили отбор «чего не хватает»; вместо этого здесь
/// одно честное «спросить заново про всё».
///
/// Отдельной кнопкой, а не заменой прежней: это десятки запросов к Steam по
/// очереди, и делать так при каждом «поискать недостающее» незачем.
final class MetadataRefreshRequested extends LibraryEvent {
  const MetadataRefreshRequested();

  @override
  List<Object?> get props => const [];
}

/// Подобрать папки сохранений по открытой базе путей.
final class SavePathsLookupRequested extends LibraryEvent {
  const SavePathsLookupRequested(
    this.game, {
    this.refresh = false,
    this.automatic = false,
  });

  final Game game;

  /// Перекачать базу, а не брать из кэша.
  final bool refresh;
  final bool automatic;

  @override
  List<Object?> get props => [game.id, refresh, automatic];
}

/// Каталог путей сообщил, как продвигается загрузка или разбор.
///
/// Событие приходит не от пользователя, а от самого каталога — тот случай,
/// ради которого события удобнее методов.
final class SavePathsProgressChanged extends LibraryEvent {
  const SavePathsProgressChanged(this.progress);

  final CatalogProgress? progress;

  @override
  List<Object?> get props => [progress];
}

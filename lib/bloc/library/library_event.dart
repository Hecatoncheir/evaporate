part of 'library_bloc.dart';

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

final class GameUpdated extends LibraryEvent {
  const GameUpdated(this.game, {this.metadataQuery});

  final Game game;
  final String? metadataQuery;

  @override
  List<Object?> get props => [
    game.id,
    game.status,
    game.saveProfile.rules,
    metadataQuery,
  ];
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

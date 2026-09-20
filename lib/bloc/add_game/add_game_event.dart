part of 'add_game_bloc.dart';

sealed class AddGameEvent extends Equatable {
  const AddGameEvent();

  @override
  List<Object?> get props => [];
}

/// Выбрали, откуда берётся игра.
final class AddGameKindChanged extends AddGameEvent {
  const AddGameKindChanged(this.kind);

  final GameSourceKind kind;

  @override
  List<Object?> get props => [kind];
}

/// Набрали или вставили magnet-ссылку.
final class AddGameMagnetChanged extends AddGameEvent {
  const AddGameMagnetChanged(this.magnet);

  final String magnet;

  @override
  List<Object?> get props => [magnet];
}

/// Набрали название.
final class AddGameTitleChanged extends AddGameEvent {
  const AddGameTitleChanged(this.title);

  final String title;

  @override
  List<Object?> get props => [title];
}

/// Выбрали файл раздачи в системном окне.
final class AddGameTorrentPicked extends AddGameEvent {
  const AddGameTorrentPicked(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

/// Выбрали папку установки в системном окне.
final class AddGameFolderPicked extends AddGameEvent {
  const AddGameFolderPicked(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

/// Переключили «начать загрузку сразу».
final class AddGameStartImmediatelyChanged extends AddGameEvent {
  const AddGameStartImmediatelyChanged({required this.start});

  final bool start;

  @override
  List<Object?> get props => [start];
}

/// Нажали «Добавить».
final class AddGameSubmitted extends AddGameEvent {
  const AddGameSubmitted();
}

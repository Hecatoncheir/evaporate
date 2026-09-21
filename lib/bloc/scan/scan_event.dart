part of 'scan_bloc.dart';

sealed class ScanEvent extends Equatable {
  const ScanEvent();

  @override
  List<Object?> get props => [];
}

/// Обход что-то нашёл, закончился или начался заново.
final class ScanSessionChanged extends ScanEvent implements FrequentEvent {
  const ScanSessionChanged();
}

/// Искать только в этой папке.
final class ScanNarrowed extends ScanEvent {
  const ScanNarrowed(this.directory);

  final String directory;

  @override
  List<Object?> get props => [directory];
}

/// В окно поиска что-то бросили.
final class ScanFolderDropped extends ScanEvent {
  const ScanFolderDropped(this.paths);

  final List<String> paths;

  @override
  List<Object?> get props => [paths];
}

/// Хватит искать. Найденное при этом остаётся: «хватит искать» и «забудь
/// найденное» — разные вещи.
final class ScanStopRequested extends ScanEvent {
  const ScanStopRequested();
}

/// Человек снял или поставил галочку у находки.
final class ScanGameToggled extends ScanEvent {
  const ScanGameToggled(this.game, {required this.selected});

  final ScannedGame game;
  final bool selected;

  @override
  List<Object?> get props => [game.installDir, selected];
}

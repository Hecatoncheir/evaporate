part of 'scan_bloc.dart';

/// Что нашли и что из этого отмечено.
class ScanState extends Equatable {
  const ScanState({
    this.found = const [],
    this.running = false,
    this.complete = false,
    this.wrongDrop = false,
    this.unchecked = const {},
    this.checked = const {},
  });

  final List<ScannedGame> found;

  /// Обход идёт прямо сейчас.
  final bool running;

  /// Обход дошёл до конца — в отличие от остановленного на полпути.
  final bool complete;

  /// Бросили не папку.
  final bool wrongDrop;

  /// Снятое человеком с уверенных находок.
  final Set<String> unchecked;

  /// Отмеченное человеком среди неуверенных.
  ///
  /// Реестр Windows знает всё установленное, и заранее отмечать оттуда
  /// нельзя: браузер добавился бы в библиотеку игрой, стоило нажать
  /// «Добавить».
  final Set<String> checked;

  /// Папки, которые сейчас отмечены.
  Set<String> get selectedDirs => {
    for (final game in found)
      if (isSelected(game)) game.installDir,
  };

  bool isSelected(ScannedGame game) => game.confident
      ? !unchecked.contains(game.installDir)
      : checked.contains(game.installDir);

  /// Сами отмеченные находки — их и заводят в библиотеку.
  List<ScannedGame> get selected => [
    for (final game in found)
      if (isSelected(game)) game,
  ];

  ScanState copyWith({
    List<ScannedGame>? found,
    bool? running,
    bool? complete,
    bool? wrongDrop,
    Set<String>? unchecked,
    Set<String>? checked,
  }) => ScanState(
    found: found ?? this.found,
    running: running ?? this.running,
    complete: complete ?? this.complete,
    wrongDrop: wrongDrop ?? this.wrongDrop,
    unchecked: unchecked ?? this.unchecked,
    checked: checked ?? this.checked,
  );

  @override
  List<Object?> get props => [
    found,
    running,
    complete,
    wrongDrop,
    unchecked,
    checked,
  ];
}

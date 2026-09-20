part of 'add_game_bloc.dart';

/// Набранное в окне и что из него вышло.
class AddGameForm extends Equatable {
  const AddGameForm({
    this.kind = GameSourceKind.magnet,
    this.magnet = '',
    this.title = '',
    this.filePath,
    this.folderPath,
    this.startImmediately = true,
    this.busy = false,
    this.error,
    this.addedId,
  });

  final GameSourceKind kind;
  final String magnet;
  final String title;
  final String? filePath;
  final String? folderPath;

  /// Поставить загрузку сразу, не дожидаясь отдельного нажатия.
  final bool startImmediately;

  final bool busy;

  /// Почему не вышло — теми же словами, какими это скажут человеку.
  final String? error;

  /// Игра заведена, и вот её идентификатор: окно закрывают им, чтобы новую
  /// игру было чем выделить в списке.
  final String? addedId;

  AddGameForm copyWith({
    GameSourceKind? kind,
    String? magnet,
    String? title,
    String? filePath,
    String? folderPath,
    bool? startImmediately,
    bool? busy,
    Object? error = _unset,
    String? addedId,
  }) => AddGameForm(
    kind: kind ?? this.kind,
    magnet: magnet ?? this.magnet,
    title: title ?? this.title,
    filePath: filePath ?? this.filePath,
    folderPath: folderPath ?? this.folderPath,
    startImmediately: startImmediately ?? this.startImmediately,
    busy: busy ?? this.busy,
    error: error == _unset ? this.error : error as String?,
    addedId: addedId ?? this.addedId,
  );

  @override
  List<Object?> get props => [
    kind,
    magnet,
    title,
    filePath,
    folderPath,
    startImmediately,
    busy,
    error,
    addedId,
  ];

  static const _unset = Object();
}

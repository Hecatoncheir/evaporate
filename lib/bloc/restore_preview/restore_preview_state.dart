part of 'restore_preview_bloc.dart';

/// Что известно до восстановления.
///
/// «Не знаем» и «сохранений здесь никогда не было» — разные вещи: первое
/// молчит, второе утверждает. Раньше диалог их путал и на неудавшемся
/// чтении заявлял, что сейвы никогда не менялись, — то есть говорил
/// неправду ровно там, где человек решает, затирать ему свой прогресс.
class RestorePreview extends Equatable {
  const RestorePreview({
    this.targets = const {},
    this.known = false,
    this.changedAt,
    this.newer = false,
  });

  /// Метка правила и путь, в который оно развернулось на этой машине.
  final Map<String, String> targets;

  /// Диск прочитан. Пока нет — о здешних сохранениях молчим.
  final bool known;

  /// `null` при [known] означает, что сохранений ещё не было.
  final DateTime? changedAt;

  /// Здешние сохранения новее снимка настолько, что восстановление — это
  /// откат прогресса.
  final bool newer;

  RestorePreview copyWith({
    Map<String, String>? targets,
    bool? known,
    DateTime? changedAt,
    bool? newer,
  }) => RestorePreview(
    targets: targets ?? this.targets,
    known: known ?? this.known,
    changedAt: changedAt ?? this.changedAt,
    newer: newer ?? this.newer,
  );

  @override
  List<Object?> get props => [targets, known, changedAt, newer];
}

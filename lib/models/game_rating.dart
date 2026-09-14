/// Как игру оценили: итог обзоров Steam и, если она есть, оценка прессы.
///
/// Одним значением, а не пятью полями в [Game]: живут они вместе, приходят
/// одним поиском и устаревают тоже вместе — обзоры копятся, и вчерашние
/// счётчики без вчерашней же подписи ничего не значат.
class GameRating {
  const GameRating({
    this.score,
    this.summary,
    this.positive = 0,
    this.negative = 0,
    this.metacritic,
  });

  /// Ступень Steam, 0–9. Не показывается — по ней выбирается цвет подписи.
  final int? score;

  /// Словами и от самого Steam: «Очень положительные», «Смешанные».
  final String? summary;

  final int positive;
  final int negative;

  /// Оценка прессы, 0–100. Есть не у всех: у половины каталога её нет.
  final int? metacritic;

  int get total => positive + negative;

  /// Доля положительных, 0–100 — число, которое Steam пишет в подсказке.
  int get positiveShare => total == 0 ? 0 : (positive * 100 / total).round();

  /// Есть ли что показывать. Игра без единого обзора и без Metacritic
  /// оценки не имеет вовсе, и строка о ней была бы строкой ни о чём.
  bool get hasAnything => total > 0 || metacritic != null;

  Map<String, dynamic> toJson() => {
    if (score != null) 'score': score,
    if (summary != null) 'summary': summary,
    'positive': positive,
    'negative': negative,
    if (metacritic != null) 'metacritic': metacritic,
  };

  factory GameRating.fromJson(Map<String, dynamic> json) => GameRating(
    score: json['score'] as int?,
    summary: json['summary'] as String?,
    positive: json['positive'] as int? ?? 0,
    negative: json['negative'] as int? ?? 0,
    metacritic: json['metacritic'] as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is GameRating &&
      other.score == score &&
      other.summary == summary &&
      other.positive == positive &&
      other.negative == negative &&
      other.metacritic == metacritic;

  @override
  int get hashCode =>
      Object.hash(score, summary, positive, negative, metacritic);
}

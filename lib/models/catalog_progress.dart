import 'package:equatable/equatable.dart';

/// Чем сейчас занят каталог путей сохранений.
enum CatalogPhase {
  /// Качаем манифест — это около семнадцати мегабайт.
  downloading,

  /// Разбираем. На настоящих данных это примерно четыре секунды, поэтому
  /// разбор идёт в отдельном изоляте, а пользователю нужно сказать, что
  /// приложение не зависло.
  parsing,
}

/// Ход подготовки базы путей.
class CatalogProgress extends Equatable {
  const CatalogProgress({
    required this.phase,
    this.received = 0,
    this.total = 0,
  });

  final CatalogPhase phase;

  /// Сколько байт получено.
  final int received;

  /// Сколько всего, или ноль — сервер не сказал.
  final int total;

  static const parsing = CatalogProgress(phase: CatalogPhase.parsing);

  /// Доля от нуля до единицы или null, если размер неизвестен: полоса тогда
  /// должна бежать сама, а не показывать выдуманное число.
  double? get fraction {
    if (phase == CatalogPhase.parsing) return null;
    if (total <= 0) return null;
    return (received / total).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [phase, received, total];
}

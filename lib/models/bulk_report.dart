import 'package:equatable/equatable.dart';

/// Чем закончилась массовая операция для одной игры.
enum BulkOutcome {
  /// Сохранения выгружены или восстановлены.
  applied,

  /// Пропущено намеренно: нечего переносить или не задано куда.
  skipped,

  /// Пропущено, потому что здешние сохранения новее пакета.
  conflicted,

  /// Пакет есть, а игры с таким названием в библиотеке нет.
  unmatched,

  /// Не получилось — с причиной.
  failed,
}

/// Строка отчёта: что за игра и что с ней произошло.
class BulkEntry extends Equatable {
  const BulkEntry({required this.title, required this.outcome, this.detail});

  final String title;
  final BulkOutcome outcome;

  /// Причина — для того, что не получилось.
  final String? detail;

  @override
  List<Object?> get props => [title, outcome, detail];
}

/// Итог массовой операции.
///
/// Одной строкой «с ошибкой: 3» пользоваться нельзя: непонятно, какие игры и
/// почему. Для операции над всей библиотекой это существенно — там легко
/// не заметить, что часть сохранений не перенеслась.
class BulkReport extends Equatable {
  const BulkReport({required this.isExport, required this.entries});

  /// Выгрузка или загрузка: формулировки в отчёте разные.
  final bool isExport;
  final List<BulkEntry> entries;

  static const empty = BulkReport(isExport: true, entries: []);

  bool get isEmpty => entries.isEmpty;

  List<BulkEntry> withOutcome(BulkOutcome outcome) =>
      entries.where((e) => e.outcome == outcome).toList();

  int count(BulkOutcome outcome) =>
      entries.where((e) => e.outcome == outcome).length;

  /// Есть ли о чём беспокоиться. Пропущенное намеренно тревогой не считается.
  bool get hasProblems =>
      count(BulkOutcome.failed) > 0 ||
      count(BulkOutcome.unmatched) > 0 ||
      count(BulkOutcome.conflicted) > 0;

  @override
  List<Object?> get props => [isExport, entries];
}

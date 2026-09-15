import 'dart:io';

import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';

/// Что нашла проверка файлов после загрузки.
class IntegrityReport {
  const IntegrityReport({
    required this.checkedFiles,
    this.missing = const [],
    this.truncated = const [],
    this.skipped = false,
  });

  /// Проверять было нечего: метаданные ещё не получены.
  const IntegrityReport.skipped() : this(checkedFiles: 0, skipped: true);

  final int checkedFiles;

  /// Файлов из раздачи нет на диске.
  final List<String> missing;

  /// Файлы есть, но размер меньше заявленного — загрузка оборвана.
  final List<String> truncated;
  final bool skipped;

  bool get isValid => missing.isEmpty && truncated.isEmpty;

  String describe(L l) {
    if (skipped) return l.nothingToVerify;
    if (isValid) return l.filesInPlace(checkedFiles);
    final parts = <String>[
      if (missing.isNotEmpty) l.filesMissing(missing.length),
      if (truncated.isNotEmpty) l.filesTruncated(truncated.length),
    ];
    return parts.join(', ');
  }
}

/// Проверяет, что скачанное действительно лежит на диске целиком.
///
/// Хеши кусков BitTorrent сверяет ещё при скачивании — битые данные просто
/// не принимаются. А вот пропавший или обрезанный файл протокол уже не
/// заметит: именно это здесь и ищем.
///
/// Отдельно от движка, потому что к нему не относится: на входе папка и
/// список ожидаемых файлов, на выходе отчёт — ни задач, ни соединений.
class IntegrityCheck {
  const IntegrityCheck._();

  static Future<IntegrityReport> run({
    required String root,
    required List<({String path, int length})> expected,
  }) async {
    final missing = <String>[];
    final truncated = <String>[];

    for (final entry in expected) {
      final file = File(p.join(root, entry.path));
      if (!await file.exists()) {
        missing.add(entry.path);
        continue;
      }
      if (await file.length() < entry.length) truncated.add(entry.path);
    }

    return IntegrityReport(
      checkedFiles: expected.length,
      missing: missing,
      truncated: truncated,
    );
  }
}

import 'dart:io';

import '../../l10n/app_localizations.dart';

/// Показывает папку в системном проводнике.
///
/// Своим классом, а не двумя строками по месту: команда у каждой системы
/// своя, отказ приходит исключением, и подменить его в прогоне иначе
/// нечем — настоящий проводник посреди тестов никому не нужен.
class FileManager {
  FileManager({
    Future<ProcessResult> Function(String, List<String>)? run,
    String? operatingSystem,
  }) : _run = run ?? Process.run,
       _operatingSystem = operatingSystem ?? Platform.operatingSystem;

  final Future<ProcessResult> Function(String, List<String>) _run;
  final String _operatingSystem;

  String get _command => switch (_operatingSystem) {
    'macos' => 'open',
    'windows' => 'explorer',
    _ => 'xdg-open',
  };

  /// Открывает папку. Бросает [FileManagerException], если не вышло.
  Future<void> openFolder(String path) async {
    if (!Directory(path).existsSync()) {
      throw FileManagerException.missing(path);
    }
    try {
      // Код возврата не проверяем: `explorer` отвечает единицей и при
      // успехе, и это известная его особенность, а не наша ошибка.
      await _run(_command, [path]);
    } on ProcessException catch (error) {
      throw FileManagerException.failed(path, error.message);
    }
  }
}

/// Папку показать не вышло — человеку об этом говорят.
///
/// Причиной, а не готовой фразой: языка у сервиса нет, и «папки нет»,
/// написанное по месту, доходило до английского интерфейса по-русски.
/// Слова подбирает блок — [describe].
class FileManagerException implements Exception {
  /// Папки нет: её унесли на другой диск или удалили мимо приложения.
  const FileManagerException.missing(this.path) : error = null;

  /// Проводник не запустился; [error] — что ответила система.
  const FileManagerException.failed(this.path, String this.error);

  final String path;
  final String? error;

  /// Ответ системы показывается как есть: он и так на её языке.
  String describe(L l) => error ?? l.folderNotFound(path);

  @override
  String toString() => 'FileManagerException($path: ${error ?? 'missing'})';
}

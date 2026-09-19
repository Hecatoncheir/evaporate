import 'dart:io';

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
      throw FileManagerException('$path — папки нет');
    }
    try {
      // Код возврата не проверяем: `explorer` отвечает единицей и при
      // успехе, и это известная его особенность, а не наша ошибка.
      await _run(_command, [path]);
    } on ProcessException catch (error) {
      throw FileManagerException(error.message);
    }
  }
}

/// Папку показать не вышло — человеку об этом говорят.
class FileManagerException implements Exception {
  const FileManagerException(this.message);

  final String message;

  @override
  String toString() => message;
}

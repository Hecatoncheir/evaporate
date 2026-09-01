import 'dart:convert';
import 'dart:io';

/// Простое JSON-хранилище с атомарной записью: пишем во временный файл и
/// переименовываем, чтобы падение посреди записи не убило библиотеку.
class JsonStore {
  JsonStore(this.path);

  final String path;

  /// Записи выстраиваются в очередь: два одновременных `write` работали бы
  /// с одним и тем же временным файлом, и второй падал бы на переименовании
  /// уже переименованного файла.
  Future<void> _queue = Future<void>.value();

  Future<Map<String, dynamic>?> read() async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } on FormatException {
      // Битый файл не должен блокировать запуск: уводим в сторону и стартуем с нуля.
      await file.rename(
        '$path.corrupt-${DateTime.now().millisecondsSinceEpoch}',
      );
      return null;
    }
  }

  Future<void> write(Map<String, dynamic> data) {
    final next = _queue.then((_) => _write(data));
    // Ошибка одной записи не должна рвать очередь для следующих.
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    // Уникальное имя: даже если очередь кто-то обойдёт, два писателя не
    // столкнутся на одном временном файле.
    final tmp = File('$path.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      await tmp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
      await tmp.rename(path);
    } on Object {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }
}

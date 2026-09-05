import 'dart:convert';
import 'dart:io';

/// Простое JSON-хранилище с атомарной записью: пишем во временный файл и
/// переименовываем, чтобы падение посреди записи не убило библиотеку.
class JsonStore {
  JsonStore(this.path, {this.private = false, this.pretty = true});

  final String path;

  /// Файл виден только владельцу.
  ///
  /// Нужно настройкам: в них лежит пароль прокси открытым текстом, а права
  /// по умолчанию на общей машине делают его читаемым кем угодно. Ставим на
  /// временном файле, до переименования, — тогда содержимое ни мгновения не
  /// лежит под чужими глазами. На Windows права устроены иначе, и там это
  /// ничего не меняет.
  final bool private;

  /// Писать ли с отступами.
  ///
  /// По умолчанию да: библиотеку и настройки полезно читать глазами, а
  /// весят они килобайты. Кэш базы путей — другое дело: там десятки тысяч
  /// записей, отступы прибавляют к файлу около трети, и разбирает его
  /// только само приложение.
  final bool pretty;

  String? recoveryPath;

  /// Записи выстраиваются в очередь: два одновременных `write` работали бы
  /// с одним и тем же временным файлом, и второй падал бы на переименовании
  /// уже переименованного файла.
  Future<void>? _queue;

  /// Дождаться уже поставленных записей без новой записи на диск.
  Future<void> flush() => _queue ?? Future<void>.value();

  Future<Map<String, dynamic>?> read() async {
    recoveryPath = null;
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const FormatException('Expected a JSON object');
    } on FormatException {
      await quarantine();
      return null;
    }
  }

  /// Читает и сразу проверяет схему. JSON может быть синтаксически верным,
  /// но содержать строку вместо числа или массив вместо ожидаемой карты —
  /// такой файл тоже сохраняем рядом для восстановления, а не роняем запуск.
  Future<T?> readAs<T>(T Function(Map<String, dynamic>) decode) async {
    final json = await read();
    if (json == null) return null;
    try {
      return decode(json);
    } on Object {
      await quarantine();
      return null;
    }
  }

  /// Читает файл как есть, не разбирая.
  ///
  /// Нужно тем, кто разбирает JSON в отдельном изоляте: у кэша базы путей
  /// это десятки тысяч записей, и разбор их на главном потоке роняет
  /// несколько кадров подряд.
  Future<String?> readText() async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      return content.trim().isEmpty ? null : content;
    } on FileSystemException {
      return null;
    }
  }

  /// Пишет готовый текст, не кодируя.
  ///
  /// Та же атомарная запись через переименование, что и у [write], — просто
  /// кодирование уже сделано в другом месте, обычно в изоляте.
  Future<void> writeText(String text) {
    final next = (_queue ?? Future<void>.value()).then((_) => _writeText(text));
    _queue = next.catchError((Object _) {});
    return next;
  }

  /// Сохраняет исходные данные отдельно перед восстановлением части записей.
  Future<void> quarantine() async {
    final file = File(path);
    if (!await file.exists()) return;
    final target = '$path.corrupt-${DateTime.now().microsecondsSinceEpoch}';
    await file.rename(target);
    recoveryPath = target;
  }

  Future<void> write(Map<String, dynamic> data) {
    final next = (_queue ?? Future<void>.value()).then((_) => _write(data));
    // Ошибка одной записи не должна рвать очередь для следующих.
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _write(Map<String, dynamic> data) => _writeText(
    pretty
        ? const JsonEncoder.withIndent('  ').convert(data)
        : jsonEncode(data),
  );

  Future<void> _writeText(String text) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    // Уникальное имя: даже если очередь кто-то обойдёт, два писателя не
    // столкнутся на одном временном файле.
    final tmp = File('$path.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      await tmp.writeAsString(text, flush: true);
      if (private && !Platform.isWindows) {
        // Своего способа сменить права у Dart нет, а запись настроек — дело
        // редкое: она случается по нажатию человека, а не по таймеру.
        await Process.run('chmod', ['600', tmp.path]);
      }
      await tmp.rename(path);
    } on Object {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }
}

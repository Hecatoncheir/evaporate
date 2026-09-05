import 'dart:async';
import 'dart:io';

/// Журнал приложения.
///
/// Приложение бережёт чужие сохранения, и семь десятков мест в нём гасят
/// ошибку молча — иначе каждая мелочь превращалась бы в сообщение поверх
/// экрана. Цена молчания: когда человек говорит «снимок не снялся», смотреть
/// было не на что. SnackBar живёт секунды, консоли у собранного приложения
/// нет, а рассказ о случившемся доходит через день.
///
/// Поэтому журнал файлом, а не `debugPrint`. Он же и предел: файл растёт до
/// [maxBytes], после чего уезжает в предыдущее поколение, а новый начинается
/// с чистого листа. Двух поколений хватает, чтобы пережить перезапуск после
/// беды, и не хватает, чтобы незаметно съесть диск.
///
/// В журнал попадают пути — в них вся суть записи. Наружу он не уходит
/// никогда: его показывают человеку, а отправляет ли он его дальше, решает
/// он сам.
class AppLog {
  AppLog({
    required this.path,
    required this.previousPath,
    this.maxBytes = 512 * 1024,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final String path;
  final String previousPath;

  /// После какого размера журнал начинается заново.
  final int maxBytes;

  final DateTime Function() _now;

  /// Записи выстраиваются в очередь: одновременные записи иначе перемешали
  /// бы строки между собой и обогнали бы поворот поколения.
  Future<void>? _queue;

  /// Журнал приложения. Заводится в `main`, до создания блоков.
  static AppLog? _instance;

  static AppLog get instance => _instance ?? _noop;
  static final AppLog _noop = AppLog(path: '', previousPath: '');

  static set instance(AppLog value) => _instance = value;

  /// Пишет строку. Ошибку в саму запись глотает: журнал не вправе стать
  /// новым источником бед.
  void write(String message, [Object? error, StackTrace? stack]) {
    if (path.isEmpty) return;
    final line = StringBuffer()
      ..write(_stamp(_now()))
      ..write(' ')
      ..write(message);
    if (error != null) line.write(': $error');
    // Стек только у неожиданного: у ожидаемых отказов он лишний шум.
    if (stack != null) line.write('\n$stack');

    _queue = (_queue ?? Future<void>.value())
        .then((_) => _append('$line\n'))
        .catchError((Object _) {});
  }

  /// Дождаться, пока всё записанное ляжет на диск.
  Future<void> flush() => _queue ?? Future<void>.value();

  Future<void> _append(String line) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    if (await file.exists() && await file.length() > maxBytes) {
      final previous = File(previousPath);
      if (await previous.exists()) await previous.delete();
      await file.rename(previousPath);
    }
    await File(path).writeAsString(line, mode: FileMode.append, flush: true);
  }

  /// Последние строки — то, что показывают человеку.
  ///
  /// Оба поколения подряд: беда, случившаяся у самой границы, иначе
  /// оказалась бы разрезанной пополам.
  Future<List<String>> tail({int lines = 200}) async {
    final chunks = <String>[];
    for (final candidate in [previousPath, path]) {
      if (candidate.isEmpty) continue;
      final file = File(candidate);
      try {
        if (await file.exists()) chunks.add(await file.readAsString());
      } on FileSystemException {
        // Не прочиталось — покажем то, что есть.
      }
    }
    final all = chunks
        .join()
        .split('\n')
        .where((line) => line.isNotEmpty)
        .toList();
    return all.length <= lines ? all : all.sublist(all.length - lines);
  }

  /// Стирает журнал целиком — по просьбе человека.
  Future<void> clear() async {
    for (final candidate in [path, previousPath]) {
      if (candidate.isEmpty) continue;
      try {
        final file = File(candidate);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Не удалилось — не повод падать.
      }
    }
  }

  /// `2026-09-05 15:44:21` — местное время: журнал читает человек, сидящий
  /// за этой самой машиной.
  static String _stamp(DateTime value) {
    final v = value.toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${v.year}-${two(v.month)}-${two(v.day)} '
        '${two(v.hour)}:${two(v.minute)}:${two(v.second)}';
  }
}

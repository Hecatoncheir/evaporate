part of 'dtorrent_engine.dart';

/// Файл сессии движка: что качалось, в каком порядке и что стояло на паузе.
///
/// Сам файл остался полем движка — расширение полей не заводит, — а круг
/// «записать и прочитать» собран здесь. Всё это живёт только внутри
/// библиотеки, поэтому расширение приватное.
extension _EngineStore on DtorrentEngine {
  Future<void> _persist() async {
    await _store.write({
      'version': 1,
      'downloads': _ordered.map((d) => d.toJson()).toList(),
    });
  }

  /// Список загрузок переживает перезапуск приложения: своего файла сессии
  /// у библиотеки нет, поэтому ведём его сами.
  Future<void> _restoreState() async {
    final restored = await _store.readAs((json) {
      final entries = json['downloads'] as List<dynamic>? ?? const [];
      return entries
          .map(
            (entry) => _ManagedDownload.fromJson(
              entry as Map<String, dynamic>,
              torrentsDir: torrentsDir,
              onChanged: _persist,
            ),
          )
          .toList();
    });
    for (final managed in restored ?? <_ManagedDownload>[]) {
      _register(managed);
    }
    pumpQueue();
  }
}

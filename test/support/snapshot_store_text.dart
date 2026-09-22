import 'dart:io';

import 'package:evaporate/services/saves/snapshot_store.dart';
import 'package:path/path.dart' as p;

var _written = 0;

/// Положить в хранилище текст — тем же `put`, каким кладёт приложение.
///
/// Через файл, а не байтами из памяти: прежде для этого в самом хранилище
/// жил `putBytes`, которым приложение не пользовалось, — код в `lib` ради
/// одних тестов, да ещё и по пути, которым настоящие снимки не ходят.
extension PutText on SnapshotStore {
  Future<SnapshotBlob> putText(String name, String text) async {
    final source = File(p.join('$root-sources', '${_written++}.src'));
    await source.parent.create(recursive: true);
    await source.writeAsString(text);
    try {
      return await put(name, source);
    } finally {
      await source.delete();
    }
  }
}

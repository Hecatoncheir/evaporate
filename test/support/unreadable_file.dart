import 'dart:io';

/// Делает файл непрочитываемым, не удаляя его, и возвращает, как это снять.
///
/// Файл есть, а прочитать нельзя — так выглядят права, антивирус, держащий
/// файл, сбой диска. На Windows — исключительной блокировкой: блокировки
/// там обязательные, и чтение другим дескриптором отказывает. На остальных
/// системах — правами `000`; под root они чтению не мешают, и такой тест
/// пропускают ([unreadableSkip]).
///
/// Снимать можно сколько угодно раз: блокировка держит файл, и на Windows
/// его не удалить, пока её не снимут, — поэтому снимают и в `finally`.
Future<Future<void> Function()> makeUnreadable(File file) async {
  var released = false;
  if (Platform.isWindows) {
    final handle = await file.open(mode: FileMode.append);
    await handle.lock();
    return () async {
      if (released) return;
      released = true;
      await handle.unlock();
      await handle.close();
    };
  }
  await Process.run('chmod', ['000', file.path]);
  return () async {
    if (released) return;
    released = true;
    await Process.run('chmod', ['644', file.path]);
  };
}

/// Почему непрочитываемый файл здесь не сделать; `null` — сделать можно.
final String? unreadableSkip = _unreadableSkip();

String? _unreadableSkip() {
  if (Platform.isWindows) return null;
  final uid = Process.runSync('id', ['-u']).stdout.toString().trim();
  return uid == '0' ? 'под root права 000 чтению не мешают' : null;
}

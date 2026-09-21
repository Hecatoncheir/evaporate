import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Один экземпляр приложения на одну папку данных.
///
/// Два процесса над одними файлами — это два движка загрузок над одними
/// раздачами, «последний записавший прав» для библиотеки и настроек, а
/// главное — уборка хранилища снимков одного процесса, удаляющая содержимое
/// снимков другого: её защита (`SnapshotStore.guard`) живёт в памяти одного
/// процесса. Сценарий будничный: приложение стартовало с системой свёрнутым
/// в трей, окна не видно, и человек щёлкает ярлык ещё раз.
///
/// Держит замок на файле (`RandomAccessFile.lock`): его снимает сама
/// система, когда процесс гибнет, — зависшего замка после падения не
/// бывает. Второй экземпляр замка не получает, просит первый показать окно
/// и выходит. Просьба идёт через петлевой сокет, порт которого первый
/// кладёт рядом: номер нельзя держать в самом файле замка — на Windows
/// заблокированный файл не прочесть другому процессу.
///
/// Окно второго экземпляра при этом не мелькает: все три раннера
/// показывают его только после первого кадра, а второй выходит раньше.
class SingleInstance {
  SingleInstance._(this._lock, this._server, this._portFile);

  final RandomAccessFile _lock;
  final ServerSocket _server;
  final File _portFile;

  /// Что шлёт второй экземпляр. Всё прочее — не наше, и его не слушаем:
  /// порт на петле открыт любому процессу этой машины.
  static const showRequest = 'evaporate:show';

  static String lockPath(String dataDir) => p.join(dataDir, 'evaporate.lock');

  static String portPath(String dataDir) => p.join(dataDir, 'evaporate.port');

  /// Берёт замок. `null` — приложение уже работает; ему тогда передана
  /// просьба показать окно, и этому процессу остаётся выйти.
  ///
  /// [onShowRequested] зовётся, когда о том же просит следующий экземпляр.
  static Future<SingleInstance?> acquire(
    String dataDir, {
    required void Function() onShowRequested,
  }) async {
    await Directory(dataDir).create(recursive: true);
    final lock = await File(lockPath(dataDir)).open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
    } on FileSystemException {
      await lock.close();
      await _askToShow(dataDir);
      return null;
    }

    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final portFile = File(portPath(dataDir));
    await portFile.writeAsString('${server.port}', flush: true);
    server.listen((client) => unawaited(_serve(client, onShowRequested)));
    return SingleInstance._(lock, server, portFile);
  }

  static Future<void> _serve(Socket client, void Function() onShow) async {
    try {
      final request = await client
          .cast<List<int>>()
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 2));
      if (request.trim() == showRequest) onShow();
    } on Object {
      // Оборванная или чужая просьба — не повод ронять работающий экземпляр.
    } finally {
      client.destroy();
    }
  }

  /// Просит работающий экземпляр показать окно.
  ///
  /// Несколько попыток: первый мог взять замок, но ещё не записать порт —
  /// два щелчка по ярлыку подряд. Не дозвались — всё равно выходим: замок
  /// держит живой процесс, и второй движок над теми же файлами хуже, чем
  /// окно, которое придётся открыть из трея.
  static Future<void> _askToShow(String dataDir) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      if (await _trySend(dataDir)) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  static Future<bool> _trySend(String dataDir) async {
    try {
      final port = int.tryParse(
        (await File(portPath(dataDir)).readAsString()).trim(),
      );
      if (port == null) return false;
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(seconds: 1),
      );
      socket.write(showRequest);
      await socket.flush();
      await socket.close();
      return true;
    } on Object {
      return false;
    }
  }

  /// Отпускает замок. Шаг завершения: система отпустит и сама, но после
  /// обычного выхода файл порта незачем оставлять.
  Future<void> release() async {
    await _server.close();
    try {
      await _portFile.delete();
    } on FileSystemException {
      // Уже нет — и хорошо.
    }
    await _lock.unlock();
    await _lock.close();
  }
}

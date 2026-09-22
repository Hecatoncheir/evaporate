import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/json_store.dart';

/// Дымовой запуск собранного приложения: `evaporate --smoke`.
///
/// Тесты не собирают ни раннеров плагинов, ни движка под систему, ни
/// установщика, и собранное приложение до выкладки не запускалось ни разу:
/// плагин, забывший зарегистрироваться, или бандл, разложенный без
/// симлинков, обнаруживались у человека. Здесь приложение поднимается
/// целиком — окно, трей, блоки, движок загрузок — во временном доме,
/// доживает до первого кадра, пишет файл тем же `JsonStore`, что и
/// настройки с паролем прокси, и завершается штатным путём. Итог — кодом
/// выхода, чтобы CI не читал вывод.
class SmokeRun {
  SmokeRun._(this.home);

  static const flag = '--smoke';

  static bool requested(List<String> args) => args.contains(flag);

  /// Временный дом: данные человека не трогаем, а замок экземпляра в нём
  /// свой — запущенная рядом копия прогону не мешает.
  final Directory home;

  static Future<SmokeRun> prepare() async =>
      SmokeRun._(await Directory.systemTemp.createTemp('evaporate_smoke_'));

  /// Проверки после запуска; возвращает код выхода.
  ///
  /// [shutdown] — тот же проход завершения, что у закрытия окна: он
  /// дописывает отложенные записи и журнал, и его сбой — тоже провал.
  /// Журнал проверяется после него — пустой журнал значил бы, что о
  /// сбоях у человека не узнать.
  Future<int> check({
    required Future<void> firstFrame,
    required Future<void> Function() shutdown,
    required String dataDir,
    required String logFile,
    Duration timeout = const Duration(seconds: 60),
    void Function(String line) report = print,
  }) async {
    try {
      await firstFrame.timeout(timeout);
      report('smoke: первый кадр');

      final store = JsonStore(p.join(dataDir, 'smoke.json'), private: true);
      await store.write({'ok': true});
      if ((await store.read())?['ok'] != true) {
        throw StateError('записанное JsonStore не читается обратно');
      }
      report('smoke: JsonStore');

      await shutdown().timeout(timeout);
      final log = File(logFile);
      if (!await log.exists() || (await log.length()) == 0) {
        throw StateError('журнал пуст: $logFile');
      }
      report('smoke: завершение и журнал');
      return 0;
    } on Object catch (error) {
      report('smoke: провал — $error');
      return 1;
    } finally {
      await _forget();
    }
  }

  Future<void> _forget() async {
    try {
      await home.delete(recursive: true);
    } on FileSystemException {
      // Не убралась — не провал: проверялось приложение, а не уборка, и
      // лежит папка среди временных.
    }
  }
}

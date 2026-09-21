import 'dart:io';

import 'package:evaporate/services/system/single_instance.dart';

/// Держатель замка в отдельном процессе — для `single_instance_test.dart`.
///
/// Отдельный процесс не прихоть: на macOS и Linux замок файла принадлежит
/// процессу, и второй захват из того же процесса проходит. Проверить
/// «второй экземпляр получает отказ» можно только настоящим вторым.
///
/// Пишет `held`, взяв замок, `show` — на каждую просьбу показать окно, и
/// отпускает замок, когда закроют его ввод.
Future<void> main(List<String> args) async {
  final instance = await SingleInstance.acquire(
    args.single,
    onShowRequested: () => stdout.writeln('show'),
  );
  if (instance == null) {
    stdout.writeln('busy');
    return;
  }
  stdout.writeln('held');
  await stdin.drain<void>();
  await instance.release();
}

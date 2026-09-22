// Репетиция обновления: `dart tool/rehearse_update.dart <архив> <папка>`.
//
// Распаковывает архив релиза тем же `UpdateUnpack`, которым его
// распакует приложение у человека, и печатает корень сборки. Дальше CI
// проверяет подпись распакованного бандла и запускает его с `--smoke`.
//
// Проверять надо именно нашей распаковкой, а не `ditto` или `unzip`: бандл
// macOS держится на симлинках внутри фреймворков, и распаковка, их не
// знавшая (такой она и была, пока разбор не нашёл), разложила бы
// обновление, которое не запустится, — а тот же архив, распакованный
// системой, был бы в полном порядке.
import 'dart:io';

import 'package:evaporate/services/system/update_unpack.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('dart tool/rehearse_update.dart <архив> <папка>');
    exitCode = 64;
    return;
  }
  final [archive, work] = args;
  final dir = await Directory(work).create(recursive: true);
  final root = await UpdateUnpack.stage(dir, p.basename(archive), archive);
  stdout.writeln(root);
}

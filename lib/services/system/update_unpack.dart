import 'dart:io';
import 'dart:isolate';

import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'update_exception.dart';

/// Распаковка скачанного обновления.
///
/// Отдельно от загрузки, потому что это другая работа с другими опасностями:
/// архив приехал из сети, и всё здесь — про то, чтобы он не разложил себя
/// мимо отведённой папки.
class UpdateUnpack {
  const UpdateUnpack._();

  /// Распаковывает проверенный архив рядом и отдаёт корень сборки.
  ///
  /// Разбор и распаковка — десятки мегабайт синхронной работы `archive`:
  /// на главном потоке окно замирало бы на секунды посреди полосы хода.
  /// Изолят сам читает файл по пути — гнать его содержимое сообщением
  /// значило бы лишний раз скопировать всё обновление.
  static Future<String> stage(
    Directory dir,
    String name,
    String archivePath,
  ) async {
    final staged = Directory(p.join(dir.path, 'staged'));
    if (await staged.exists()) await staged.delete(recursive: true);
    await staged.create(recursive: true);
    final stagedPath = staged.path;
    await Isolate.run(() => _unpackFile(name, archivePath, stagedPath));
    return _rootOf(staged);
  }

  static Future<void> _unpackFile(
    String name,
    String archivePath,
    String target,
  ) async {
    final archive = _readArchive(name, await File(archivePath).readAsBytes());
    for (final file in archive.files) {
      final destination = _safeDestination(file.name, target);
      // Запись про корень архива: создавать нечего, целевая папка уже есть.
      if (destination == null) continue;
      await _extract(file, destination);
    }
  }

  /// Разбирает скачанное: `.tar.gz` на Linux, zip на остальных.
  static Archive _readArchive(String name, List<int> bytes) {
    final data = Uint8List.fromList(bytes);
    try {
      return name.endsWith('.tar.gz')
          ? TarDecoder().decodeBytes(const GZipDecoder().decodeBytes(data))
          : ZipDecoder().decodeBytes(data);
    } on Object catch (error) {
      throw UpdateException('Архив не читается: $error');
    }
  }

  /// Куда положить одну запись архива. `null` — записи про корень архива:
  /// создавать нечего, целевая папка уже есть.
  ///
  /// Та же мерка, что и у пакетов сохранений: архив приехал из сети, и
  /// выход за пределы папки в нём недопустим.
  static String? _safeDestination(String entryName, String target) {
    final relative = entryName.replaceAll(r'\', '/');
    // Пустые куски пути выходом наружу не являются: так записана обычная
    // папка (`data/flutter_assets/assets/`), так же выглядит и двойной
    // слеш. Отбрасываем их и разбираем то, что осталось, — иначе
    // обновление спотыкалось о первую же папку в архиве.
    final parts = [
      for (final part in relative.split('/'))
        if (part.isNotEmpty) part,
    ];
    if (parts.any((part) => part == '.' || part == '..')) {
      throw UpdateException('Архив просит записать файл наружу: $relative');
    }
    if (parts.isEmpty) return null;

    final destination = p.normalize(p.joinAll([target, ...parts]));
    if (!p.isWithin(target, destination)) {
      throw UpdateException('Архив просит записать файл наружу: $relative');
    }
    return destination;
  }

  /// Кладёт одну запись архива на своё место.
  static Future<void> _extract(ArchiveFile file, String destination) async {
    if (file.isSymbolicLink) {
      await _link(file, destination);
      return;
    }
    if (!file.isFile) {
      await Directory(destination).create(recursive: true);
      return;
    }
    final out = File(destination);
    await out.parent.create(recursive: true);
    final sink = OutputFileStream(destination);
    try {
      file.writeContent(sink);
    } finally {
      await sink.close();
    }
    // Права в zip не переживают распаковку, а запускать после обновления
    // придётся именно эти файлы.
    if (!Platform.isWindows && _looksExecutable(file)) {
      await Process.run('chmod', ['+x', destination]);
    }
  }

  /// Восстанавливает символическую ссылку.
  ///
  /// Бандл macOS без них не запускается: `Versions/Current` и сам бинарник
  /// фреймворка — ссылки, и CI пакует архив `ditto` именно ради них. Ляг
  /// ссылка обычным файлом с путём внутри, приложение не стартовало бы, а
  /// помощник к тому времени уже убрал прежнюю копию.
  ///
  /// Ссылка — такой же способ записать наружу, как `..` в имени: всё, что
  /// потом ляжет «внутрь» неё, ляжет туда, куда она указывает. Поэтому
  /// принимаем только относительные ссылки вниз, без `..`: каждая указывает
  /// в свою же папку или глубже, и цепочка таких ссылок наружу не выводит
  /// ни при каком порядке записей. Проверять по буквам «внутри ли корня»
  /// мало — через уже развёрнутую ссылку на `.` буквальный путь врёт.
  /// Ссылок вверх в бандле нет, и им неоткуда взяться.
  static Future<void> _link(ArchiveFile file, String destination) async {
    final raw = file.symbolicLink!.replaceAll(r'\', '/');
    final target = p.posix.normalize(raw);
    if (p.posix.isAbsolute(raw) || p.posix.split(target).contains('..')) {
      throw UpdateException(
        'Ссылка в архиве указывает наружу: ${file.name} -> $raw',
      );
    }
    await Directory(p.dirname(destination)).create(recursive: true);
    await Link(destination).create(target);
  }

  /// Похож ли файл на тот, которому нужен бит запуска.
  ///
  /// В zip права хранятся в верхних битах внешних атрибутов; там, где их
  /// нет, ориентируемся на расположение — в бандле macOS исполняемое лежит
  /// в `Contents/MacOS`.
  static bool _looksExecutable(ArchiveFile file) {
    final mode = file.mode;
    if (mode != 0 && (mode & 0x49) != 0) return true;
    return file.name.contains('/MacOS/') || !file.name.contains('.');
  }

  /// Папка, которой предстоит заменить установку.
  ///
  /// Архивы собраны по-разному: у macOS внутри лежит `.app`, у остальных —
  /// содержимое папки приложения россыпью. Разбираем по тому, что видим, а
  /// не по системе: так же поступит и человек, распаковавший архив руками.
  static Future<String> _rootOf(Directory staged) async {
    final entries = await staged.list(followLinks: false).toList();
    final bundles = entries.whereType<Directory>().where(
      (dir) => p.extension(dir.path) == '.app',
    );
    if (bundles.isNotEmpty) return bundles.first.path;
    // Единственная папка внутри — это она и есть.
    final dirs = entries.whereType<Directory>().toList();
    if (dirs.length == 1 && entries.length == 1) return dirs.single.path;
    return staged.path;
  }
}

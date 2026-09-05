import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Один файл снимка: имя внутри пакета и содержимое, найденное по хешу.
///
/// [size] — размер исходного файла, не сжатого: он идёт в манифест пакета и
/// должен совпасть с тем, что увидит другое устройство.
class SnapshotBlob {
  const SnapshotBlob({
    required this.name,
    required this.hash,
    required this.size,
  });

  /// Имя внутри `.evsave`: `data/<ruleId>/<путь внутри правила>`.
  final String name;

  /// sha256 содержимого. Он же адрес файла в хранилище.
  final String hash;
  final int size;

  Map<String, dynamic> toJson() => {'name': name, 'hash': hash, 'size': size};

  factory SnapshotBlob.fromJson(Map<String, dynamic> json) => SnapshotBlob(
    name: json['name'] as String,
    hash: json['hash'] as String,
    size: json['size'] as int? ?? 0,
  );
}

/// Файлы снимков, сложенные по содержимому.
///
/// Двадцать снимков одной игры — это двадцать полных копий её сохранений,
/// хотя между соседними меняется обычно один файл: остальное лежало
/// двадцать раз подряд одним и тем же. Здесь содержимое кладётся один раз
/// под именем своего sha256, а снимок хранит только список ссылок.
///
/// Формат `.evsave` от этого не меняется ни на байт. Пакет остаётся
/// самодостаточным zip, потому что его уносят на флешке на другую машину и
/// читают чужие сборки; дедупликация — свойство здешнего хранилища, а не
/// формата. Собрать пакет из ссылок можно в любой момент, обратное неверно.
///
/// Снимки, снятые до появления хранилища, продолжают лежать своими
/// архивами: их не трогаем, а по мере ротации они уходят сами.
class SnapshotStore {
  SnapshotStore({required this.root});

  /// Куда складывать содержимое — `AppPaths.blobsDir`.
  final String root;

  /// Двухбуквенная приставка каталога.
  ///
  /// Десятки тысяч файлов в одной папке — беда для любой файловой системы,
  /// а два первых символа хеша делят их на 256 корзин задаром.
  String pathFor(String hash) => p.join(root, hash.substring(0, 2), hash);

  File fileFor(String hash) => File(pathFor(hash));

  /// Кладёт файл в хранилище и возвращает ссылку на него.
  ///
  /// Хеш считается по исходному содержимому, а лежит оно сжатым: адресация
  /// по содержимому и упаковка — вещи независимые, и мерить хеш по сжатому
  /// значило бы привязать адрес к версии упаковщика.
  ///
  /// Сжатие здесь не роскошь, а возврат долга: раньше снимок лежал zip-ом,
  /// и без упаковки хранилище проиграло бы старому способу на тех, кто
  /// держит один-два снимка. На правдоподобных сейвах это ещё два-три раза
  /// поверх дедупликации.
  ///
  /// Уже лежащее не переписываем: содержимое найдено по хешу, значит, оно
  /// такое же. Пишем через временный файл и переименование — оборванная на
  /// середине запись не должна оставить под правильным именем половину
  /// файла, которую потом никто не отличит от целого.
  Future<SnapshotBlob> put(String name, File source) async {
    final digest = await sha256.bind(source.openRead()).first;
    final hash = digest.toString();
    final size = await source.length();
    final target = fileFor(hash);

    if (!await target.exists()) {
      await _write(target, () => source.openRead());
    }
    return SnapshotBlob(name: name, hash: hash, size: size);
  }

  /// Кладёт готовое содержимое, уже прочитанное в память.
  Future<SnapshotBlob> putBytes(String name, List<int> bytes) async {
    final hash = sha256.convert(bytes).toString();
    final target = fileFor(hash);
    if (!await target.exists()) {
      await _write(target, () => Stream<List<int>>.value(bytes));
    }
    return SnapshotBlob(name: name, hash: hash, size: bytes.length);
  }

  Future<void> _write(File target, Stream<List<int>> Function() open) async {
    await target.parent.create(recursive: true);
    final tmp = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await open().transform(gzip.encoder).pipe(tmp.openWrite());
      await tmp.rename(target.path);
    } on Object {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }

  /// Распаковывает содержимое в отдельный файл.
  ///
  /// Нужно при сборке пакета: `.evsave` — обычный zip, и упаковщику нужен
  /// настоящий файл, а не наше сжатое представление.
  Future<void> extractTo(String hash, String destination) async {
    final source = fileFor(hash);
    if (!await source.exists()) {
      throw FileSystemException('Содержимое снимка не найдено', source.path);
    }
    final target = File(destination);
    await target.parent.create(recursive: true);
    await source.openRead().transform(gzip.decoder).pipe(target.openWrite());
  }

  /// Убирает содержимое, на которое больше никто не ссылается.
  ///
  /// Разметка и обход, а не счётчик ссылок: счётчик врёт после любого сбоя
  /// посреди операции, а живой список снимков и так известен библиотеке
  /// целиком. Возвращает, сколько байт освободилось, — это единственный
  /// способ показать человеку, что уборка вообще что-то дала.
  Future<int> collect(Set<String> alive) async {
    final dir = Directory(root);
    if (!await dir.exists()) return 0;

    var freed = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      // Временные файлы чужой оборвавшейся записи убираем заодно.
      final orphanTemp = name.endsWith('.tmp');
      if (!orphanTemp && alive.contains(name)) continue;
      try {
        freed += await entity.length();
        await entity.delete();
      } on FileSystemException {
        // Файл мог исчезнуть сам — уборка не повод падать.
      }
    }
    return freed;
  }
}

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
  SnapshotStore({
    required this.root,
    Stream<FileSystemEntity> Function(Directory dir)? listFiles,
  }) : _listFiles = listFiles ?? _listRecursive;

  /// Куда складывать содержимое — `AppPaths.blobsDir`.
  final String root;

  /// Обход хранилища при уборке. Подменяется в тестах: гонку уборки с
  /// работой иначе не поставить точно — порядок обхода папки не задан.
  final Stream<FileSystemEntity> Function(Directory dir) _listFiles;

  static Stream<FileSystemEntity> _listRecursive(Directory dir) =>
      dir.list(recursive: true, followLinks: false);

  /// Сколько работ идёт сейчас.
  var _busy = 0;

  /// Сколько работ начиналось за всё время.
  ///
  /// Одного [_busy] уборке мало: работа, начавшаяся и закончившаяся, пока
  /// уборка шла по диску, возвращает его к нулю, а список живых у уборки
  /// остаётся прежним — и свежее содержимое выглядит бесхозным. Смена эпохи
  /// говорит «список устарел», даже когда работа уже кончилась. Прежде это
  /// пытались закрыть списком записанного работой, но его сбрасывал конец
  /// работы — ровно в тот промежуток, где он и был нужен.
  var _epoch = 0;

  /// Удаления, которые уборка ведёт прямо сейчас.
  ///
  /// Проверить наличие файла и решить «он на месте, писать не нужно» можно,
  /// пока удаление уже отдано системе: проверка ответит «есть», а через
  /// мгновение его не станет. Кладущий дожидается удалений и только потом
  /// спрашивает. Множество, а не одно: две уборки могут идти разом.
  final _deletions = <Future<void>>{};

  /// Работа, во время которой уборка не вправе трогать записанное.
  ///
  /// Снимок становится живым не тогда, когда его файлы легли на диск, а
  /// когда библиотека занесёт его в состояние. Между этими мгновениями
  /// проходит ещё и запись остальных файлов снимка, а при восстановлении —
  /// заливка сейвов из пакета: минуты, в которые ссылок на свежее
  /// содержимое нет ни у кого. Уборка, запущенная в этот промежуток,
  /// честно сочла бы его мусором и унесла — а снимок остался бы в
  /// библиотеке с правильным числом файлов и размером, но нечитаемым.
  /// Узнают об этом, когда он понадобится, то есть в худший момент.
  ///
  /// Промежуток этот не выдуманный: Bloc обрабатывает события параллельно,
  /// и `SnapshotDeleted` от соседней игры спокойно приходит посреди
  /// автоснимка после выхода.
  ///
  /// Времени тут не место: по возрасту файла «библиотека ещё не успела о
  /// нём узнать» не отличить от «библиотека знает, и он больше не нужен».
  /// Знает об этом только тот, кто работу ведёт, — он и отмечается.
  Future<T> guard<T>(Future<T> Function() body) async {
    _epoch++;
    _busy++;
    try {
      return await body();
    } finally {
      _busy--;
    }
  }

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
  ///
  /// Файл читается дважды — сначала ради хеша, и только если такого
  /// содержимого ещё нет, ради записи: неизменившийся сейв, а их в снимке
  /// большинство, так и не сжимается зря. Но между чтениями игра могла
  /// дописать файл, поэтому записанное адресуется хешем **второго** чтения,
  /// посчитанным по тем же байтам, что легли на диск. Иначе под хешем
  /// лежало бы чужое содержимое, и ничто бы этого не поймало.
  Future<SnapshotBlob> put(String name, File source) async {
    final seen = await _hashOf(source.openRead());
    if (await _isKept(seen.hash)) {
      return SnapshotBlob(name: name, hash: seen.hash, size: seen.size);
    }
    final written = await _writeHashed(source.openRead());
    return SnapshotBlob(name: name, hash: written.hash, size: written.size);
  }

  /// Кладёт готовое содержимое, уже прочитанное в память.
  Future<SnapshotBlob> putBytes(String name, List<int> bytes) async {
    final hash = sha256.convert(bytes).toString();
    if (!await _isKept(hash)) {
      await _writeHashed(Stream<List<int>>.value(bytes));
    }
    return SnapshotBlob(name: name, hash: hash, size: bytes.length);
  }

  /// Лежит ли уже такое содержимое.
  ///
  /// Уже лежавшее нуждается в защите не меньше нового: уборка, унёсшая его
  /// между проверкой и возвратом, оставила бы снимок со ссылкой в пустоту,
  /// а писать его заново никто не стал бы — он ведь был на месте. От этого
  /// защищает [guard], начатый до проверки: он меняет эпоху, и уборка
  /// обрывается, не дойдя до следующего удаления. А начатое до смены —
  /// дожидаемся здесь.
  Future<bool> _isKept(String hash) async {
    // Исход удаления не важен — важно, что оно кончилось.
    await Future.wait([
      for (final deletion in _deletions)
        deletion.then((_) {}, onError: (Object _) {}),
    ]);
    return fileFor(hash).exists();
  }

  /// Пишет поток сжатым во временный файл, считая хеш по тем же байтам, и
  /// кладёт под этим хешем.
  Future<({String hash, int size})> _writeHashed(
    Stream<List<int>> content,
  ) async {
    await Directory(root).create(recursive: true);
    final tmp = File(
      p.join(root, '${DateTime.now().microsecondsSinceEpoch}.tmp'),
    );
    try {
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      var size = 0;
      await content
          .map((chunk) {
            hasher.add(chunk);
            size += chunk.length;
            return chunk;
          })
          .transform(gzip.encoder)
          .pipe(tmp.openWrite());
      hasher.close();
      final hash = digest.value.toString();

      if (await _isKept(hash)) {
        await tmp.delete();
      } else {
        final target = fileFor(hash);
        await target.parent.create(recursive: true);
        await tmp.rename(target.path);
      }
      return (hash: hash, size: size);
    } on Object {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }

  static Future<({String hash, int size})> _hashOf(
    Stream<List<int>> content,
  ) async {
    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    var size = 0;
    await for (final chunk in content) {
      hasher.add(chunk);
      size += chunk.length;
    }
    hasher.close();
    return (hash: digest.value.toString(), size: size);
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
  /// целиком. Возвращает, сколько байт освободилось: наружу это не
  /// показывают — место и так видно на экране сохранений, — но библиотека
  /// кладёт непустой итог в журнал. «Куда делись гигабайты» спрашивают
  /// через неделю, и ответ к тому времени должен где-то лежать.
  Future<int> collect(Set<String> alive) async {
    // Пока идёт работа со снимками, уборка не начинается вовсе. Список
    // живых ссылок ей собрали до того, как работа закончится, и он заведомо
    // неполон: обход идёт не мгновенно, работа может закончиться на его
    // середине, и дальше мы шагали бы по файлам уже с устаревшим списком.
    // Отказаться дешевле, чем угадывать: уборок будет ещё много, а
    // унесённое содержимое снимка не вернуть.
    if (_busy > 0) return 0;
    // По той же причине уборка обрывается, едва начнётся новая работа, — и
    // тогда, когда та успела закончиться, пока мы шли по диску: список
    // живых собран до неё и её содержимого не знает.
    final epoch = _epoch;

    final dir = Directory(root);
    if (!await dir.exists()) return 0;

    var freed = 0;
    await for (final entity in _listFiles(dir)) {
      if (_epoch != epoch) break;
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      // Временные файлы чужой оборвавшейся записи убираем заодно: начнись
      // запись посреди обхода, эпоха бы сменилась.
      if (!name.endsWith('.tmp') && alive.contains(name)) continue;
      try {
        // Размер засчитываем после удаления, а не до: занятый файл удалить
        // не выйдет, и отчёт о сотнях освобождённых мегабайт, которых на
        // диске не прибавилось, — это ложь в единственном числе, которое
        // человек отсюда и увидит.
        final size = await entity.length();
        // Проверка — вплотную к удалению: ожидание выше тоже промежуток.
        if (_epoch != epoch) break;
        final deleting = entity.delete();
        _deletions.add(deleting);
        try {
          await deleting;
        } finally {
          _deletions.remove(deleting);
        }
        freed += size;
      } on FileSystemException {
        // Файл мог исчезнуть сам — уборка не повод падать.
      }
    }
    return freed;
  }
}

/// Приёмник единственного хеша от потокового `sha256`.
class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

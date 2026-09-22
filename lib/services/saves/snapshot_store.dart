import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../l10n/app_localizations.dart';
import '../../models/snapshot_blob.dart';
import 'offload.dart';
import 'restore_transaction.dart';
import 'save_exception.dart';

// Часть снимка, а не хранилища: её читают и модели, и пакет `.evsave`.
export '../../models/snapshot_blob.dart';

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
    String? trash,
    this.trashKeep = defaultTrashKeep,
    DateTime Function()? clock,
    Stream<FileSystemEntity> Function(Directory dir)? listFiles,
    Offload? offload,
  }) : trash = trash ?? p.join(p.dirname(root), '${p.basename(root)}-trash'),
       _clock = clock ?? DateTime.now,
       _listFiles = listFiles ?? _listRecursive,
       _offload = offload ?? runInIsolate;

  /// Куда складывать содержимое — `AppPaths.blobsDir`.
  final String root;

  /// Куда уборка выносит бесхозное содержимое, прежде чем удалить.
  ///
  /// Второй рубеж, а не корзина для человека. Уборка верит списку живых
  /// снимков, а список бывал неполным так, как никто не предусмотрел: однажды
  /// испорченный файл списка отдал ей содержимое всех снимков разом. Лежащее
  /// здесь возвращается само, стоит снимку на него сослаться, — при
  /// раскладке или при следующем снимке того же содержимого. Рядом с
  /// хранилищем, а не внутри: обход хранилища сюда не заходит.
  final String trash;

  /// Сколько вынесенное лежит, прежде чем удалиться насовсем.
  final Duration trashKeep;

  static const defaultTrashKeep = Duration(days: 14);

  final DateTime Function() _clock;

  /// Обход хранилища при уборке. Подменяется в тестах: гонку уборки с
  /// работой иначе не поставить точно — порядок обхода папки не задан.
  final Stream<FileSystemEntity> Function(Directory dir) _listFiles;

  static Stream<FileSystemEntity> _listRecursive(Directory dir) =>
      dir.list(recursive: true, followLinks: false);

  /// Где хешировать и сжимать крупное — см. [Offload].
  final Offload _offload;

  /// Выполняет работу с байтами файла на месте или в изоляте — по размеру.
  ///
  /// Сама работа собирается статикой ([_hashJob] и соседи), а не
  /// замыканием в методе: такое замыкание несёт с собой `this`, а
  /// хранилище с его очередями и таймерами в изолят не пересылается.
  Future<R> _heavy<R>(int size, FutureOr<R> Function() job) async =>
      size >= offloadFromBytes ? _offload(job) : job();

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

  /// Есть ли такое содержимое — на месте или вынесенным уборкой.
  ///
  /// Вынесенное при этом возвращается на место: раз на него сослались, оно
  /// живое, и список, отдавший его уборке, ошибся.
  Future<bool> contains(String hash) async =>
      await _isWhole(fileFor(hash)) || await _revive(hash);

  /// Лежит ли под именем хоть что-то.
  ///
  /// Пустой файл под хешем — след оборванной записи, а не содержимое:
  /// сжатое пустое и то весит два десятка байт. Считать его лежащим
  /// значило бы на каждом следующем снимке отвечать «уже лежит» и так и
  /// не записать настоящее.
  static Future<bool> _isWhole(File file) async {
    try {
      return await file.length() > 0;
    } on FileSystemException {
      return false;
    }
  }

  /// Убирает содержимое, которое не развернулось.
  ///
  /// Обрезанный gzip по имени и длине от целого не отличить — ловит его
  /// только раскладка. Тогда он уходит, чтобы следующий снимок того же
  /// содержимого его переписал, а не ответил «уже лежит».
  Future<void> discard(String hash) async {
    try {
      await fileFor(hash).delete();
    } on FileSystemException {
      // Уже нет — и хорошо.
    }
  }

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
  ///
  /// Крупный файл хешируется и сжимается в отдельном изоляте ([Offload]).
  Future<SnapshotBlob> put(String name, File source) async {
    final size = await source.length();
    // Мелкое читается на месте и через сам [source]: изолят получает только
    // путь, а мелкому он не нужен.
    final offload = size >= offloadFromBytes;
    final seen = await (offload
        ? _offload(_hashJob(source.path))
        : _hashOf(source.openRead()));
    if (await _isKept(seen.hash)) {
      return SnapshotBlob(name: name, hash: seen.hash, size: seen.size);
    }
    final written = await _writeHashed(
      (tmp) => offload
          ? _offload(_compressJob(source.path, tmp))
          : _compressTo(source.openRead(), tmp),
    );
    return SnapshotBlob(name: name, hash: written.hash, size: written.size);
  }

  /// Кладёт готовое содержимое, уже прочитанное в память.
  Future<SnapshotBlob> putBytes(String name, List<int> bytes) async {
    final hash = sha256.convert(bytes).toString();
    if (!await _isKept(hash)) {
      await _writeHashed(
        (tmp) => _compressTo(Stream<List<int>>.value(bytes), tmp),
      );
    }
    return SnapshotBlob(name: name, hash: hash, size: bytes.length);
  }

  static Future<_Hashed> Function() _hashJob(String path) =>
      () => _hashOf(File(path).openRead());

  static Future<_Hashed> Function() _compressJob(String source, String tmp) =>
      () => _compressTo(File(source).openRead(), tmp);

  static Future<void> Function() _gunzipJob(String source, String target) =>
      () =>
          File(source)
              .openRead()
              .transform(gzip.decoder)
              .pipe(File(target).openWrite());

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
    if (await _isWhole(fileFor(hash))) return true;
    return _revive(hash);
  }

  File _trashed(String hash) => File(p.join(trash, hash));

  /// Возвращает вынесенное уборкой, если оно ещё лежит.
  Future<bool> _revive(String hash) async {
    final trashed = _trashed(hash);
    if (!await trashed.exists()) return false;
    final target = fileFor(hash);
    await target.parent.create(recursive: true);
    try {
      await trashed.rename(target.path);
    } on FileSystemException {
      // Вернул кто-то другой — или вернуть нельзя; смотрим, что вышло.
    }
    return target.exists();
  }

  /// Пишет сжатое во временный файл и кладёт под хешем, который посчитал
  /// [compress] по тем же байтам.
  Future<_Hashed> _writeHashed(
    Future<_Hashed> Function(String tmp) compress,
  ) async {
    await Directory(root).create(recursive: true);
    // `uuid`, а не часы: у двух одновременных записей на Windows время
    // совпадает, и вторая писала бы в чужой временный файл.
    final tmp = File(p.join(root, '${_uuid.v4()}.tmp'));
    try {
      final written = await compress(tmp.path);
      if (await _isKept(written.hash)) {
        await tmp.delete();
      } else {
        final target = fileFor(written.hash);
        await target.parent.create(recursive: true);
        // Под именем мог остаться пустой след оборванной записи.
        if (await target.exists()) await target.delete();
        await tmp.rename(target.path);
      }
      return written;
    } on Object {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }

  static const _uuid = Uuid();

  /// Сжимает поток в [tmp], считая хеш по тем же байтам, и сбрасывает
  /// записанное на диск. Статикой: идёт и в изоляте.
  static Future<_Hashed> _compressTo(
    Stream<List<int>> content,
    String tmp,
  ) async {
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
        .pipe(File(tmp).openWrite());
    await _syncToDisk(File(tmp));
    hasher.close();
    return (hash: digest.value.toString(), size: size);
  }

  /// Сбрасывает записанное на диск до переименования.
  ///
  /// Закрытый поток отдаёт байты системе, но не диску: после обрыва питания
  /// под верным хешем лежал бы пустой или обрезанный файл — индекс-то,
  /// список снимков, на диск сбрасывается (`JsonStore`).
  static Future<void> _syncToDisk(File file) async {
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  static Future<_Hashed> _hashOf(Stream<List<int>> content) async {
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
  /// настоящий файл, а не наше сжатое представление. [size] — длина
  /// развёрнутого, если она известна: по ней решается, стоит ли
  /// распаковка изолята.
  Future<void> extractTo(String hash, String destination, {int? size}) async {
    final source = fileFor(hash);
    if (!await _isWhole(source) && !await _revive(hash)) {
      throw FileSystemException('Содержимое снимка не найдено', source.path);
    }
    await File(destination).parent.create(recursive: true);
    await _heavy(
      size ?? await source.length(),
      _gunzipJob(source.path, destination),
    );
  }

  /// Убирает содержимое, на которое больше никто не ссылается.
  ///
  /// Разметка и обход, а не счётчик ссылок: счётчик врёт после любого сбоя
  /// посреди операции, а живой список снимков и так известен библиотеке
  /// целиком.
  ///
  /// Бесхозное не удаляется, а выносится в [trash] и удаляется оттуда
  /// через [trashKeep]. Сколько вынесено и сколько удалено насовсем,
  /// возвращается: наружу это не показывают — место и так видно на экране
  /// сохранений, — но библиотека кладёт непустой итог в журнал. «Куда
  /// делись гигабайты» спрашивают через неделю, и ответ к тому времени
  /// должен где-то лежать.
  Future<StoreCleanup> collect(Set<String> alive) async {
    // Пока идёт работа со снимками, уборка не начинается вовсе. Список
    // живых ссылок ей собрали до того, как работа закончится, и он заведомо
    // неполон: обход идёт не мгновенно, работа может закончиться на его
    // середине, и дальше мы шагали бы по файлам уже с устаревшим списком.
    // Отказаться дешевле, чем угадывать: уборок будет ещё много, а
    // унесённое содержимое снимка не вернуть.
    if (_busy > 0) return (moved: 0, purged: 0);
    // По той же причине уборка обрывается, едва начнётся новая работа, — и
    // тогда, когда та успела закончиться, пока мы шли по диску: список
    // живых собран до неё и её содержимого не знает.
    final epoch = _epoch;
    final moved = await _sweep(alive, epoch);
    final purged = await _purgeTrash(epoch);
    return (moved: moved, purged: purged);
  }

  /// Выносит из хранилища всё, чего нет в [alive].
  Future<int> _sweep(Set<String> alive, int epoch) async {
    final dir = Directory(root);
    if (!await dir.exists()) return 0;

    var moved = 0;
    await for (final entity in _listFiles(dir)) {
      if (_epoch != epoch) break;
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      // Временные файлы чужой оборвавшейся записи убираем заодно и сразу
      // насовсем: начнись запись посреди обхода, эпоха бы сменилась.
      final temporary = name.endsWith('.tmp');
      if (!temporary && alive.contains(name)) continue;
      final size = await _discard(entity, epoch, toTrash: !temporary);
      if (size == null) break;
      moved += size;
    }
    return moved;
  }

  /// Удаляет насовсем то, что пролежало вынесенным дольше [trashKeep].
  Future<int> _purgeTrash(int epoch) async {
    final dir = Directory(trash);
    if (!await dir.exists()) return 0;

    final cutoff = _clock().subtract(trashKeep);
    var purged = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (_epoch != epoch) break;
      if (entity is! File || !await _olderThan(entity, cutoff)) continue;
      final size = await _discard(entity, epoch, toTrash: false);
      if (size == null) break;
      purged += size;
    }
    return purged;
  }

  static Future<bool> _olderThan(File file, DateTime cutoff) async {
    try {
      return (await file.lastModified()).isBefore(cutoff);
    } on FileSystemException {
      return false;
    }
  }

  /// Выносит или удаляет один файл; `null` — уборку пора обрывать.
  Future<int?> _discard(File file, int epoch, {required bool toTrash}) async {
    try {
      // Размер засчитываем после удаления, а не до: занятый файл удалить
      // не выйдет, и отчёт о сотнях освобождённых мегабайт, которых на
      // диске не прибавилось, — это ложь в единственном числе, которое
      // человек отсюда и увидит.
      final size = await file.length();
      // Проверка — вплотную к удалению: ожидание выше тоже промежуток.
      if (_epoch != epoch) return null;
      final Future<void> removing = toTrash
          ? _moveToTrash(file)
          : file.delete();
      _deletions.add(removing);
      try {
        await removing;
      } finally {
        _deletions.remove(removing);
      }
      return size;
    } on FileSystemException {
      // Файл мог исчезнуть сам — уборка не повод падать.
      return 0;
    }
  }

  Future<void> _moveToTrash(File file) async {
    await Directory(trash).create(recursive: true);
    final moved = await file.rename(p.join(trash, p.basename(file.path)));
    // Срок считается от выноса, а не от записи: переименование времени не
    // меняет, и содержимое, лежавшее год, ушло бы насовсем в тот же миг.
    try {
      await moved.setLastModified(_clock());
    } on FileSystemException {
      // Не вышло — уйдёт раньше срока; снимку, который на него сошлётся,
      // от этого не хуже, чем было до корзины.
    }
  }
}

/// Итог уборки: сколько байт вынесено из хранилища и сколько удалено
/// насовсем из вынесенного раньше.
typedef StoreCleanup = ({int moved, int purged});

/// Приёмник единственного хеша от потокового `sha256`.
class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Файл снимка, лежащий в хранилище по содержимому.
///
/// Сжатое представление разворачивается прямо в цель: временный пакет для
/// этого не нужен, а вот проверка нужна — гигабайт, оборвавшийся на
/// середине, выглядит как обычный файл.
class StoredBlobSource implements RestoreSource {
  StoredBlobSource(
    this._blob, {
    required this._store,
    required this._localizations,
  });

  final SnapshotBlob _blob;
  final SnapshotStore _store;
  final L Function() _localizations;

  L get _l => _localizations();

  @override
  String get name => _blob.name;

  @override
  int get size => _blob.size;

  /// Не развернулось — содержимое убирается из хранилища ([SnapshotStore.discard]):
  /// следующий снимок того же сейва его перепишет, а не ответит «уже
  /// лежит». Отказ при этом приходит словами, а не сырым исключением
  /// разборщика gzip.
  @override
  Future<void> writeTo(String path) async {
    try {
      await _store.extractTo(_blob.hash, path, size: _blob.size);
      if (await File(path).length() == _blob.size) return;
    } on SaveException {
      rethrow;
    } on Object {
      // Обрезанный gzip — `FormatException` или ошибка ввода-вывода.
    }
    await _store.discard(_blob.hash);
    throw SaveException(_l.saveArchiveReadFailed(_blob.name));
  }
}

/// Хеш содержимого и его длина до сжатия.
typedef _Hashed = ({String hash, int size});

import 'dart:io';

import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/download/torrent_export.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Скачанную раздачу человек вправе унести с собой: в другой клиент, на
/// другое устройство, в архив. Файл при этом лежит в разных местах, и
/// поиск обязан находить его во всех.
void main() {
  late Directory tmp;
  late String torrentsDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_torrent_');
    torrentsDir = p.join(tmp.path, 'torrents');
    await Directory(torrentsDir).create(recursive: true);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<String> writeTorrent(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('d4:infod4:name4:gameee');
    return path;
  }

  Game game({
    String id = 'game-1',
    GameSource? source,
    String? downloadTaskId,
    String? infoHash,
  }) => Game(
    id: id,
    title: 'Игра',
    addedAt: DateTime(2026),
    source: source,
    downloadTaskId: downloadTaskId,
    infoHash: infoHash,
  );

  TorrentExport search({String? Function(String id)? engine}) => TorrentExport(
    torrentsDir: torrentsDir,
    enginePath: engine ?? (_) => null,
  );

  group('поиск файла раздачи', () {
    test(
      'копия, снятая при добавлении, находится по идентификатору игры',
      () async {
        final copy = await writeTorrent(p.join(torrentsDir, 'game-1.torrent'));

        final found = await search().locate(
          game(
            source: const GameSource(
              kind: GameSourceKind.torrentFile,
              value: '/уже/удалённый.torrent',
            ),
          ),
        );

        expect(found, copy);
      },
    );

    // Magnet-ссылка своего файла не приносит: он появляется только после
    // метаданных, и знает о нём движок.
    test('для magnet-ссылки файл берётся у движка', () async {
      final built = await writeTorrent(
        p.join(tmp.path, 'из-метаданных.torrent'),
      );

      final found = await search(engine: (id) => id == 'hash-1' ? built : null)
          .locate(
            game(
              source: const GameSource(
                kind: GameSourceKind.magnet,
                value: 'magnet:?x',
              ),
              infoHash: 'hash-1',
            ),
          );

      expect(found, built);
    });

    // Идентификатор задачи живёт только до перезапуска приложения, infohash —
    // всегда. Спрашиваем по обоим, иначе после перезапуска экспорт исчез бы.
    test('до перезапуска годится и идентификатор задачи', () async {
      final built = await writeTorrent(p.join(tmp.path, 'задача.torrent'));

      final found = await search(engine: (id) => id == 'task-7' ? built : null)
          .locate(
            game(
              source: const GameSource(
                kind: GameSourceKind.magnet,
                value: 'magnet:?x',
              ),
              downloadTaskId: 'task-7',
            ),
          );

      expect(found, built);
    });

    // Последняя надежда — файл, который пользователь когда-то выбрал сам.
    // Он живёт вне приложения, поэтому и спрашивается последним.
    test('исходный .torrent пользователя годится, пока он на месте', () async {
      final original = await writeTorrent(
        p.join(tmp.path, 'скачанное.torrent'),
      );

      final found = await search().locate(
        game(
          source: GameSource(kind: GameSourceKind.torrentFile, value: original),
        ),
      );

      expect(found, original);
    });

    test(
      'обещанный движком файл, которого нет на диске, не подходит',
      () async {
        final found =
            await search(engine: (_) => p.join(tmp.path, 'нет.torrent')).locate(
              game(
                source: const GameSource(
                  kind: GameSourceKind.magnet,
                  value: 'magnet:?x',
                ),
                infoHash: 'hash-1',
              ),
            );

        expect(found, isNull);
      },
    );

    test('пока метаданные не пришли, отдавать нечего', () async {
      final found = await search().locate(
        game(
          source: const GameSource(
            kind: GameSourceKind.magnet,
            value: 'magnet:?x',
          ),
          infoHash: 'hash-1',
        ),
      );

      expect(found, isNull);
    });
  });

  group('кому предлагать экспорт', () {
    test('раздача — magnet-ссылка и .torrent', () {
      expect(
        TorrentExport.isTorrent(
          game(
            source: const GameSource(
              kind: GameSourceKind.magnet,
              value: 'magnet:?x',
            ),
          ),
        ),
        isTrue,
      );
      expect(
        TorrentExport.isTorrent(
          game(
            source: const GameSource(
              kind: GameSourceKind.torrentFile,
              value: 'a.torrent',
            ),
          ),
        ),
        isTrue,
      );
    });

    // У игры из локальной папки раздачи нет и быть не может — кнопке в
    // карточке взяться неоткуда.
    test('локальная папка и игра без источника раздачей не считаются', () {
      expect(
        TorrentExport.isTorrent(
          game(
            source: const GameSource(
              kind: GameSourceKind.localFolder,
              value: '/games/Игра',
            ),
          ),
        ),
        isFalse,
      );
      expect(TorrentExport.isTorrent(game()), isFalse);
    });
  });
}

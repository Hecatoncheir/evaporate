import 'dart:io';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' as dt;
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/proxy_settings.dart';
import 'package:evaporate/services/download/download_engine.dart';
import 'package:evaporate/services/download/dtorrent_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_engine_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Движок без автозапуска: очередь и состояние проверяются без сети.
  DtorrentEngine buildEngine({
    ProxySettings proxy = const ProxySettings(),
    int maxConcurrent = 3,
  }) {
    return DtorrentEngine(
      downloadDir: p.join(tmp.path, 'games'),
      stateFile: p.join(tmp.path, 'downloads.json'),
      proxy: proxy,
      maxConcurrent: maxConcurrent,
      autoStart: false,
    );
  }

  /// Валидная magnet-ссылка с 40-символьным hex-infohash.
  String magnet(String hash, {String name = 'Раздача'}) =>
      'magnet:?xt=urn:btih:$hash&dn=$name';

  const hashA = 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678';
  const hashB = '00112233445566778899aabbccddeeff00112233';
  const hashC = 'ffeeddccbbaa99887766554433221100ffeeddcc';

  group('прокси', () {
    test('выключенный прокси не даёт конфигурации', () {
      final engine = buildEngine();
      expect(engine.buildProxyConfig(), isNull);
      engine.dispose();
    });

    test('незаполненный хост не считается настроенным', () {
      final engine = buildEngine(
        proxy: const ProxySettings(enabled: true, host: '  '),
      );
      expect(engine.buildProxyConfig(), isNull);
      engine.dispose();
    });

    test('SOCKS5 проксирует и пиров — ради этого движок и менялся', () {
      final engine = buildEngine(
        proxy: const ProxySettings(
          enabled: true,
          kind: ProxyKind.socks5,
          host: '127.0.0.1',
          port: 9050,
        ),
      );

      final config = engine.buildProxyConfig()!;

      expect(config.type, dt.ProxyType.socks5);
      expect(config.host, '127.0.0.1');
      expect(config.port, 9050);
      expect(config.useForPeers, isTrue);
      expect(config.useForTrackers, isTrue);
      engine.dispose();
    });

    test('HTTP-прокси не покрывает пиров', () {
      final engine = buildEngine(
        proxy: const ProxySettings(
          enabled: true,
          kind: ProxyKind.http,
          host: 'proxy.local',
          port: 8080,
        ),
      );

      final config = engine.buildProxyConfig()!;

      expect(config.type, dt.ProxyType.http);
      expect(
        config.useForPeers,
        isFalse,
        reason: 'HTTP-прокси в BitTorrent покрывает только трекеры',
      );
      engine.dispose();
    });

    test('схема в адресе не ломает конфигурацию', () {
      final engine = buildEngine(
        proxy: const ProxySettings(
          enabled: true,
          host: 'socks5://10.0.0.1',
          port: 1080,
        ),
      );

      expect(engine.buildProxyConfig()!.host, '10.0.0.1');
      engine.dispose();
    });

    test('учётные данные пробрасываются, пустые — нет', () {
      final withAuth = buildEngine(
        proxy: const ProxySettings(
          enabled: true,
          host: 'h',
          port: 1,
          username: 'user',
          password: 'secret',
        ),
      );
      final withoutAuth = buildEngine(
        proxy: const ProxySettings(enabled: true, host: 'h', port: 1),
      );

      expect(withAuth.buildProxyConfig()!.username, 'user');
      expect(withAuth.buildProxyConfig()!.password, 'secret');
      expect(withoutAuth.buildProxyConfig()!.username, isNull);
      expect(withoutAuth.buildProxyConfig()!.password, isNull);
      withAuth.dispose();
      withoutAuth.dispose();
    });
  });

  group('очередь', () {
    test('одновременно стартует не больше разрешённого', () async {
      final engine = buildEngine(maxConcurrent: 2);

      await engine.addMagnet(magnet(hashA), dir: tmp.path);
      await engine.addMagnet(magnet(hashB), dir: tmp.path);
      await engine.addMagnet(magnet(hashC), dir: tmp.path);

      expect(engine.startedIds, hasLength(2));
      await engine.refresh();
      final waiting = engine.tasks.value
          .where((t) => t.state == DownloadState.waiting)
          .length;
      expect(waiting, 3, reason: 'без сети ни одна задача не активна');
      engine.dispose();
    });

    test('пауза освобождает слот для ожидающей задачи', () async {
      final engine = buildEngine(maxConcurrent: 1);
      await engine.addMagnet(magnet(hashA), dir: tmp.path);
      await engine.addMagnet(magnet(hashB), dir: tmp.path);
      expect(engine.startedIds, {hashA});

      await engine.pause(hashA);

      expect(engine.startedIds, contains(hashB));
      expect(engine.taskById(hashA)?.state, DownloadState.paused);
      engine.dispose();
    });

    test('удаление освобождает слот', () async {
      final engine = buildEngine(maxConcurrent: 1);
      await engine.addMagnet(magnet(hashA), dir: tmp.path);
      await engine.addMagnet(magnet(hashB), dir: tmp.path);

      await engine.remove(hashA);

      expect(engine.startedIds, {hashB});
      expect(engine.taskById(hashA), isNull);
      engine.dispose();
    });

    test('увеличение лимита раздаёт слоты сразу', () async {
      final engine = buildEngine(maxConcurrent: 1);
      await engine.addMagnet(magnet(hashA), dir: tmp.path);
      await engine.addMagnet(magnet(hashB), dir: tmp.path);
      expect(engine.startedIds, hasLength(1));

      engine
        ..maxConcurrent = 2
        ..pumpQueue();

      expect(engine.startedIds, hasLength(2));
      engine.dispose();
    });
  });

  group('добавление задач', () {
    test('не-magnet отвергается', () async {
      final engine = buildEngine();
      await expectLater(
        engine.addMagnet('http://example.org/file', dir: tmp.path),
        throwsA(isA<DownloadEngineException>()),
      );
      engine.dispose();
    });

    test('несуществующий торрент-файл отвергается', () async {
      final engine = buildEngine();
      await expectLater(
        engine.addTorrentFile(p.join(tmp.path, 'нет.torrent'), dir: tmp.path),
        throwsA(isA<DownloadEngineException>()),
      );
      engine.dispose();
    });

    test('повторная ссылка не создаёт дубль', () async {
      final engine = buildEngine();

      final first = await engine.addMagnet(magnet(hashA), dir: tmp.path);
      final second = await engine.addMagnet(magnet(hashA), dir: tmp.path);

      expect(first, second);
      expect(engine.startedIds, hasLength(1));
      engine.dispose();
    });

    test('идентификатор задачи — infohash, а не случайное число', () async {
      final engine = buildEngine();
      final id = await engine.addMagnet(magnet(hashA), dir: tmp.path);
      expect(id, hashA);
      engine.dispose();
    });

    test('имя из ссылки попадает в задачу', () async {
      final engine = buildEngine();
      await engine.addMagnet(magnet(hashA, name: 'Моя игра'), dir: tmp.path);
      await engine.refresh();

      expect(engine.taskById(hashA)?.name, 'Моя игра');
      engine.dispose();
    });
  });

  group('состояние между запусками', () {
    test('список загрузок восстанавливается', () async {
      final first = buildEngine();
      await first.addMagnet(magnet(hashA, name: 'Первая'), dir: tmp.path);
      await first.addMagnet(magnet(hashB, name: 'Вторая'), dir: tmp.path);
      first.dispose();

      // Новый движок на том же файле состояния — как после перезапуска.
      final second = buildEngine();
      await second.start();
      await second.refresh();

      expect(second.tasks.value.map((t) => t.id), containsAll([hashA, hashB]));
      expect(second.status.value.state, EngineState.ready);
      second.dispose();
    });

    test('удалённая задача не возвращается после перезапуска', () async {
      final first = buildEngine();
      await first.addMagnet(magnet(hashA), dir: tmp.path);
      await first.addMagnet(magnet(hashB), dir: tmp.path);
      await first.remove(hashA);
      first.dispose();

      final second = buildEngine();
      await second.start();
      await second.refresh();

      expect(second.tasks.value.map((t) => t.id), [hashB]);
      second.dispose();
    });
  });

  test('движок готов сразу: внешнего бинарника больше нет', () async {
    final engine = buildEngine();
    expect(engine.status.value.state, EngineState.stopped);

    await engine.start();

    expect(engine.status.value.isReady, isTrue);
    engine.dispose();
  });
}

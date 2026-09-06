import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:b_encode_decode/b_encode_decode.dart' as bencode;
import 'package:evaporate/models/proxy_settings.dart';
import 'package:evaporate/services/download/dtorrent_engine.dart';
import 'package:evaporate/services/download/torrent_file.dart';
import 'package:evaporate/services/system/proxy_http_overrides.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socks5_proxy/socks_server.dart' as socks;

/// «Загружать через прокси» обязано означать всё, а не почти всё.
///
/// Объявление трекеру внутри `dtorrent_task_v2` заводит `HttpClient()` само
/// и наши настройки не спрашивает — а объявление и есть единственный способ
/// узнать пиров, когда DHT не поднялся. Раздача с закрытым у провайдера
/// трекером не качалась ни с прокси, ни без него, и приложение об этом
/// молчало.
void main() {
  late HttpServer tracker;
  late socks.SocksServer proxy;
  late ServerSocket proxyServer;
  late List<String> announces;
  late int proxied;

  setUp(() async {
    announces = [];
    proxied = 0;

    tracker = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    tracker.listen((request) {
      announces.add(request.uri.toString());
      request.response
        ..headers.contentType = ContentType('text', 'plain')
        ..add('d8:intervali1800e5:peers0:e'.codeUnits);
      request.response.close();
    });

    // Настоящий SOCKS5 на месте: подделка тут ничего не доказала бы —
    // проверяем, что чужой клиент действительно говорит по протоколу.
    proxy = socks.SocksServer();
    // `forward` — именно оно связывает потоки: `accept` только открывает
    // соединение к цели, и запрос повис бы на полпути.
    proxy.connections.listen((connection) {
      proxied++;
      unawaited(connection.forward());
    });
    proxyServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(proxy.addServerSocket(proxyServer));
  });

  tearDown(() async {
    HttpOverrides.global = null;
    await tracker.close(force: true);
    await proxyServer.close();
  });

  ProxySettings socksSettings() =>
      ProxySettings(enabled: true, host: '127.0.0.1', port: proxyServer.port);

  Future<void> install(ProxySettings settings) async {
    final overrides = ProxyHttpOverrides();
    await overrides.apply(settings);
    HttpOverrides.global = overrides;
  }

  group('прокси перехватывает создание клиента', () {
    test('запрос обычного HttpClient идёт через SOCKS5', () async {
      await install(socksSettings());

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${tracker.port}/announce?probe=1'),
      );
      await (await request.close()).drain<void>();
      client.close();

      expect(announces, hasLength(1));
      expect(proxied, 1, reason: 'запрос прошёл мимо прокси');
    });

    // Выключенный прокси не должен ничего перехватывать: иначе запрос уходил
    // бы в никуда у всех, кто прокси не заводил.
    test('без прокси запрос идёт напрямую', () async {
      await install(const ProxySettings());

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${tracker.port}/announce?probe=2'),
      );
      await (await request.close()).drain<void>();
      client.close();

      expect(announces, hasLength(1));
      expect(proxied, 0);
    });
  });

  group('объявление трекеру', () {
    /// Раздача, у которой единственный трекер — наш, на этой же машине.
    Future<File> torrentIn(Directory dir) async {
      final random = Random(7);
      final info = Uint8List.fromList(
        bencode.encode({
          'length': 262144,
          'name': 'Проба связи',
          'piece length': 262144,
          'pieces': Uint8List.fromList([
            for (var i = 0; i < 20; i++) random.nextInt(256),
          ]),
        }, 'utf-8'),
      );
      final file = File('${dir.path}/probe.torrent');
      await file.writeAsBytes(
        TorrentFile.assemble(
          info,
          trackers: [Uri.parse('http://127.0.0.1:${tracker.port}/announce')],
        ),
      );
      return file;
    }

    Future<void> waitFor(bool Function() done) async {
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (!done()) {
        if (DateTime.now().isAfter(deadline)) return;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    test('уходит через прокси, когда прокси включён', () async {
      final tmp = await Directory.systemTemp.createTemp('evaporate_proxy_');
      addTearDown(() => tmp.delete(recursive: true));
      await install(socksSettings());

      final engine = DtorrentEngine(
        downloadDir: tmp.path,
        stateFile: '${tmp.path}/state.json',
        torrentsDir: '${tmp.path}/torrents',
        proxy: socksSettings(),
      );
      addTearDown(engine.stop);
      await engine.start();
      await engine.addTorrentFile((await torrentIn(tmp)).path, dir: tmp.path);

      await waitFor(() => announces.isNotEmpty);

      expect(
        announces,
        isNotEmpty,
        reason: 'движок не объявился трекеру вовсе',
      );
      expect(
        announces.first,
        contains('info_hash='),
        reason: 'объявление без info_hash трекер отвергнет',
      );
      expect(
        proxied,
        greaterThan(0),
        reason:
            'объявление ушло мимо прокси — раздача с закрытым трекером '
            'не поедет ни с прокси, ни без него',
      );
    });
  });
}

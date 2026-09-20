import 'dart:async';
import 'dart:io';

import 'package:evaporate/models/proxy_settings.dart';
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

  Future<ProxyHttpOverrides> install(
    ProxySettings settings, {
    Future<List<InternetAddress>> Function(String host)? lookup,
  }) async {
    final overrides = ProxyHttpOverrides(lookup: lookup);
    await overrides.apply(settings);
    HttpOverrides.global = overrides;
    return overrides;
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

  // Прокси включают ради скрытности, и «не смогли — пойдём напрямую» здесь
  // худший из возможных ответов: объявление трекеру уходило с настоящим
  // адресом человека, а он видел включённый переключатель и строку в
  // журнале, которую никто не читает.
  group('прокси, до которого не дотянуться, не пускает запрос напрямую', () {
    ProxySettings named() =>
        const ProxySettings(enabled: true, host: 'proxy.example', port: 1080);

    Future<List<InternetAddress>> unresolvable(String host) =>
        Future.error(const SocketException('имя не разрешается'));

    test('запрос отклоняется, а не уходит мимо прокси', () async {
      await install(named(), lookup: unresolvable);

      final client = HttpClient();
      // Через `Future(...)`, потому что отказ прилетает синхронно: клиент
      // зовёт способ соединяться, не дожидаясь возврата из `getUrl`.
      await expectLater(
        Future(
          () => client.getUrl(
            Uri.parse('http://127.0.0.1:${tracker.port}/announce?probe=3'),
          ),
        ),
        throwsA(isA<ProxyUnreachableException>()),
      );
      client.close();

      expect(announces, isEmpty, reason: 'запрос ушёл напрямую');
    });

    test(
      'о неразрешённом имени видно снаружи, а не только в журнале',
      () async {
        final overrides = await install(named(), lookup: unresolvable);

        expect(overrides.routing.value, ProxyRouting.blocked);
      },
    );

    test('разрешившееся имя запросов не отклоняет', () async {
      final overrides = await install(
        ProxySettings(
          enabled: true,
          host: 'proxy.example',
          port: proxyServer.port,
        ),
        lookup: (_) async => [InternetAddress.loopbackIPv4],
      );

      expect(overrides.routing.value, ProxyRouting.through);

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${tracker.port}/announce?probe=4'),
      );
      await (await request.close()).drain<void>();
      client.close();

      expect(proxied, 1);
    });

    test('выключенный прокси остаётся прямым путём', () async {
      final overrides = await install(const ProxySettings());

      expect(overrides.routing.value, ProxyRouting.direct);
    });
  });

  // Объявления самого движка здесь нет намеренно. Прогнать его вживую можно
  // только через `TorrentTask.start`, а там перед объявлением идут проброс
  // порта, запрос внешнего IP и подъём DHT: на машине сборки это минуты
  // ожидания, и такой тест уже уронил прогон. Напрямую трекер не завести —
  // `AnnounceOptionsProvider` наружу из библиотеки не экспортирован.
  //
  // Проверено руками на настоящей раздаче: объявление уходит через прокси.
  // Здесь же закреплено то, на чём это держится, — что перехват достаётся
  // любому `HttpClient`, включая тот, который библиотека заводит себе сама.
}

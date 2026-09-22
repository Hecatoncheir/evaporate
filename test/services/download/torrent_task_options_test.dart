import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' as dt;
import 'package:evaporate/models/proxy_settings.dart';
import 'package:evaporate/services/download/torrent_task_options.dart';
import 'package:flutter_test/flutter_test.dart';

/// Во что наши настройки превращаются для торрент-библиотеки.
///
/// Прежде перевод жил внутри движка, и что доезжало до задачи, можно было
/// узнать только живой раздачей — то есть не узнать вовсе.
void main() {
  group('прокси', () {
    test('выключенный прокси не даёт конфигурации', () {
      expect(torrentProxyConfig(const ProxySettings()), isNull);
    });

    test('незаполненный хост не считается настроенным', () {
      expect(
        torrentProxyConfig(const ProxySettings(enabled: true, host: '  ')),
        isNull,
      );
    });

    test('SOCKS5 проксирует и пиров — ради этого движок и менялся', () {
      final config = torrentProxyConfig(
        const ProxySettings(
          enabled: true,
          kind: ProxyKind.socks5,
          host: '127.0.0.1',
          port: 9050,
        ),
      )!;

      expect(config.type, dt.ProxyType.socks5);
      expect(config.host, '127.0.0.1');
      expect(config.port, 9050);
      expect(config.useForPeers, isTrue);
      expect(config.useForTrackers, isTrue);
    });

    test('HTTP-прокси не покрывает пиров', () {
      final config = torrentProxyConfig(
        const ProxySettings(
          enabled: true,
          kind: ProxyKind.http,
          host: 'proxy.local',
          port: 8080,
        ),
      )!;

      expect(config.type, dt.ProxyType.http);
      expect(
        config.useForPeers,
        isFalse,
        reason: 'HTTP-прокси в BitTorrent покрывает только трекеры',
      );
    });

    test('схема в адресе не ломает конфигурацию', () {
      final config = torrentProxyConfig(
        const ProxySettings(
          enabled: true,
          host: 'socks5://10.0.0.1',
          port: 1080,
        ),
      )!;

      expect(config.host, '10.0.0.1');
    });

    test('учётные данные пробрасываются, пустые — нет', () {
      final withAuth = torrentProxyConfig(
        const ProxySettings(
          enabled: true,
          host: 'h',
          port: 1,
          username: 'user',
          password: 'secret',
        ),
      )!;
      final withoutAuth = torrentProxyConfig(
        const ProxySettings(enabled: true, host: 'h', port: 1),
      )!;

      expect(withAuth.username, 'user');
      expect(withAuth.password, 'secret');
      expect(withoutAuth.username, isNull);
      expect(withoutAuth.password, isNull);
    });
  });

  // Прокси перехватывает только `HttpClient`: `udp://` библиотека шлёт
  // своим сокетом, а `ws(s)://` — статическим `WebSocket`. При включённом
  // прокси объявление туда уходило с настоящим адресом.
  group('трекеры при прокси', () {
    final announces = [
      Uri.parse('udp://tracker.example:1337/announce'),
      Uri.parse('http://tracker.example/announce'),
      Uri.parse('https://tracker.example/announce'),
      Uri.parse('wss://tracker.example/announce'),
    ];
    const socks = ProxySettings(enabled: true, host: '127.0.0.1', port: 1080);

    test('без прокси трекеры остаются все', () {
      expect(announcesFor(announces, const ProxySettings()), announces);
    });

    test('при прокси остаются только HTTP-трекеры', () {
      expect(announcesFor(announces, socks).map((uri) => uri.scheme), [
        'http',
        'https',
      ]);
      expect(
        announcesFor(announces, socks.copyWith(kind: ProxyKind.http)),
        hasLength(2),
      );
    });

    // При SOCKS5 поиск идёт через прокси и без DHT: пиров дают только
    // HTTP-трекеры ссылки. Ссылку без них через прокси не найти никогда —
    // отказ словами сразу, а не десять минут ожидания. HTTP-прокси пиров не
    // покрывает и честно об этом говорит — там поиск идёт как шёл.
    test('через SOCKS5 magnet ищется, только если есть HTTP-трекер', () {
      final udpOnly = [Uri.parse('udp://tracker.example:1337/announce')];
      final withHttp = [...udpOnly, Uri.parse('https://t.example/announce')];

      expect(canFetchMetadata(const ProxySettings(), const []), isTrue);
      expect(canFetchMetadata(socks, withHttp), isTrue);
      expect(canFetchMetadata(socks, udpOnly), isFalse);
      expect(canFetchMetadata(socks, const []), isFalse);
      expect(
        canFetchMetadata(socks.copyWith(kind: ProxyKind.http), udpOnly),
        isTrue,
      );
    });
  });
}

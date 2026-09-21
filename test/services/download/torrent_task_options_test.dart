import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' as dt;
import 'package:evaporate/models/proxy_settings.dart';
import 'package:evaporate/models/speed_limits.dart';
import 'package:evaporate/services/download/torrent_task_options.dart';
import 'package:flutter_test/flutter_test.dart';

/// Во что наши настройки превращаются для торрент-библиотеки.
///
/// Прежде перевод жил внутри движка, и какие пределы доезжали до задачи,
/// можно было узнать только живой раздачей — то есть не узнать вовсе.
void main() {
  group('предел скорости', () {
    test('без пределов окна нет — его снимают, а не ставят', () {
      expect(speedLimitWindow(SpeedLimits.unlimited, playing: false), isNull);
      expect(speedLimitWindow(SpeedLimits.unlimited, playing: true), isNull);
    });

    test('килобайты настроек доезжают до задачи байтами', () {
      final window = speedLimitWindow(
        const SpeedLimits(download: 500, upload: 50),
        playing: false,
      )!;

      expect(window.maxDownloadRate, 500 * 1024);
      expect(window.maxUploadRate, 50 * 1024);
    });

    // Предел на время игры — то, ради чего лончер и держит скорость сам:
    // обычный клиент не знает, что вы сейчас играете.
    test('во время игры действует свой предел приёма', () {
      const limits = SpeedLimits(download: 500, whilePlaying: 100);

      expect(
        speedLimitWindow(limits, playing: false)!.maxDownloadRate,
        500 * 1024,
      );
      expect(
        speedLimitWindow(limits, playing: true)!.maxDownloadRate,
        100 * 1024,
      );
    });

    test('один предел раздачи — тоже окно, а приём остаётся свободным', () {
      final window = speedLimitWindow(
        const SpeedLimits(upload: 20),
        playing: false,
      )!;

      expect(window.maxDownloadRate, isNull);
      expect(window.maxUploadRate, 20 * 1024);
    });

    // Окно круглосуточное только потому, что расписанием мы не пользуемся;
    // вне окна библиотека по умолчанию ставит задачу на паузу, и узкое окно
    // останавливало бы загрузку по ночам без единого слова.
    test('окно на все дни и сутки и паузы вне себя не ставит', () {
      final window = speedLimitWindow(
        const SpeedLimits(download: 1),
        playing: false,
      )!;

      expect(window.id, speedLimitWindowId);
      expect(window.weekdays, {1, 2, 3, 4, 5, 6, 7});
      expect(window.start, Duration.zero);
      expect(window.end, const Duration(hours: 23, minutes: 59));
      expect(window.pauseOutsideWindow, isFalse);
    });
  });

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
}

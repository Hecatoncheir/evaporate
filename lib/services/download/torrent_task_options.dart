import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' as dt;

import '../../models/proxy_settings.dart';
import '../../models/speed_limits.dart';

// Наши настройки на языке `dtorrent_task_v2`.
//
// Отдельно от движка, потому что это перевод, а не работа с раздачами: на
// входе настройки, на выходе объекты библиотеки — ни задач, ни сети.
// Внутри движка он проверялся только живой задачей, то есть не проверялся
// вовсе: какие именно пределы доезжали до библиотеки, не видел ни один тест.

/// Под каким именем предел скорости лежит среди окон расписания задачи.
///
/// Одно имя на все задачи: снять или заменить предел — значит найти своё
/// окно, а не перебирать чужие.
const speedLimitWindowId = 'evaporate-speed-limit';

/// Окно расписания, которым задаче задаётся предел скорости.
///
/// Публичного способа задать предел разом у библиотеки нет — есть окна
/// расписания у задачи. Ставим одно окно на все дни и все сутки:
/// расписанием мы не пользуемся, нужен только предел.
///
/// `null` — ограничивать нечего, и окно надо не ставить, а снять.
dt.ScheduleWindow? speedLimitWindow(
  SpeedLimits limits, {
  required bool playing,
}) {
  final download = limits.downloadBytes(playing: playing);
  final upload = limits.uploadBytes;
  if (download == null && upload == null) return null;
  return dt.ScheduleWindow(
    id: speedLimitWindowId,
    weekdays: const {1, 2, 3, 4, 5, 6, 7},
    start: Duration.zero,
    end: const Duration(hours: 23, minutes: 59),
    maxDownloadRate: download,
    maxUploadRate: upload,
    // Иначе вне окна задача встала бы на паузу — а окно у нас
    // круглосуточное только по недосмотру расписания.
    pauseOutsideWindow: false,
  );
}

/// Настройки прокси приложения в конфиг библиотеки. `null` — без прокси.
dt.ProxyConfig? torrentProxyConfig(ProxySettings proxy) {
  if (!proxy.isUsable) return null;
  final host = proxy.host.trim().replaceFirst(RegExp(r'^\w+://'), '');
  final user = proxy.hasCredentials ? proxy.username : null;
  final password = proxy.password.isEmpty ? null : proxy.password;

  return switch (proxy.kind) {
    // Для SOCKS5 прокси покрывает и пиров — ради этого движок и менялся.
    ProxyKind.socks5 => dt.ProxyConfig.socks5(
      host: host,
      port: proxy.port,
      username: user,
      password: password,
      useForTrackers: true,
      useForPeers: true,
    ),
    ProxyKind.http => dt.ProxyConfig.http(
      host: host,
      port: proxy.port,
      username: user,
      password: password,
    ),
  };
}

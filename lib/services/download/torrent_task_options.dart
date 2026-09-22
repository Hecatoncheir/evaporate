import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' as dt;

import '../../models/proxy_settings.dart';

// Наши настройки на языке `dtorrent_task_v2`.
//
// Отдельно от движка, потому что это перевод, а не работа с раздачами: на
// входе настройки, на выходе объекты библиотеки — ни задач, ни сети.
// Внутри движка он проверялся только живой задачей, то есть не проверялся
// вовсе: что именно доезжало до библиотеки, не видел ни один тест.
//
// Пределов скорости здесь больше нет: библиотека принимает их окном
// расписания и не соблюдает (см. `DtorrentEngine.applyLimits`).

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

/// Трекеры, которым можно объявлять раздачу при этих настройках прокси.
///
/// Прокси перехватывает только `HttpClient` (`ProxyHttpOverrides`), а
/// `udp://` библиотека шлёт своим сокетом, `ws(s)://` — статическим
/// `WebSocket`, и оба идут мимо прокси с настоящим адресом человека. В духе
/// уже принятого решения — прокси, который не держит, отказывает, а не
/// пропускает мимо себя, — такие трекеры при включённом прокси выбрасываем.
/// Раздача без HTTP-трекеров при этом ищет пиров только через DHT, и об
/// этом говорит подпись в настройках.
List<Uri> announcesFor(List<Uri> announces, ProxySettings proxy) {
  if (!proxy.isUsable) return announces;
  return [
    for (final uri in announces)
      if (uri.scheme == 'http' || uri.scheme == 'https') uri,
  ];
}

/// Можно ли искать метаданные magnet-ссылки по сети при этих настройках.
///
/// При SOCKS5 поиск идёт к пирам через прокси, а DHT не поднимается вовсе:
/// он — голый UDP, и узлы видели бы настоящий адрес. Пиров тогда дают
/// только HTTP-трекеры ссылки (`udp://` через SOCKS5 не пройдёт), и ссылка
/// без них не найдётся никогда — это отказ словами сразу, а не десять
/// минут ожидания. HTTP-прокси пиров не покрывает — это в подписи к нему, —
/// и там поиск идёт как шёл.
bool canFetchMetadata(ProxySettings proxy, Iterable<Uri> trackers) {
  if (!proxy.isUsable || proxy.kind != ProxyKind.socks5) return true;
  return trackers.any((uri) => uri.scheme == 'http' || uri.scheme == 'https');
}

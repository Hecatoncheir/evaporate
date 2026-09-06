import 'dart:io';

import 'package:socks5_proxy/socks_client.dart' as socks;

import '../../models/proxy_settings.dart';
import 'app_log.dart';

/// Уводит весь HTTP приложения в прокси пользователя.
///
/// Перехватывать создание клиента приходится из-за чужого кода: объявление
/// трекеру внутри `dtorrent_task_v2` заводит `HttpClient()` само и о наших
/// настройках не знает — флаг `useForTrackers` читают только пути паузы и
/// scrape, а не тот, что работает при старте задачи. Дотянуться до него
/// больше неоткуда, и без этого переключатель «Загружать через прокси»
/// обещал неправду: раздача с закрытым у провайдера трекером не качалась ни
/// с прокси, ни без него — пиров взять было неоткуда.
///
/// Перехват общий, поэтому места, где о прокси решают отдельно, берут
/// клиента через [directHttpClient] — иначе отдельный флаг «в Steam ходить
/// напрямую» перестал бы что-либо значить.
class ProxyHttpOverrides extends HttpOverrides {
  ProxySettings _settings = const ProxySettings();
  InternetAddress? _address;

  ProxySettings get settings => _settings;

  /// Куда сейчас уходят запросы. `null` — напрямую.
  InternetAddress? get address => _address;

  /// Меняет прокси. Имя разрешается здесь, а не при каждом запросе: клиент
  /// создаётся синхронно, а подключаться к прокси нужно по адресу — имя
  /// SOCKS-клиент принимает только для того, к кому идут через прокси.
  Future<void> apply(ProxySettings settings) async {
    _settings = settings;
    _address = settings.isUsable ? await _resolve(settings.host) : null;
  }

  static Future<InternetAddress?> _resolve(String host) async {
    final cleaned = host.trim().replaceFirst(RegExp(r'^\w+://'), '');
    final literal = InternetAddress.tryParse(cleaned);
    if (literal != null) return literal;
    try {
      final found = await InternetAddress.lookup(cleaned);
      return found.isEmpty ? null : found.first;
    } on Object catch (error) {
      // Молчать нельзя: без адреса запросы пойдут напрямую, а человек будет
      // уверен, что идут через прокси.
      AppLog.instance.write('прокси: не разобрать адрес «$host»', error);
      return null;
    }
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    final settings = _settings;
    final address = _address;
    if (!settings.isUsable || address == null) return client;

    switch (settings.kind) {
      // SOCKS5 в HttpClient не встроен: пакет подменяет ему способ
      // устанавливать соединение.
      case ProxyKind.socks5:
        socks.SocksTCPClient.assignToHttpClient(client, [
          socks.ProxySettings(
            address,
            settings.port,
            username: settings.hasCredentials ? settings.username : null,
            password: settings.password.isEmpty ? null : settings.password,
          ),
        ]);
      case ProxyKind.http:
        client.findProxy = (_) => 'PROXY ${address.address}:${settings.port}';
        if (settings.hasCredentials) {
          client.addProxyCredentials(
            address.address,
            settings.port,
            'Basic',
            HttpClientBasicCredentials(settings.username, settings.password),
          );
        }
    }
    return client;
  }
}

/// Клиент, которого перехват не касается.
///
/// Нужен там, где о прокси решают отдельно: каталог Steam, база путей
/// сохранений и обновление спрашивают свои флаги и настраивают клиента сами.
/// Глобальный перехват отнял бы у человека выбор «качать через прокси, а в
/// Steam ходить напрямую», ради которого отдельный флаг и заведён.
HttpClient directHttpClient([SecurityContext? context]) =>
    HttpOverrides.runWithHttpOverrides(
      () => HttpClient(context: context),
      _NoOverrides(),
    );

class _NoOverrides extends HttpOverrides {}

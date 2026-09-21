import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:socks5_proxy/socks_client.dart' as socks;

import '../../models/proxy_settings.dart';
import 'app_log.dart';

/// Куда сейчас уходит HTTP приложения.
enum ProxyRouting {
  /// Прокси не задан: идём напрямую, как и просили.
  direct,

  /// Идём через прокси.
  through,

  /// Прокси задан, но его адрес не разрешается, и соединения отклоняются.
  ///
  /// Отдельное состояние, а не «как будто напрямую»: прокси включают ради
  /// скрытности, и молчаливый переход на прямые запросы — худшее, что
  /// можно сделать с таким намерением.
  blocked,
}

/// Соединение отклонено: прокси задан, а ходить через него сейчас нечем.
///
/// Исключение, а не тихий прямой запрос: пусть загрузка сорвётся с
/// понятной причиной, чем уйдёт к трекеру с настоящим адресом человека.
class ProxyUnreachableException implements Exception {
  const ProxyUnreachableException(this.host);

  final String host;

  @override
  String toString() => 'прокси «$host» недоступен: соединение отклонено';
}

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
  ProxyHttpOverrides({
    AppLog Function()? log,
    Future<List<InternetAddress>> Function(String host)? lookup,
    this.retryDelay = const Duration(seconds: 30),
  }) : _log = log ?? _appLog,
       _lookup = lookup ?? InternetAddress.lookup;

  /// Через сколько снова разрешать имя заблокированного прокси.
  ///
  /// Автозапуск бывает раньше сети: имя не разрешилось, и без повтора прокси
  /// оставался заблокированным до правки настроек, а загрузки стояли, хотя
  /// сеть давно появилась.
  final Duration retryDelay;

  Timer? _retry;

  /// Номер последнего `apply`. Имя разрешается не мгновенно, и два `apply`
  /// кончались в порядке ответов DNS: поздний ответ про прежний прокси
  /// возвращал его.
  var _generation = 0;

  /// Куда писать о неразобранном адресе. Функцией — как `L Function()` у
  /// блоков: журнал заводится в `main`, а в тестах подменяется без правки
  /// глобала.
  final AppLog Function() _log;

  static AppLog _appLog() => AppLog.instance;

  /// Чем разрешать имя. Подменяется в прогоне: настоящий DNS в тестах —
  /// это и сеть, и чужой ответ, который однажды окажется другим.
  final Future<List<InternetAddress>> Function(String host) _lookup;

  ProxySettings _settings = const ProxySettings();
  InternetAddress? _address;

  /// Куда уходит HTTP приложения прямо сейчас.
  ///
  /// Слушателем, а не возвращаемым значением [apply]: прокси меняется и
  /// сам по себе — из потока настроек, — а сказать о том, что он отвалился,
  /// надо человеку, а не тому, кто его применил.
  final routing = ValueNotifier(ProxyRouting.direct);

  ProxySettings get settings => _settings;

  /// Куда сейчас уходят запросы. `null` — напрямую.
  InternetAddress? get address => _address;

  /// Меняет прокси. Имя разрешается здесь, а не при каждом запросе: клиент
  /// создаётся синхронно, а подключаться к прокси нужно по адресу — имя
  /// SOCKS-клиент принимает только для того, к кому идут через прокси.
  ///
  /// Настройки и адрес ставятся **одной парой**, когда имя уже разрешилось:
  /// прежде настройки менялись сразу, а адрес — после DNS, и запрос в этом
  /// окне уходил на адрес прежнего прокси с портом и учётными данными
  /// нового. До тех пор действует прежняя пара целиком.
  Future<void> apply(ProxySettings settings) async {
    final generation = ++_generation;
    _retry?.cancel();
    final address = settings.isUsable ? await _resolve(settings.host) : null;
    if (generation != _generation) return;
    _settings = settings;
    _address = address;
    routing.value = switch ((settings.isUsable, address)) {
      (false, _) => ProxyRouting.direct,
      (true, null) => ProxyRouting.blocked,
      _ => ProxyRouting.through,
    };
    if (routing.value == ProxyRouting.blocked) {
      _retry = Timer(retryDelay, () => unawaited(apply(settings)));
    }
  }

  /// Больше не пробовать разрешить имя — шаг завершения.
  void stopRetrying() {
    _generation++;
    _retry?.cancel();
  }

  Future<InternetAddress?> _resolve(String host) async {
    final cleaned = host.trim().replaceFirst(RegExp(r'^\w+://'), '');
    final literal = InternetAddress.tryParse(cleaned);
    if (literal != null) return literal;
    try {
      final found = await _lookup(cleaned);
      return found.isEmpty ? null : found.first;
    } on Object catch (error) {
      _log().write('прокси: не разобрать адрес «$host»', error);
      return null;
    }
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    final settings = _settings;
    final address = _address;
    // Прокси просили, а адреса у нас нет — отказываем. Прежде здесь
    // возвращался обычный клиент, и запросы шли напрямую: объявление
    // трекеру уходило с настоящим адресом человека, а он видел включённый
    // переключатель и строку в журнале, которую никто не читает.
    if (settings.isUsable && address == null) {
      return _refusing(client, settings.host);
    }
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

  /// Клиент, который не соединяется ни с кем.
  ///
  /// Отказ ставится подменой способа соединяться, а не выдуманным адресом
  /// прокси: запрос к несуществующему узлу ждал бы таймаута и выглядел бы
  /// оборванной сетью, а здесь причина названа своими словами и доходит до
  /// того, кто запрос сделал.
  HttpClient _refusing(HttpClient client, String host) =>
      client
        ..connectionFactory = (_, _, _) =>
            throw ProxyUnreachableException(host);
}

/// Клиент, которого перехват не касается.
///
/// Нужен там, где о прокси решают отдельно: каталог Steam и база путей
/// сохранений спрашивают свой флаг ([ProxySettings.forCatalogs]).
/// Глобальный перехват отнял бы у человека выбор «качать через прокси, а в
/// Steam ходить напрямую», ради которого отдельный флаг и заведён.
HttpClient directHttpClient([SecurityContext? context]) =>
    HttpOverrides.runWithHttpOverrides(
      () => HttpClient(context: context),
      _NoOverrides(),
    );

/// Клиент для того, кто решает о прокси сам, — каталога Steam и базы
/// путей сохранений.
///
/// Выбор «перехваченный или прямой» стоял у обоих своей копией, а правило
/// у него одно: [ProxySettings.forCatalogs].
HttpClient catalogHttpClient(
  ProxySettings proxy, {
  required Duration timeout,
}) =>
    (proxy.forCatalogs ? HttpClient() : directHttpClient())
      ..connectionTimeout = timeout;

/// Клиент для проверки и загрузки обновлений — **через прокси**, как весь
/// остальной HTTP.
///
/// Решение записано, потому что прежде оно было ничьим: обновление брало
/// прямой клиент, а комментарий уверял, что оно «спрашивает свои флаги» —
/// флагов у него не было. Запрос к GitHub выдаёт, что человек пользуется
/// Evaporate, и кто включил прокси ради скрытности, вправе ждать, что и
/// этот запрос уйдёт через него. Отдельного выключателя, как у каталогов, у
/// обновления нет: там это выбор между «видно ли Steam мой адрес» и
/// «работает ли поиск обложек», здесь такого выбора нет. Недоступный прокси
/// отказывает и здесь — проверка обновлений молча не удастся, а не уйдёт
/// напрямую.
HttpClient updateHttpClient() => HttpClient();

class _NoOverrides extends HttpOverrides {}

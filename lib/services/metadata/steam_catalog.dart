import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:socks5_proxy/socks_client.dart' as socks;

import '../../models/proxy_settings.dart';
import 'release_name.dart';

/// Игра, найденная в каталоге Steam.
class SteamGame extends Equatable {
  const SteamGame({
    required this.appId,
    required this.name,
    this.headerImage,
    this.description,
  });

  final int appId;
  final String name;
  final String? headerImage;
  final String? description;

  SteamGame merge(SteamGame other) => SteamGame(
    appId: appId,
    name: other.name.isNotEmpty ? other.name : name,
    headerImage: other.headerImage ?? headerImage,
    description: other.description ?? description,
  );

  @override
  List<Object?> get props => [appId, name, headerImage, description];
}

class SteamLookupException implements Exception {
  SteamLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Поиск игры по имени раздачи в каталоге Steam.
///
/// SteamDB для этого не годится: он закрыт Cloudflare и отвечает 403 на
/// автоматические запросы. Здесь используются публичные точки самого Steam.
class SteamCatalog {
  SteamCatalog({
    Future<String> Function(Uri uri)? fetch,
    this.language = 'russian',
    ProxySettings Function()? proxy,
  }) : _proxy = proxy ?? _noProxy {
    _fetch = fetch;
  }

  /// Подменяется в тестах, чтобы не ходить в сеть.
  late final Future<String> Function(Uri uri)? _fetch;

  /// Настройки читаются на каждый запрос: пользователь мог поменять их,
  /// пока приложение открыто.
  final ProxySettings Function() _proxy;
  final String language;

  static ProxySettings _noProxy() => const ProxySettings();

  Future<String> _request(Uri uri) {
    final override = _fetch;
    return override != null ? override(uri) : _httpFetch(uri);
  }

  static const _searchLimit = 8;

  /// Ищет кандидатов по имени раздачи, предварительно очистив его.
  Future<List<SteamGame>> searchByRelease(String releaseName) {
    final query = ReleaseName.clean(releaseName);
    if (query.isEmpty) return Future.value(const []);
    return search(query);
  }

  Future<List<SteamGame>> search(String query) async {
    final uri = Uri.https('store.steampowered.com', '/api/storesearch/', {
      'term': query,
      'l': language,
      'cc': 'ru',
    });

    final body = await _request(uri);
    return parseSearch(body);
  }

  /// Подробности: описание и картинка шапки.
  Future<SteamGame?> details(int appId) async {
    final uri = Uri.https('store.steampowered.com', '/api/appdetails', {
      'appids': '$appId',
      'l': language,
    });

    final body = await _request(uri);
    return parseDetails(body, appId);
  }

  /// Ищет и сразу дополняет лучший результат подробностями.
  ///
  /// [minSimilarity] отсекает случайные попадания: у поиска Steam широкая
  /// выдача, и «Hollow Knight» легко превращается в саундтрек к ней.
  Future<SteamGame?> bestMatch(
    String releaseName, {
    double minSimilarity = 0.6,
  }) async {
    final cleaned = ReleaseName.clean(releaseName);
    if (cleaned.isEmpty) return null;

    final candidates = await search(cleaned);
    if (candidates.isEmpty) return null;

    SteamGame? best;
    var bestScore = 0.0;
    for (final candidate in candidates) {
      final score = ReleaseName.similarity(cleaned, candidate.name);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    if (best == null || bestScore < minSimilarity) return null;

    final detailed = await details(best.appId);
    return detailed == null ? best : best.merge(detailed);
  }

  /// Разбор ответа поиска. Вынесено отдельно: так парсинг проверяется
  /// на зафиксированных ответах, без обращения к сети.
  static List<SteamGame> parseSearch(String body) {
    final decoded = _decodeMap(body);
    final items = decoded['items'];
    if (items is! List) return const [];

    return items
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final id = item['id'];
          final name = item['name'];
          if (id is! int || name is! String) return null;
          return SteamGame(
            appId: id,
            name: name,
            headerImage: item['tiny_image'] as String?,
          );
        })
        .whereType<SteamGame>()
        .take(_searchLimit)
        .toList();
  }

  static SteamGame? parseDetails(String body, int appId) {
    final decoded = _decodeMap(body);
    final entry = decoded['$appId'];
    if (entry is! Map<String, dynamic>) return null;
    if (entry['success'] != true) return null;

    final data = entry['data'];
    if (data is! Map<String, dynamic>) return null;

    final name = data['name'];
    if (name is! String) return null;

    return SteamGame(
      appId: appId,
      name: name,
      headerImage: data['header_image'] as String?,
      description: data['short_description'] as String?,
    );
  }

  static Map<String, dynamic> _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      throw SteamLookupException('Steam вернул неожиданный ответ');
    }
  }

  /// Готовит клиент под настройки прокси.
  ///
  /// `HttpClient` умеет только HTTP-прокси, поэтому SOCKS5 подключается
  /// подменой фабрики соединений: домен уходит в прокси нерезолвленным,
  /// и DNS-запрос не утекает мимо него.
  /// Значение для `findProxy` или null, если HTTP-прокси не нужен.
  ///
  /// Вынесено отдельно: у `HttpClient` нет геттера `findProxy`, поэтому
  /// проверить применённую настройку можно только на этом уровне.
  @visibleForTesting
  String? httpProxyDirective() {
    final proxy = _proxy();
    if (!_appliesToSteam(proxy) || proxy.kind != ProxyKind.http) return null;
    return 'PROXY ${_hostOf(proxy)}:${proxy.port}';
  }

  /// SOCKS5 идёт мимо `findProxy` — через подмену фабрики соединений.
  @visibleForTesting
  bool usesSocksTunnel() {
    final proxy = _proxy();
    return _appliesToSteam(proxy) && proxy.kind == ProxyKind.socks5;
  }

  static bool _appliesToSteam(ProxySettings proxy) =>
      proxy.isUsable && proxy.useForSteam;

  static String _hostOf(ProxySettings proxy) =>
      proxy.host.trim().replaceFirst(RegExp(r'^\w+://'), '');

  void configureClient(HttpClient client) {
    final proxy = _proxy();
    if (!_appliesToSteam(proxy)) return;

    final host = _hostOf(proxy);
    switch (proxy.kind) {
      case ProxyKind.socks5:
        socks.SocksTCPClient.assignToHttpClient(client, [
          socks.ProxySettings(
            InternetAddress(host, type: InternetAddressType.unix),
            proxy.port,
            username: proxy.hasCredentials ? proxy.username : null,
            password: proxy.password.isEmpty ? null : proxy.password,
          ),
        ]);
      case ProxyKind.http:
        client.findProxy = (_) => 'PROXY $host:${proxy.port}';
        if (proxy.hasCredentials) {
          client.addProxyCredentials(
            host,
            proxy.port,
            'Basic',
            HttpClientBasicCredentials(proxy.username, proxy.password),
          );
        }
    }
  }

  Future<String> _httpFetch(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    configureClient(client);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw SteamLookupException('Steam ответил ${response.statusCode}');
      }
      // Без await клиент в finally закроется раньше, чем дочитается тело.
      return await response.transform(utf8.decoder).join();
    } on SocketException catch (error) {
      throw SteamLookupException('Нет связи со Steam: ${error.message}');
    } finally {
      client.close(force: true);
    }
  }
}

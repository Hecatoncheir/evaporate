import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../system/proxy_http_overrides.dart';
import '../../models/proxy_settings.dart';
import 'release_name.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';

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
    L Function()? localizations,
  }) : _proxy = proxy ?? _noProxy,
       _localizations = localizations ?? _defaultLocalizations {
    _fetch = fetch;
  }

  /// Откуда брать переводы: ошибки отсюда доходят до пользователя
  /// уведомлениями, а `BuildContext` здесь взять неоткуда.
  final L Function() _localizations;

  L get _l => _localizations();

  static L _defaultLocalizations() => LRu();

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

  /// Вертикальная обложка из библиотеки Steam — та самая, из которой
  /// складывается сетка в Big Picture. Соотношение 2:3.
  ///
  /// Собирается по идентификатору, а не спрашивается у API: в ответе
  /// `appdetails` её нет, зато на CDN она лежит по предсказуемому адресу.
  /// Есть не у всякой игры — на старые и мелкие её просто не рисовали, и
  /// тогда CDN отвечает отказом, а показывать приходится горизонтальную.
  static String portraitUrl(int appId) =>
      'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId'
      '/library_600x900.jpg';

  static const _searchLimit = 8;

  /// Обложку загружаем только вместе с явным поиском метаданных; UI читает
  /// сохранённый файл и никогда не обращается к Steam при перерисовке.
  Future<List<int>?> coverBytes(SteamGame game) async {
    for (final url in [
      portraitUrl(game.appId),
      if (game.headerImage != null) game.headerImage!,
    ]) {
      final client = _client(const Duration(seconds: 10));
      try {
        final bytes = await (() async {
          final response = await (await client.getUrl(Uri.parse(url))).close();
          if (response.statusCode != 200) return null;
          // BytesBuilder, а не List<int>: в списке чисел каждый байт занял бы
          // машинное слово, и обложка у верхнего предела стоила бы восьмидесяти
          // мегабайт памяти вместо десяти.
          final builder = BytesBuilder(copy: false);
          await for (final chunk in response) {
            builder.add(chunk);
            if (builder.length > 10 * 1024 * 1024) {
              throw const FormatException('Cover is too large');
            }
          }
          return builder.isEmpty ? null : builder.takeBytes();
        })().timeout(const Duration(seconds: 20));
        if (bytes != null) return bytes;
      } on Object {
        // Отсутствующая обложка не отменяет найденные ID и описание.
      } finally {
        client.close(force: true);
      }
    }
    return null;
  }

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
      throw SteamLookupException(_defaultLocalizations().steamUnexpectedAnswer);
    }
  }

  /// Идут ли запросы каталога через прокси.
  ///
  /// Своей настройки прокси у каталога больше нет: её применяет общий
  /// перехват создания клиентов. Здесь остался только выбор — брать
  /// перехваченного клиента или прямого: «качать через прокси, а в Steam
  /// ходить напрямую» — законное желание, ради него флаг и заведён.
  @visibleForTesting
  bool usesProxy() {
    final proxy = _proxy();
    return proxy.isUsable && proxy.useForSteam;
  }

  HttpClient _client(Duration timeout) =>
      (usesProxy() ? HttpClient() : directHttpClient())
        ..connectionTimeout = timeout;

  Future<String> _httpFetch(Uri uri) async {
    final client = _client(const Duration(seconds: 10));
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw SteamLookupException(_l.steamStatus(response.statusCode));
      }
      // Без await клиент в finally закроется раньше, чем дочитается тело.
      return await response.transform(utf8.decoder).join();
    } on SocketException catch (error) {
      throw SteamLookupException(_l.steamNoConnection(error.message));
    } finally {
      client.close(force: true);
    }
  }
}

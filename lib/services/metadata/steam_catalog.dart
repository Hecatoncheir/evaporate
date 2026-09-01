import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';

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
  }) : _fetch = fetch ?? _httpFetch;

  final Future<String> Function(Uri uri) _fetch;
  final String language;

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

    final body = await _fetch(uri);
    return parseSearch(body);
  }

  /// Подробности: описание и картинка шапки.
  Future<SteamGame?> details(int appId) async {
    final uri = Uri.https('store.steampowered.com', '/api/appdetails', {
      'appids': '$appId',
      'l': language,
    });

    final body = await _fetch(uri);
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

  static Future<String> _httpFetch(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
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

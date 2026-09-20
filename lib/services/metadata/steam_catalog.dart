import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/proxy_settings.dart';
import '../system/http_fetch.dart';
import '../system/proxy_http_overrides.dart';
import 'release_name.dart';

/// Игра, найденная в каталоге Steam.
class SteamGame extends Equatable {
  const SteamGame({
    required this.appId,
    required this.name,
    this.headerImage,
    this.description,
    this.metacritic,
    this.screenshots = const [],
  });

  final int appId;
  final String name;
  final String? headerImage;
  final String? description;

  /// Оценка прессы, 0–100. Есть далеко не у всякой игры: Metacritic
  /// оценивает то, что до него дошло, и у половины каталога её просто нет.
  final int? metacritic;

  /// Кадры из игры, миниатюрами 600×338.
  ///
  /// Полные 1920×1080 лежат в том же ответе, но нам они не нужны: кадры
  /// идут под крупную обложку библиотеки размытыми и затемнёнными, а весят
  /// всемеро больше и разворачиваются в памяти в восемь мегабайт каждый.
  ///
  /// Приходят даром: это тот же `appdetails`, из которого берутся описание
  /// и Metacritic, — отдельного запроса, а значит и новой очереди к Steam,
  /// здесь не заводится.
  final List<String> screenshots;

  SteamGame merge(SteamGame other) => SteamGame(
    appId: appId,
    name: other.name.isNotEmpty ? other.name : name,
    headerImage: other.headerImage ?? headerImage,
    description: other.description ?? description,
    metacritic: other.metacritic ?? metacritic,
    screenshots: other.screenshots.isNotEmpty ? other.screenshots : screenshots,
  );

  @override
  List<Object?> get props => [
    appId,
    name,
    headerImage,
    description,
    metacritic,
    screenshots,
  ];
}

/// Итог обзоров игры в Steam.
///
/// Отдельно от [SteamGame] потому, что приходит из другой точки: в
/// `appdetails` обзоров нет вовсе, их считает `appreviews`.
class SteamReviews extends Equatable {
  const SteamReviews({
    required this.score,
    required this.summary,
    required this.positive,
    required this.negative,
  });

  /// Ступень Steam, 0–9: 5 — «Смешанные», 9 — «Крайне положительные».
  /// В интерфейсе самого Steam числа не видно, и мы его тоже не
  /// показываем — по нему выбирается цвет оценки. Своей границы по
  /// проценту не заводим: у Steam она зависит ещё и от числа обзоров,
  /// и повторять её на глаз значило бы иногда красить вопреки подписи.
  final int score;

  /// Словами и от самого Steam («Очень положительные»). Своей таблицы
  /// «ступень → слово» не держим: ступеней десять, эмпирически проверены
  /// не все, и придуманная подпись сказала бы о вкусах игроков то, чего мы
  /// не знаем.
  final String summary;

  final int positive;
  final int negative;

  int get total => positive + negative;

  /// Доля положительных, 0–100. То самое число, которое Steam показывает
  /// в подсказке к оценке.
  int get positiveShare => total == 0 ? 0 : (positive * 100 / total).round();

  @override
  List<Object?> get props => [score, summary, positive, negative];
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
    Future<List<int>?> Function(Uri uri)? fetchImage,
    this.language = 'russian',
    ProxySettings Function()? proxy,
    L Function()? localizations,
  }) : _proxy = proxy ?? _noProxy,
       _localizations = localizations ?? _defaultLocalizations {
    _fetch = fetch;
    _fetchImage = fetchImage;
  }

  /// Откуда брать переводы: ошибки отсюда доходят до пользователя
  /// уведомлениями, а `BuildContext` здесь взять неоткуда.
  final L Function() _localizations;

  L get _l => _localizations();

  static L _defaultLocalizations() => LRu();

  /// Подменяется в тестах, чтобы не ходить в сеть.
  late final Future<String> Function(Uri uri)? _fetch;

  /// Картинки идут мимо [_fetch]: тот отдаёт текст, а тут байты.
  late final Future<List<int>?> Function(Uri uri)? _fetchImage;

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

  /// Горизонтальная плашка: ею Steam показывает игру в полке «недавние» и
  /// в списках, где вертикальной обложке места нет.
  static String capsuleUrl(int appId) =>
      'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/header.jpg';

  /// Широкий задник страницы игры в библиотеке.
  static String heroUrl(int appId) =>
      'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId'
      '/library_hero.jpg';

  /// Название игры картинкой — Steam кладёт его поверх задника.
  static String logoUrl(int appId) =>
      'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/logo.png';

  static const _searchLimit = 8;

  /// Обложку загружаем только вместе с явным поиском метаданных; UI читает
  /// сохранённый файл и никогда не обращается к Steam при перерисовке.
  Future<List<int>?> coverBytes(SteamGame game) async {
    for (final url in [
      portraitUrl(game.appId),
      if (game.headerImage != null) game.headerImage!,
    ]) {
      final bytes = await imageBytes(url);
      if (bytes != null) return bytes;
    }
    return null;
  }

  /// Картинка по адресу, или `null`, если её там нет.
  ///
  /// Отсутствие — обычное дело, а не сбой: вертикальную обложку старым и
  /// мелким играм не рисовали вовсе, и CDN на такую просьбу отвечает
  /// отказом. Поэтому исход здесь один — «есть или нет», без исключений
  /// наружу.
  Future<List<int>?> imageBytes(String url) async {
    final override = _fetchImage;
    if (override != null) return override(Uri.parse(url));

    try {
      final bytes = await _fetcher(
        const Duration(seconds: 10),
        limitBytes: 10 * 1024 * 1024,
      ).bytes(Uri.parse(url)).timeout(const Duration(seconds: 20));
      return bytes.isEmpty ? null : bytes;
    } on Object {
      return null;
    }
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

  /// Итог обзоров. Отдельным запросом, потому что `appdetails` его не несёт.
  ///
  /// `language=all` и `purchase_type=all` — не украшение: по умолчанию Steam
  /// считает обзоры на одном языке и только от купивших в Steam, и итог
  /// вышел бы меньше того, что написано у игры на странице магазина.
  /// `num_per_page=0` отсекает сами тексты обзоров: нужен только итог, а
  /// иначе к нему прилагаются два десятка полных отзывов.
  Future<SteamReviews?> reviews(int appId) async {
    final uri = Uri.https('store.steampowered.com', '/appreviews/$appId', {
      'json': '1',
      'language': 'all',
      'purchase_type': 'all',
      'num_per_page': '0',
      'l': language,
    });

    final body = await _request(uri);
    return parseReviews(body);
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

    final best = ReleaseName.bestMatch(
      candidates,
      cleaned,
      titleOf: (candidate) => candidate.name,
      minSimilarity: minSimilarity,
    );
    if (best == null) return null;

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

    final metacritic = data['metacritic'];

    return SteamGame(
      appId: appId,
      name: name,
      headerImage: data['header_image'] as String?,
      description: data['short_description'] as String?,
      metacritic: metacritic is Map<String, dynamic>
          ? metacritic['score'] as int?
          : null,
      screenshots: _screenshots(data['screenshots']),
    );
  }

  /// Кадры из ответа `appdetails`.
  ///
  /// Берём `path_thumbnail`, а не `path_full`: подложке хватает 600×338, а
  /// полный кадр весит всемеро больше. Пропускаем всё, что не строка: ответ
  /// приходит из сети, и один испорченный элемент не должен уносить всю
  /// подборку.
  static List<String> _screenshots(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic> && item['path_thumbnail'] is String)
          item['path_thumbnail'] as String,
    ];
  }

  /// Разбор итога обзоров.
  ///
  /// `null` — это и «Steam отказал», и «обзоров нет ни одного»: показывать
  /// в обоих случаях нечего, а «0 из 0 положительные» сказало бы об игре
  /// то, чего никто не говорил.
  static SteamReviews? parseReviews(String body) {
    final decoded = _decodeMap(body);
    if (decoded['success'] != 1) return null;

    final summary = decoded['query_summary'];
    if (summary is! Map<String, dynamic>) return null;

    final positive = summary['total_positive'];
    final negative = summary['total_negative'];
    if (positive is! int || negative is! int) return null;
    if (positive + negative == 0) return null;

    final score = summary['review_score'];
    final description = summary['review_score_desc'];
    return SteamReviews(
      score: score is int ? score : 0,
      summary: description is String ? description : '',
      positive: positive,
      negative: negative,
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
  bool usesProxy() => _proxy().forCatalogs;

  HttpClient _client(Duration timeout) =>
      catalogHttpClient(_proxy(), timeout: timeout);

  Future<String> _httpFetch(Uri uri) async {
    try {
      return await _fetcher(const Duration(seconds: 10)).text(uri);
    } on SocketException catch (error) {
      throw SteamLookupException(_l.steamNoConnection(error.message));
    }
  }

  /// Запрос к Steam: клиент по флагу прокси, отказ — словами о Steam.
  HttpFetch _fetcher(Duration timeout, {int? limitBytes}) => HttpFetch(
    openClient: () => _client(timeout),
    describeStatus: (status) => SteamLookupException(_l.steamStatus(status)),
    limitBytes: limitBytes,
  );
}

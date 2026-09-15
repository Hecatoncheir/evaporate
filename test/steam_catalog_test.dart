import 'package:evaporate/models/proxy_settings.dart';
import 'package:evaporate/services/metadata/steam_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Ответы Steam, снятые с настоящих запросов и урезанные до нужных полей.
  const searchBody = '''
  {"total": 3, "items": [
    {"id": 367520, "name": "Hollow Knight",
     "tiny_image": "https://cdn.steam/hk.jpg"},
    {"id": 1030300, "name": "Hollow Knight: Silksong",
     "tiny_image": "https://cdn.steam/silksong.jpg"},
    {"id": 598190, "name": "Hollow Knight - Official Soundtrack",
     "tiny_image": "https://cdn.steam/ost.jpg"}
  ]}''';

  const detailsBody = '''
  {"367520": {"success": true, "data": {
    "name": "Hollow Knight",
    "header_image": "https://cdn.steam/header.jpg",
    "short_description": "Исследуйте огромный разрушенный мир."
  }}}''';

  /// Кадры приходят тем же ответом, что описание: у настоящей игры их два
  /// десятка, здесь хватит трёх — и одного испорченного.
  const detailsWithShots = '''
  {"367520": {"success": true, "data": {
    "name": "Hollow Knight",
    "header_image": "https://cdn.steam/header.jpg",
    "screenshots": [
      {"id": 0, "path_thumbnail": "https://cdn.steam/ss0.600x338.jpg",
       "path_full": "https://cdn.steam/ss0.1920x1080.jpg"},
      {"id": 1, "path_thumbnail": "https://cdn.steam/ss1.600x338.jpg",
       "path_full": "https://cdn.steam/ss1.1920x1080.jpg"},
      {"id": 2, "path_full": "https://cdn.steam/ss2.1920x1080.jpg"},
      "мусор"
    ]
  }}}''';

  /// Клиент с подменённым транспортом: ни одного сетевого запроса.
  SteamCatalog catalogWith(Map<String, String> byPath) {
    return SteamCatalog(
      fetch: (uri) async {
        for (final entry in byPath.entries) {
          if (uri.path.contains(entry.key)) return entry.value;
        }
        throw SteamLookupException('неожиданный запрос: $uri');
      },
    );
  }

  group('разбор ответов', () {
    test('кадры берутся миниатюрами, а битые записи пропускаются', () {
      final game = SteamCatalog.parseDetails(detailsWithShots, 367520)!;

      // Полные 1920×1080 лежат в том же ответе и не нужны: подложка
      // показывает кадры размытыми, а весят они всемеро больше.
      expect(game.screenshots, [
        'https://cdn.steam/ss0.600x338.jpg',
        'https://cdn.steam/ss1.600x338.jpg',
      ]);
    });

    test('без кадров подборка пуста, а не сломана', () {
      final game = SteamCatalog.parseDetails(detailsBody, 367520)!;

      expect(game.screenshots, isEmpty);
      expect(game.name, 'Hollow Knight');
    });

    test('поиск даёт кандидатов с картинками', () {
      final found = SteamCatalog.parseSearch(searchBody);

      expect(found, hasLength(3));
      expect(found.first.appId, 367520);
      expect(found.first.name, 'Hollow Knight');
      expect(found.first.headerImage, 'https://cdn.steam/hk.jpg');
    });

    test('пустая выдача — это пустой список, а не ошибка', () {
      expect(SteamCatalog.parseSearch('{"total": 0, "items": []}'), isEmpty);
    });

    test('ответ без items не роняет разбор', () {
      expect(SteamCatalog.parseSearch('{"total": 0}'), isEmpty);
    });

    test('битые элементы пропускаются, годные остаются', () {
      const mixed = '''
      {"items": [
        {"id": "не число", "name": "Плохая"},
        {"name": "Без идентификатора"},
        {"id": 42, "name": "Хорошая"}
      ]}''';

      final found = SteamCatalog.parseSearch(mixed);

      expect(found, hasLength(1));
      expect(found.single.appId, 42);
    });

    test('не-json приводит к понятной ошибке', () {
      expect(
        () => SteamCatalog.parseSearch('<html>Cloudflare</html>'),
        throwsA(isA<SteamLookupException>()),
      );
    });

    test('подробности дают описание и обложку', () {
      final game = SteamCatalog.parseDetails(detailsBody, 367520);

      expect(game, isNotNull);
      expect(game!.headerImage, 'https://cdn.steam/header.jpg');
      expect(game.description, contains('разрушенный мир'));
    });

    test('неуспешный ответ подробностей даёт null', () {
      final game = SteamCatalog.parseDetails(
        '{"999": {"success": false}}',
        999,
      );
      expect(game, isNull);
    });

    test('чужой идентификатор в ответе игнорируется', () {
      expect(SteamCatalog.parseDetails(detailsBody, 111), isNull);
    });
  });

  group('итог обзоров', () {
    /// Ответ `appreviews`, снятый с настоящего запроса и урезанный.
    const reviewsBody = '''
    {"success": 1, "query_summary": {
      "num_reviews": 0,
      "review_score": 9,
      "review_score_desc": "Крайне положительные",
      "total_positive": 54551,
      "total_negative": 2374,
      "total_reviews": 56925
    }}''';

    test('счётчики и подпись доезжают как есть', () {
      final reviews = SteamCatalog.parseReviews(reviewsBody)!;

      expect(reviews.score, 9);
      expect(reviews.summary, 'Крайне положительные');
      expect(reviews.positive, 54551);
      expect(reviews.negative, 2374);
    });

    test('доля считается от обоих счётчиков', () {
      final reviews = SteamCatalog.parseReviews(reviewsBody)!;

      expect(reviews.total, 56925);
      expect(reviews.positiveShare, 96);
    });

    // «Ноль из нуля положительные» — утверждение об игре, которого никто не
    // делал. Отсутствие обзоров обязано выглядеть отсутствием оценки.
    test('игра без единого обзора оценки не получает', () {
      const empty = '''
      {"success": 1, "query_summary": {
        "review_score": 0, "review_score_desc": "Нет обзоров пользователей",
        "total_positive": 0, "total_negative": 0, "total_reviews": 0
      }}''';

      expect(SteamCatalog.parseReviews(empty), isNull);
    });

    test('отказ Steam даёт пустоту, а не выдуманный итог', () {
      expect(SteamCatalog.parseReviews('{"success": 2}'), isNull);
    });

    test('ответ без сводки не роняет разбор', () {
      expect(SteamCatalog.parseReviews('{"success": 1}'), isNull);
    });

    // Без этих трёх Steam считает обзоры на одном языке и только от
    // купивших у него же, а к итогу прикладывает два десятка полных
    // отзывов, которые мы всё равно выбросим.
    test('запрос просит общий итог и ни одного текста', () async {
      late Uri asked;
      final catalog = SteamCatalog(
        fetch: (uri) async {
          asked = uri;
          return reviewsBody;
        },
      );

      await catalog.reviews(367520);

      expect(asked.path, '/appreviews/367520');
      expect(asked.queryParameters['language'], 'all');
      expect(asked.queryParameters['purchase_type'], 'all');
      expect(asked.queryParameters['num_per_page'], '0');
    });
  });

  group('оценка прессы', () {
    test('приходит из подробностей вместе с описанием', () {
      const withScore = '''
      {"367520": {"success": true, "data": {
        "name": "Hollow Knight",
        "metacritic": {"score": 90, "url": "https://metacritic.invalid/hk"}
      }}}''';

      expect(SteamCatalog.parseDetails(withScore, 367520)!.metacritic, 90);
    });

    // У половины каталога Metacritic нет вовсе, и ноль баллов сказал бы о
    // таких играх ровно противоположное правде.
    test('её отсутствие — это отсутствие, а не ноль', () {
      expect(
        SteamCatalog.parseDetails(detailsBody, 367520)!.metacritic,
        isNull,
      );
    });
  });

  group('прокси для запросов Steam', () {
    SteamCatalog withProxy(ProxySettings proxy) =>
        SteamCatalog(proxy: () => proxy);

    // Своей настройки прокси у каталога больше нет: её применяет общий
    // перехват создания клиентов, а здесь остаётся только выбор — брать
    // перехваченного клиента или прямого. Что перехват работает, проверяет
    // `proxy_routing_test.dart` на настоящем SOCKS5.
    test('без прокси запросы идут напрямую', () {
      expect(withProxy(const ProxySettings()).usesProxy(), isFalse);
    });

    test('включённый прокси годится обоим видам', () {
      for (final kind in ProxyKind.values) {
        final catalog = withProxy(
          ProxySettings(
            enabled: true,
            kind: kind,
            host: 'proxy.local',
            port: 8080,
          ),
        );

        expect(catalog.usesProxy(), isTrue, reason: '$kind');
      }
    });

    test('выключённый для Steam прокси не применяется', () {
      final catalog = withProxy(
        const ProxySettings(
          enabled: true,
          host: 'proxy.local',
          port: 8080,
          useForSteam: false,
        ),
      );

      expect(
        catalog.usesProxy(),
        isFalse,
        reason:
            'качать через прокси и ходить в Steam напрямую — законное желание',
      );
    });

    test('незаполненный адрес прокси игнорируется', () {
      final catalog = withProxy(
        const ProxySettings(enabled: true, host: '   ', port: 8080),
      );

      expect(catalog.usesProxy(), isFalse);
    });
  });

  group('подбор игры по имени раздачи', () {
    test('имя раздачи приводится к названию и находит игру', () async {
      final catalog = catalogWith({
        'storesearch': searchBody,
        'appdetails': detailsBody,
      });

      final game = await catalog.bestMatch('Hollow.Knight.v1.5.78.11-GOG');

      expect(game, isNotNull);
      expect(game!.appId, 367520);
      // Подробности подмешаны к результату поиска.
      expect(game.description, contains('разрушенный мир'));
      expect(game.headerImage, 'https://cdn.steam/header.jpg');
    });

    test('саундтрек не подменяет саму игру', () async {
      final catalog = catalogWith({
        'storesearch': searchBody,
        'appdetails': detailsBody,
      });

      final game = await catalog.bestMatch('Hollow Knight');

      expect(
        game!.name,
        'Hollow Knight',
        reason: 'точное совпадение обязано выигрывать у дополнений',
      );
    });

    test('слишком непохожий результат отбрасывается', () async {
      final catalog = catalogWith({'storesearch': searchBody});

      final game = await catalog.bestMatch('Cyberpunk 2077');

      expect(
        game,
        isNull,
        reason: 'лучше ничего не предложить, чем подставить чужую игру',
      );
    });

    test('пустое имя не идёт в сеть', () async {
      final catalog = SteamCatalog(
        fetch: (uri) async => fail('запроса быть не должно'),
      );

      expect(await catalog.bestMatch('   '), isNull);
    });

    test('поиск по имени раздачи чистит его перед запросом', () async {
      Uri? requested;
      final catalog = SteamCatalog(
        fetch: (uri) async {
          requested = uri;
          return searchBody;
        },
      );

      await catalog.searchByRelease('The.Witcher.3.Wild.Hunt-ElAmigos');

      expect(requested!.queryParameters['term'], 'The Witcher 3 Wild Hunt');
    });

    test('ошибка сети пробрасывается вызывающему', () async {
      final catalog = SteamCatalog(
        fetch: (uri) async => throw SteamLookupException('нет связи'),
      );

      await expectLater(
        catalog.bestMatch('Hollow Knight'),
        throwsA(isA<SteamLookupException>()),
      );
    });
  });
}

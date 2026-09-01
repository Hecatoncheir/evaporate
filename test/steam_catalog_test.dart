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

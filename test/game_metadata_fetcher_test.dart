import 'dart:io';

import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/metadata/game_metadata_fetcher.dart';
import 'package:evaporate/services/metadata/steam_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Каталог, который отвечает тем, что задали, и считает, о чём спросили.
class _Steam extends SteamCatalog {
  _Steam();

  String? askedTitle;
  int? askedAppId;
  int imageCalls = 0;
  bool reviewsFail = false;

  SteamGame result = const SteamGame(
    appId: 42,
    name: 'Example',
    headerImage: 'https://example.invalid/header.jpg',
    metacritic: 86,
    screenshots: [
      'https://example.invalid/ss0.jpg',
      'https://example.invalid/ss1.jpg',
      'https://example.invalid/ss2.jpg',
    ],
  );

  @override
  Future<SteamGame?> bestMatch(
    String releaseName, {
    double minSimilarity = 0.6,
  }) async {
    askedTitle = releaseName;
    return result;
  }

  @override
  Future<SteamGame?> details(int appId) async {
    askedAppId = appId;
    return result;
  }

  @override
  Future<SteamReviews?> reviews(int appId) async {
    if (reviewsFail) throw const SocketException('offline');
    return const SteamReviews(
      score: 8,
      summary: 'Очень положительные',
      positive: 90,
      negative: 10,
    );
  }

  @override
  Future<List<int>?> coverBytes(SteamGame game) async => [1, 2, 3];

  @override
  Future<List<int>?> imageBytes(String url) async {
    imageCalls++;
    return [imageCalls];
  }
}

/// Цепочка «название → `appid` → обложка, кадры и оценка» целиком, без
/// состояния библиотеки и без сети.
void main() {
  late _Steam steam;

  setUp(() => steam = _Steam());

  Game game({int? appId}) => Game(
    id: 'g1',
    title: 'Example',
    addedAt: DateTime(2026),
    steamAppId: appId,
  );

  test('без известного appid спрашивают по названию', () async {
    await GameMetadataFetcher(steam).fetch(game());

    expect(steam.askedTitle, 'Example');
    expect(steam.askedAppId, isNull);
  });

  // Поиск по названию тут не лишний, а вредный: он способен ответить
  // другой игрой, и тогда игре достались бы чужие сейвы.
  test('известный appid спрашивают прямо по нему', () async {
    await GameMetadataFetcher(steam).fetch(game(appId: 42));

    expect(steam.askedAppId, 42);
    expect(steam.askedTitle, isNull);
  });

  test('имя раздачи спрашивают вместо названия, когда оно есть', () async {
    await GameMetadataFetcher(steam).fetch(game(), query: 'Example.RePack');

    expect(steam.askedTitle, 'Example.RePack');
  });

  test('оценка собирается из обзоров и Metacritic', () async {
    final found = await GameMetadataFetcher(steam).fetch(game());

    expect(found!.rating.summary, 'Очень положительные');
    expect(found.rating.positive, 90);
    expect(found.rating.metacritic, 86);
  });

  // Промолчи Steam об обзорах — игра всё равно получит обложку, описание
  // и пути сохранений: терять их из-за числа рядом с оценкой не за что.
  test('отказ по обзорам не отменяет остального', () async {
    steam.reviewsFail = true;

    final found = await GameMetadataFetcher(steam).fetch(game());

    expect(found, isNotNull);
    expect(found!.coverBytes, [1, 2, 3]);
    expect(found.rating.summary, isNull);
  });

  test('кадров берут не больше, чем покажет подложка', () async {
    final found = await GameMetadataFetcher(steam, maxShots: 2).fetch(game());

    expect(found!.shots, hasLength(2));
  });

  test('не нашлось — и рассказывать нечего', () async {
    final found = await GameMetadataFetcher(_NothingFound()).fetch(game());

    expect(found, isNull);
  });

  // Заход идёт секунды, и за это время приложение могло начать
  // закрываться: доводить до конца то, чей ответ некому получить, незачем.
  test('отмена обрывает заход, а не доводит его до конца', () async {
    final found = await GameMetadataFetcher(steam)
        .fetch(game(), cancelled: () => true);

    expect(found, isNull);
    expect(steam.imageCalls, 0);
  });
}

class _NothingFound extends SteamCatalog {
  @override
  Future<SteamGame?> bestMatch(
    String releaseName, {
    double minSimilarity = 0.6,
  }) async => null;
}

import '../../models/game.dart';
import '../../models/game_rating.dart';
import 'steam_catalog.dart';

/// Всё, что Steam рассказал об игре за один заход.
class GameMetadata {
  const GameMetadata({
    required this.match,
    required this.rating,
    this.coverBytes,
    this.shots = const [],
  });

  final SteamGame match;

  /// Оценка игроков: доля положительных — из обзоров, Metacritic — из тех
  /// же `appdetails`, откуда пришло описание.
  final GameRating rating;

  /// Картинка обложки, если её удалось забрать.
  final List<int>? coverBytes;

  /// Кадры из игры, уже скачанные, в порядке показа.
  final List<List<int>> shots;
}

/// Ходит в Steam за всем, что знают об игре: `appid`, описание, обложка,
/// кадры и оценка игроков.
///
/// Отдельно от блока, потому что это сеть, а не состояние: блок только
/// спрашивает и раскладывает ответ. Прежде поход в Steam, запись файлов и
/// правка состояния лежали в одном обработчике на девяносто строк, и
/// проверить из них можно было лишь то, что переживёт настоящий HTTP.
class GameMetadataFetcher {
  const GameMetadataFetcher(this.steam, {this.maxShots = 5});

  final SteamCatalog steam;

  /// Сколько кадров забирать на игру. Больше подложка не покажет: она
  /// водит их по кругу, и на пятом обороте смотреть уже перестают, а файл
  /// на диске каждый лишний кадр занимает у каждой игры.
  final int maxShots;

  /// Спрашивает Steam об игре. `null` — не нашлось.
  ///
  /// [cancelled] спрашивают между запросами: заход идёт секунды, и за это
  /// время приложение могло начать закрываться. Тогда бросать поход
  /// дешевле, чем доводить до конца то, чей ответ уже некому получить.
  Future<GameMetadata?> fetch(
    Game game, {
    String? query,
    bool Function()? cancelled,
  }) async {
    bool stop() => cancelled?.call() ?? false;

    final match = await _askAbout(game, query);
    if (match == null || stop()) return null;

    final reviews = await _reviews(match.appId);
    if (stop()) return null;

    final coverBytes = await steam.coverBytes(match);
    if (stop()) return null;

    return GameMetadata(
      match: match,
      rating: GameRating(
        score: reviews?.score,
        summary: reviews?.summary,
        positive: reviews?.positive ?? 0,
        negative: reviews?.negative ?? 0,
        metacritic: match.metacritic,
      ),
      coverBytes: coverBytes,
      shots: await _shots(match, stop),
    );
  }

  /// Идентификатор уже известен — спрашиваем прямо по нему. Поиск по
  /// названию тут не только лишний, но и вреден: он способен ответить
  /// другой игрой.
  Future<SteamGame?> _askAbout(Game game, String? query) =>
      game.steamAppId != null
      ? steam.details(game.steamAppId!)
      : steam.bestMatch(query ?? game.title);

  /// Обзоры — отдельным запросом: в `appdetails` их нет вовсе.
  ///
  /// Своя попытка и свой отказ: промолчи Steam об обзорах, игра всё равно
  /// получит и обложку, и описание, и пути сохранений — терять их из-за
  /// числа рядом с оценкой не за что.
  Future<SteamReviews?> _reviews(int appId) async {
    try {
      return await steam.reviews(appId);
    } on Object {
      return null;
    }
  }

  Future<List<List<int>>> _shots(SteamGame match, bool Function() stop) async {
    final images = <List<int>>[];
    for (final url in match.screenshots.take(maxShots)) {
      if (stop()) break;
      final bytes = await steam.imageBytes(url);
      if (bytes != null) images.add(bytes);
    }
    return images;
  }
}

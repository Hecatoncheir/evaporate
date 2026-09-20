import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/json_store.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/catalog_progress.dart';
import '../../models/proxy_settings.dart';
import '../metadata/release_name.dart';
import '../system/http_fetch.dart';
import '../system/proxy_http_overrides.dart';
import 'ludusavi_manifest.dart';

/// Разобранный манифест и текст для кэша.
typedef _Parsed = ({LudusaviManifest manifest, String json});

/// Разбор в отдельном изоляте: манифест — это десятки тысяч записей,
/// в главном потоке такой разбор заморозил бы интерфейс на секунды.
///
/// В изоляте делается **всё** тяжёлое разом, включая кодирование кэша: оно
/// стоит ещё двух десятков миллисекунд, то есть кадра с лишним.
_Parsed _parseManifest(String source) {
  final manifest = LudusaviManifest.parse(source);
  return (manifest: manifest, json: jsonEncode(manifest.toJson()));
}

/// Чтение кэша — тоже в изоляте.
///
/// Три мегабайта JSON разбираются миллисекунд тридцать пять, а это два-три
/// подряд пропущенных кадра: анимация в это время видимо дёргается.
///
/// `null` означает испорченный кэш: разбирается он вдали от главного
/// потока, и бросать исключение через границу изолята ради этого незачем.
LudusaviManifest? _decodeManifest(String text) {
  try {
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic>) return null;
    return LudusaviManifest.fromJson(json);
  } on Object {
    return null;
  }
}

/// Доступ к базе известных путей сохранений.
///
/// Сама база в репозиторий не входит: манифест проекта Ludusavi (MIT)
/// скачивается по требованию и хранится в кэше приложения.
class LudusaviCatalog {
  LudusaviCatalog({
    required String cacheFile,
    Future<String> Function(Uri uri)? fetch,
    ProxySettings Function()? proxy,
    this.onProgress,
    L Function()? localizations,
  }) : // Кэш читает только приложение: отступы в нём — лишняя треть файла.
       _store = JsonStore(cacheFile, pretty: false),
       _localizations = localizations ?? _defaultLocalizations,
       _proxy = proxy ?? _noProxy {
    _fetch = fetch;
  }

  /// Куда сообщать о ходе работы. Манифест весит семнадцать мегабайт,
  /// а разбор занимает секунды — без указателя это выглядит зависанием.
  ///
  /// Поле изменяемое: блок подключается к нему уже после создания
  /// каталога, потому что в списке инициализации события слать некуда.
  void Function(CatalogProgress)? onProgress;

  /// Откуда брать переводы: ошибка загрузки доходит до пользователя
  /// уведомлением, а `BuildContext` здесь взять неоткуда.
  final L Function() _localizations;

  L get _l => _localizations();

  static L _defaultLocalizations() => LRu();

  final JsonStore _store;
  final ProxySettings Function() _proxy;
  late final Future<String> Function(Uri uri)? _fetch;

  LudusaviManifest? _manifest;
  Future<bool>? _loading;

  static ProxySettings _noProxy() => const ProxySettings();

  bool get isLoaded => _manifest != null;

  int get entryCount => _manifest?.entries.length ?? 0;

  /// Читает базу из кэша; при [refresh] или пустом кэше — скачивает заново.
  Future<bool> ensureLoaded({bool refresh = false}) {
    if (_manifest != null && !refresh) return Future.value(true);
    return _loading ??= _load(refresh: refresh)
        .whenComplete(() => _loading = null);
  }

  Future<bool> _load({required bool refresh}) async {
    if (!refresh) {
      final text = await _store.readText();
      if (text != null) {
        final cached = await compute(_decodeManifest, text);
        if (cached != null) {
          _manifest = cached;
          _steamIndex = null;
          return true;
        }
        // Кэш испорчен — сохраняем его рядом и качаем заново.
        await _store.quarantine();
      }
    }

    final source = await _download();
    onProgress?.call(CatalogProgress.parsing);
    final parsed = await compute(_parseManifest, source);
    _manifest = parsed.manifest;
    _steamIndex = null;
    await _store.writeText(parsed.json);
    return true;
  }

  /// При известном Steam ID ищет только по нему: совпадение названия
  /// другой игры не должно подставлять чужие сохранения.
  LudusaviEntry? find({required String title, int? steamAppId}) {
    final manifest = _manifest;
    if (manifest == null) return null;

    if (steamAppId != null) return _bySteamId[steamAppId];

    final needle = ReleaseName.clean(title);
    if (needle.isEmpty) return null;
    return ReleaseName.bestMatch(
      manifest.entries.where((entry) => !entry.isEmpty),
      needle,
      titleOf: (entry) => entry.title,
      // Порог выше, чем у поиска в Steam: здесь ответ подставляет игре
      // чужие сохранения, а чужие пути хуже, чем никакие.
      minSimilarity: 0.75,
    );
  }

  /// Записи по Steam ID.
  ///
  /// Строится по первой надобности и живёт, пока жив манифест: записей в
  /// нём десятки тысяч, а спрашивают по одной на каждую игру библиотеки —
  /// линейный проход означал бы сорок проходов по сорока тысячам записей
  /// подряд, на загрузке библиотеки.
  Map<int, LudusaviEntry> get _bySteamId {
    final ready = _steamIndex;
    if (ready != null) return ready;

    final index = <int, LudusaviEntry>{};
    for (final entry in _manifest?.entries ?? const <LudusaviEntry>[]) {
      final id = entry.steamId;
      if (id == null || entry.isEmpty) continue;
      // Первая выигрывает — так же вёл себя и прежний проход по списку.
      index.putIfAbsent(id, () => entry);
    }
    return _steamIndex = index;
  }

  Map<int, LudusaviEntry>? _steamIndex;

  Future<String> _download() async {
    final override = _fetch;
    if (override != null) return override(Uri.parse(LudusaviManifest.source));

    // Читаем кусками, а не целиком: иначе о ходе загрузки сказать нечего,
    // а ждать пришлось бы молча — манифест весит семнадцать мегабайт.
    final bytes =
        await HttpFetch(
          // Прокси применяет общий перехват; здесь остаётся только выбор,
          // брать перехваченного клиента или прямого.
          openClient: () =>
              catalogHttpClient(_proxy(), timeout: const Duration(seconds: 20)),
          describeStatus: (status) =>
              HttpException(_l.pathsDatabaseUnavailable(status)),
        ).bytes(
          Uri.parse(LudusaviManifest.source),
          onProgress: (received, total) => onProgress?.call(
            CatalogProgress(
              phase: CatalogPhase.downloading,
              received: received,
              total: total,
            ),
          ),
        );
    return utf8.decode(bytes);
  }
}

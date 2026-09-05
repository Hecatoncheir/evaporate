import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/json_store.dart';
import '../../models/catalog_progress.dart';
import '../../models/proxy_settings.dart';
import '../metadata/release_name.dart';
import 'ludusavi_manifest.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';

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

  /// Как часто сообщать о ходе загрузки.
  static const _progressInterval = Duration(milliseconds: 100);

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
    await _store.writeText(parsed.json);
    return true;
  }

  /// При известном Steam ID ищет только по нему: совпадение названия
  /// другой игры не должно подставлять чужие сохранения.
  LudusaviEntry? find({required String title, int? steamAppId}) {
    final manifest = _manifest;
    if (manifest == null) return null;

    if (steamAppId != null) {
      for (final entry in manifest.entries) {
        if (entry.steamId == steamAppId && !entry.isEmpty) return entry;
      }
      return null;
    }

    final needle = ReleaseName.clean(title);
    if (needle.isEmpty) return null;

    LudusaviEntry? best;
    var bestScore = 0.0;
    for (final entry in manifest.entries) {
      if (entry.isEmpty) continue;
      final score = ReleaseName.similarity(needle, entry.title);
      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }
    // Порог тот же, что и у поиска в Steam: чужие пути хуже, чем никакие.
    return bestScore >= 0.75 ? best : null;
  }

  Future<String> _download() async {
    final override = _fetch;
    if (override != null) return override(Uri.parse(LudusaviManifest.source));

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    _applyProxy(client);
    try {
      final request = await client.getUrl(Uri.parse(LudusaviManifest.source));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException(_l.pathsDatabaseUnavailable(response.statusCode));
      }
      // Читаем кусками, а не целиком: иначе о ходе загрузки сказать
      // нечего, а ждать пришлось бы молча.
      //
      // Копим в BytesBuilder, а не в List<int>: манифест весит семнадцать
      // мегабайт, и растущий список чисел стоил бы под полгигабайта — в нём
      // каждый байт занимает машинное слово, да ещё удваивается при росте.
      final total = response.contentLength;
      final builder = BytesBuilder(copy: false);

      // О ходе сообщаем не чаще десяти раз в секунду. Кусков приходит
      // несколько сотен, каждый поднимал событие блока и перерисовку — то
      // есть сотни кадров работы там, где глазу хватает десятка в секунду.
      // Ровно от этого и дёргалась анимация на фоне.
      var reported = DateTime.now();
      void report() {
        onProgress?.call(
          CatalogProgress(
            phase: CatalogPhase.downloading,
            received: builder.length,
            total: total > 0 ? total : 0,
          ),
        );
      }

      await for (final chunk in response) {
        builder.add(chunk);
        final now = DateTime.now();
        if (now.difference(reported) < _progressInterval) continue;
        reported = now;
        report();
      }
      // Последний отчёт обязателен: без него полоса замирает, не дойдя
      // до конца, и выглядит это как оборванная загрузка.
      report();
      return utf8.decode(builder.takeBytes());
    } finally {
      client.close(force: true);
    }
  }

  void _applyProxy(HttpClient client) {
    final proxy = _proxy();
    if (!proxy.isUsable || !proxy.useForSteam) return;
    if (proxy.kind != ProxyKind.http) return;

    final host = proxy.host.trim().replaceFirst(RegExp(r'^\w+://'), '');
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

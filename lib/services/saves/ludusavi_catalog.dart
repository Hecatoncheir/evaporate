import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/json_store.dart';
import '../../models/catalog_progress.dart';
import '../../models/proxy_settings.dart';
import '../metadata/release_name.dart';
import 'ludusavi_manifest.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';

/// Разбор в отдельном изоляте: манифест — это десятки тысяч записей,
/// в главном потоке такой разбор заморозил бы интерфейс на секунды.
Map<String, dynamic> _parseManifest(String source) =>
    LudusaviManifest.parse(source).toJson();

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
  }) : _store = JsonStore(cacheFile),
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
      final cached = await _store.readAs(LudusaviManifest.fromJson);
      if (cached != null) {
        _manifest = cached;
        return true;
      }
    }

    final source = await _download();
    onProgress?.call(CatalogProgress.parsing);
    final json = await compute(_parseManifest, source);
    _manifest = LudusaviManifest.fromJson(json);
    await _store.write(json);
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
      final total = response.contentLength;
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        onProgress?.call(
          CatalogProgress(
            phase: CatalogPhase.downloading,
            received: bytes.length,
            total: total > 0 ? total : 0,
          ),
        );
      }
      return utf8.decode(bytes);
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

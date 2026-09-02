import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';

/// Версия приложения.
///
/// Держится константой, а не читается из пакета: иначе понадобилась бы
/// отдельная зависимость ради одной строки. От расхождения с pubspec.yaml
/// стережёт тест — он сверяет их при каждом прогоне.
class AppVersion {
  const AppVersion._();

  static const current = '0.5.0';

  /// Разбирает `1.2.3` или `v1.2.3` в числа. Лишнее после третьего числа
  /// (`-beta`, `+2`) отбрасывается: для сравнения оно роли не играет.
  static List<int>? parse(String value) {
    final cleaned = value.trim().replaceFirst(RegExp('^[vV]'), '');
    final core = cleaned.split(RegExp(r'[-+]')).first;
    final parts = core.split('.');
    if (parts.isEmpty || parts.length > 3) return null;

    final numbers = <int>[];
    for (final part in parts) {
      final number = int.tryParse(part.trim());
      if (number == null || number < 0) return null;
      numbers.add(number);
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return numbers;
  }

  /// Больше нуля, если [a] новее [b]. `null`, если сравнивать нечего.
  static int? compare(String a, String b) {
    final left = parse(a);
    final right = parse(b);
    if (left == null || right == null) return null;
    for (var i = 0; i < 3; i++) {
      final diff = left[i].compareTo(right[i]);
      if (diff != 0) return diff;
    }
    return 0;
  }

  static bool isNewer(String candidate, String than) =>
      (compare(candidate, than) ?? 0) > 0;
}

/// Вышедшая версия.
class Release extends Equatable {
  const Release({
    required this.version,
    required this.url,
    this.notes = '',
    this.publishedAt,
  });

  final String version;
  final String url;
  final String notes;
  final DateTime? publishedAt;

  @override
  List<Object?> get props => [version, url, notes, publishedAt];
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Проверка, не вышла ли версия новее установленной.
///
/// Приложение ничего не скачивает и не ставит само: оно только сообщает, что
/// обновление есть, и даёт ссылку. Молчаливое самообновление на десктопе —
/// сюрприз, которого никто не просил, а на Linux ещё и не сработает: там
/// приложение может лежать в системной папке без прав на запись.
class UpdateCheck {
  UpdateCheck({
    String? currentVersion,
    this._fetch,
    this.releasesUrl = _defaultUrl,
    L Function()? localizations,
  }) : current = currentVersion ?? AppVersion.current,
       _localizations = localizations ?? _defaultLocalizations;

  /// Откуда брать переводы: сообщения отсюда доходят до пользователя
  /// уведомлениями, а `BuildContext` здесь взять неоткуда.
  final L Function() _localizations;

  L get _l => _localizations();

  static L _defaultLocalizations() => LRu();

  static const _defaultUrl =
      'https://api.github.com/repos/Hecatoncheir/evaporate/releases/latest';

  final String current;
  final String releasesUrl;
  final Future<String> Function(Uri uri)? _fetch;

  /// Возвращает вышедшую версию или `null`, если установлена свежая.
  Future<Release?> latest() async {
    final body = await _load(Uri.parse(releasesUrl));
    final release = parseRelease(body);
    if (release == null) return null;
    return AppVersion.isNewer(release.version, current) ? release : null;
  }

  /// Разбирает ответ GitHub. Черновики и предрелизы пропускаем: их выкладывают
  /// не для того, чтобы на них звали пользователей.
  static Release? parseRelease(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw UpdateCheckException(_defaultLocalizations().updateBadAnswer);
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['draft'] == true || decoded['prerelease'] == true) return null;

    final tag = decoded['tag_name'];
    if (tag is! String || AppVersion.parse(tag) == null) return null;

    return Release(
      version: tag,
      url: decoded['html_url'] as String? ?? '',
      notes: decoded['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(decoded['published_at'] as String? ?? ''),
    );
  }

  Future<String> _load(Uri uri) async {
    final override = _fetch;
    if (override != null) return override(uri);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri);
      // Без заголовка версии GitHub может ответить иначе, чем ожидается.
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'Evaporate/$current');
      final response = await request.close();
      if (response.statusCode != 200) {
        throw UpdateCheckException(_l.updateUnavailable(response.statusCode));
      }
      // Без await клиент закроется раньше, чем дочитается тело.
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }
}

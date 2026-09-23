import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import 'http_fetch.dart';
import 'proxy_http_overrides.dart';

/// Версия приложения.
///
/// Задаётся при сборке, а не правится в коде: её знает CI по имени тега.
///
///     flutter build macos --release --dart-define=EVAPORATE_VERSION=1.2.3
///
/// Раньше она лежала здесь константой и ещё раз в `pubspec.yaml`, а тест
/// сторожил их совпадение — то есть выпуск версии начинался с правки трёх
/// файлов, из которых два ничего не решают. Теперь решает тег.
class AppVersion {
  const AppVersion._();

  /// Версия сборки, собранной не по тегу: своей, с машины разработчика.
  /// Та же, что в `pubspec.yaml`, — и там, и здесь она значит «не релиз».
  ///
  /// Обновиться такая сборка предложит: нули старше любого выпуска. Это не
  /// недосмотр — так единственный путь обновления виден и на своей машине,
  /// а не только у того, кто уже поставил релиз.
  static const dev = '0.0.0';

  static const current = String.fromEnvironment(
    'EVAPORATE_VERSION',
    defaultValue: dev,
  );

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
/// Файл, приложенный к релизу.
class ReleaseAsset extends Equatable {
  const ReleaseAsset({
    required this.name,
    required this.url,
    required this.sizeBytes,
  });

  final String name;
  final String url;
  final int sizeBytes;

  @override
  List<Object?> get props => [name, url, sizeBytes];
}

class Release extends Equatable {
  const Release({
    required this.version,
    required this.url,
    this.notes = '',
    this.publishedAt,
    this.assets = const [],
  });

  final String version;
  final String url;
  final String notes;
  final DateTime? publishedAt;

  /// Приложенные файлы релиза.
  final List<ReleaseAsset> assets;

  /// Хвост имени файла обновления для системы.
  ///
  /// Windows получает setup, а не zip: его можно запустить напрямую и
  /// закрыть приложение, не оставляя между ними ненадёжный PowerShell-
  /// помощник. macOS и Linux по-прежнему заменяют папку из архива.
  ///
  /// У Linux хвост сменён нарочно, и прежний (`-linux.tar.gz`) в релизы
  /// больше не кладут. Замену выполняет помощник **установленной** сборки, а
  /// помощник до 0.38 удалял папку с исполняемым файлом, не проверяя, чья
  /// она, — у распаковавших архив в «Загрузки» это «Загрузки». Новой
  /// сборкой его не починить. Не найдя своего файла, старая сборка просто
  /// не предлагает обновиться, и новую человек ставит руками — уже с
  /// защитой.
  static String? updateSuffix(String platformKey) => switch (platformKey) {
    'macos' => '-macos.zip',
    'windows' => '-windows-setup.exe',
    'linux' => '-linux-x64.tar.gz',
    _ => null,
  };

  /// Файл, которым эта система обновляется.
  ReleaseAsset? updateFor(String platformKey) {
    final suffix = updateSuffix(platformKey);
    if (suffix == null) return null;
    for (final asset in assets) {
      if (asset.name.endsWith(suffix)) return asset;
    }
    return null;
  }

  ReleaseAsset? get updateForThisPlatform => updateFor(currentPlatformKey());

  /// Файл контрольных сумм, которым проверяется скачанное.
  ///
  /// Канал защищён TLS, но оборванная загрузка выглядит как целый файл, и
  /// распаковывать её поверх установки нельзя.
  ReleaseAsset? get checksums {
    for (final asset in assets) {
      if (asset.name == 'SHA256SUMS') return asset;
    }
    return null;
  }

  @override
  List<Object?> get props => [version, url, notes, publishedAt, assets];
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Проверка, не вышла ли версия новее установленной.
///
/// Сама проверка только сообщает о новой версии. Скачивание и установку
/// запускает пользователь из экрана настроек.
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
    final Release? release;
    try {
      release = parseRelease(body);
    } on FormatException {
      throw UpdateCheckException(_l.updateBadAnswer);
    }
    if (release == null) return null;
    return AppVersion.isNewer(release.version, current) ? release : null;
  }

  /// Разбирает ответ GitHub. Черновики и предрелизы пропускаем: их выкладывают
  /// не для того, чтобы на них звали пользователей.
  ///
  /// Не JSON — `FormatException`, а слова к нему подбирает [latest]: разбор
  /// статикой ради тестов на записанных ответах, и языка у него нет. Прежде
  /// он брал русский по умолчанию, и английский интерфейс получал
  /// «Ответ о версиях не разобрать».
  static Release? parseRelease(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['draft'] == true || decoded['prerelease'] == true) return null;

    final tag = decoded['tag_name'];
    if (tag is! String || AppVersion.parse(tag) == null) return null;

    return Release(
      version: tag,
      url: decoded['html_url'] as String? ?? '',
      notes: decoded['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(decoded['published_at'] as String? ?? ''),
      assets: [
        for (final entry in decoded['assets'] as List<dynamic>? ?? const [])
          if (entry is Map<String, dynamic>)
            if (entry['name'] is String &&
                entry['browser_download_url'] is String)
              ReleaseAsset(
                name: entry['name'] as String,
                url: entry['browser_download_url'] as String,
                sizeBytes: entry['size'] as int? ?? 0,
              ),
      ],
    );
  }

  Future<String> _load(Uri uri) async {
    final override = _fetch;
    if (override != null) return override(uri);

    return HttpFetch(
      openClient: () =>
          updateHttpClient()..connectionTimeout = const Duration(seconds: 15),
      describeStatus: (status) =>
          UpdateCheckException(_l.updateUnavailable(status)),
      // Без заголовков GitHub может ответить иначе, чем ожидается.
      headers: {
        HttpHeaders.acceptHeader: 'application/vnd.github+json',
        HttpHeaders.userAgentHeader: 'Evaporate/$current',
      },
    ).text(uri);
  }
}

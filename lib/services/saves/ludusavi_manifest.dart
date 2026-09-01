import 'package:equatable/equatable.dart';
import 'package:yaml/yaml.dart';

import '../../core/format.dart';
import '../../core/save_path_template.dart';

/// Запись о том, где игра держит сохранения.
class LudusaviEntry extends Equatable {
  const LudusaviEntry({
    required this.title,
    required this.templates,
    this.steamId,
  });

  final String title;

  /// Пути в наших шаблонах — уже отфильтрованные по текущей платформе.
  final List<String> templates;

  /// Идентификатор в Steam, если он известен базе.
  final int? steamId;

  bool get isEmpty => templates.isEmpty;

  Map<String, dynamic> toJson() => {
    'title': title,
    'templates': templates,
    if (steamId != null) 'steamId': steamId,
  };

  factory LudusaviEntry.fromJson(Map<String, dynamic> json) => LudusaviEntry(
    title: json['title'] as String,
    templates: (json['templates'] as List<dynamic>)
        .map((e) => e.toString())
        .toList(),
    steamId: json['steamId'] as int?,
  );

  @override
  List<Object?> get props => [title, templates, steamId];
}

/// Разбор манифеста Ludusavi — открытой базы расположения сохранений.
///
/// Сама база в репозиторий не копируется: манифест скачивается и хранится
/// в кэше приложения. Здесь только разбор, фильтрация под текущую ОС и
/// перевод плейсхолдеров Ludusavi в наши шаблоны путей.
class LudusaviManifest {
  const LudusaviManifest(this.entries);

  final List<LudusaviEntry> entries;

  static const source =
      'https://raw.githubusercontent.com/mtkennerly/ludusavi-manifest/master/data/manifest.yaml';

  /// Плейсхолдеры базы в наши. То, чего в списке нет, мы развернуть не
  /// умеем — такие пути отбрасываются, чтобы не подсунуть мусор.
  static const _placeholders = {
    '<home>': SavePathTemplate.home,
    '<winAppData>': SavePathTemplate.appData,
    '<winLocalAppData>': SavePathTemplate.localAppData,
    '<winDocuments>': SavePathTemplate.documents,
    '<xdgData>': SavePathTemplate.appSupport,
    '<xdgConfig>': SavePathTemplate.appData,
  };

  /// Плейсхолдеры, которые зависят от учётной записи в магазине или от
  /// папки установки: подставить их вслепую нельзя.
  static const _unsupported = {
    '<base>',
    '<root>',
    '<game>',
    '<storeUserId>',
    '<osUserName>',
    '<winDir>',
    '<winProgramData>',
    '<winPublic>',
  };

  /// Переводит путь базы в наш шаблон. Возвращает null, если путь
  /// опирается на то, чего мы не знаем.
  static String? toTemplate(String rawPath) {
    var path = rawPath.trim().replaceAll(r'\', '/');
    if (path.isEmpty) return null;

    for (final placeholder in _unsupported) {
      if (path.contains(placeholder)) return null;
    }

    var replaced = false;
    for (final entry in _placeholders.entries) {
      if (!path.contains(entry.key)) continue;
      path = path.replaceAll(entry.key, entry.value);
      replaced = true;
    }
    if (!replaced) return null;

    // Маски вида `*` база использует для «любой профиль»; развернуть их
    // мы не умеем, а частичный путь только запутает.
    if (path.contains('*')) return null;

    return path.replaceAll(RegExp(r'/{2,}'), '/');
  }

  /// Разбирает манифест целиком. Тяжёлая операция: манифест — это десятки
  /// тысяч записей, поэтому вызывать её стоит в отдельном изоляте.
  static LudusaviManifest parse(String yamlSource, {String? platform}) {
    final os = platform ?? currentPlatformKey();
    final doc = loadYaml(yamlSource);
    if (doc is! YamlMap) return const LudusaviManifest([]);

    final entries = <LudusaviEntry>[];
    for (final item in doc.entries) {
      final title = item.key.toString();
      final game = item.value;
      if (game is! YamlMap) continue;

      final templates = _templatesFor(game['files'], os);
      final steamId = _steamId(game['steam']);
      if (templates.isEmpty && steamId == null) continue;

      entries.add(
        LudusaviEntry(title: title, templates: templates, steamId: steamId),
      );
    }
    return LudusaviManifest(entries);
  }

  static List<String> _templatesFor(Object? files, String os) {
    if (files is! YamlMap) return const [];

    final templates = <String>[];
    for (final file in files.entries) {
      final meta = file.value;
      if (meta is! YamlMap) continue;

      // Нас интересуют только сохранения: настройки и кэш переносить незачем.
      final tags = meta['tags'];
      if (tags is! YamlList || !tags.contains('save')) continue;
      if (!_matchesOs(meta['when'], os)) continue;

      final template = toTemplate(file.key.toString());
      if (template != null && !templates.contains(template)) {
        templates.add(template);
      }
    }
    return templates;
  }

  /// Пустое условие означает «на всех системах».
  static bool _matchesOs(Object? when, String os) {
    if (when is! YamlList || when.isEmpty) return true;

    var sawOsConstraint = false;
    for (final constraint in when) {
      if (constraint is! YamlMap) continue;
      final value = constraint['os'];
      if (value == null) return true;
      sawOsConstraint = true;
      if (_osKey(value.toString()) == os) return true;
    }
    return !sawOsConstraint;
  }

  static String _osKey(String value) => switch (value.toLowerCase()) {
    'windows' => 'windows',
    'mac' || 'macos' || 'darwin' => 'macos',
    'linux' => 'linux',
    _ => value.toLowerCase(),
  };

  static int? _steamId(Object? steam) {
    if (steam is! YamlMap) return null;
    final id = steam['id'];
    if (id is int) return id;
    return int.tryParse('$id');
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory LudusaviManifest.fromJson(Map<String, dynamic> json) =>
      LudusaviManifest(
        (json['entries'] as List<dynamic>? ?? [])
            .map((e) => LudusaviEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

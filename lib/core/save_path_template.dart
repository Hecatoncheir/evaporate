import 'dart:io';

import 'package:path/path.dart' as p;

/// Перенос сейвов между устройствами держится на том, что мы храним не
/// абсолютный путь (`/Users/имя/Library/...`), а шаблон с плейсхолдером
/// (`{APPSUPPORT}/MyGame/Saves`). На другой машине — и на другой ОС — тот же
/// шаблон разворачивается в правильный локальный путь.
class SavePathTemplate {
  const SavePathTemplate._();

  static const home = '{HOME}';
  static const documents = '{DOCUMENTS}';
  static const appData = '{APPDATA}';
  static const localAppData = '{LOCALAPPDATA}';
  static const appSupport = '{APPSUPPORT}';
  static const savedGames = '{SAVEDGAMES}';

  /// Папка, в которую поставлена сама игра.
  ///
  /// Отличается от остальных: системные корни одинаковы для всех игр, а этот
  /// у каждой свой, и подставить его может только тот, кто знает, о какой
  /// игре речь. Переносимости это не мешает, а помогает — на другом
  /// устройстве игра лежит в другом месте, и шаблон разворачивается туда.
  ///
  /// Ради него и получилось отказаться от Ludusavi: в базе путей это
  /// `<base>`, самый частый плейсхолдер, и Ludusavi вычислял его, обходя
  /// папки Steam и GOG. Лончер, который сам поставил игру, знает его точно.
  static const game = '{GAME}';

  /// Порядок предпочтения при сворачивании, когда несколько
  /// плейсхолдеров указывают в одну и ту же папку. На macOS и Linux
  /// так и есть, а на Windows это уже разные папки: свернув путь в
  /// `{SAVEDGAMES}` вместо `{APPSUPPORT}`, мы отправили бы сейв не туда.
  /// Сортировка списка сама по себе тут не поможет — `List.sort`
  /// в Dart нестабилен, и выбор оказался бы случайным.
  static const _preference = [
    appSupport,
    appData,
    localAppData,
    savedGames,
    documents,
    home,
  ];

  /// Порядок важен: при сворачивании пути в шаблон выигрывает самый
  /// длинный (самый специфичный) префикс, поэтому список отсортирован
  /// по убыванию длины значения на этапе [collapse].
  static Map<String, String> get placeholders {
    final h = _home;
    if (Platform.isWindows) {
      final env = Platform.environment;
      return {
        appData: env['APPDATA'] ?? p.join(h, 'AppData', 'Roaming'),
        localAppData: env['LOCALAPPDATA'] ?? p.join(h, 'AppData', 'Local'),
        appSupport: env['APPDATA'] ?? p.join(h, 'AppData', 'Roaming'),
        savedGames: p.join(h, 'Saved Games'),
        documents: p.join(h, 'Documents'),
        home: h,
      };
    }
    if (Platform.isMacOS) {
      return {
        appSupport: p.join(h, 'Library', 'Application Support'),
        appData: p.join(h, 'Library', 'Application Support'),
        localAppData: p.join(h, 'Library', 'Application Support'),
        savedGames: p.join(h, 'Library', 'Application Support'),
        documents: p.join(h, 'Documents'),
        home: h,
      };
    }
    final xdgData =
        Platform.environment['XDG_DATA_HOME'] ?? p.join(h, '.local', 'share');
    final xdgConfig =
        Platform.environment['XDG_CONFIG_HOME'] ?? p.join(h, '.config');
    return {
      appSupport: xdgData,
      localAppData: xdgData,
      appData: xdgConfig,
      savedGames: xdgData,
      documents: p.join(h, 'Documents'),
      home: h,
    };
  }

  /// Нужна ли для разворачивания папка игры.
  static bool needsGameDir(String template) => template.contains(game);

  /// `{APPSUPPORT}/MyGame/Saves` -> `/Users/me/Library/Application Support/MyGame/Saves`
  ///
  /// [gameDir] — папка установки игры для `{GAME}`. Без неё такой шаблон
  /// останется неразвёрнутым; спрашивать [needsGameDir] нужно заранее.
  static String expand(String template, {String? gameDir}) {
    var result = template;
    if (gameDir != null) {
      result = result.replaceAll(game, gameDir.replaceAll(r'\', '/'));
    }
    placeholders.forEach((token, value) {
      result = result.replaceAll(token, value);
    });
    // Шаблоны всегда пишутся через `/`; на Windows приводим к разделителю ОС.
    if (Platform.isWindows) {
      result = result.replaceAll('/', r'\');
    }
    return p.normalize(result);
  }

  /// `/Users/me/Library/Application Support/MyGame/Saves` -> `{APPSUPPORT}/MyGame/Saves`
  ///
  /// Если путь не лежит ни под одним из известных корней, возвращается как есть:
  /// такой сейв просто не будет переносимым, и UI об этом предупредит.
  ///
  /// [gameDir] проверяется первым: путь внутри папки игры сворачивается в
  /// `{GAME}`, даже если та лежит в домашней папке. Иначе сейв рядом с игрой
  /// уехал бы в `{HOME}/...` и на другом устройстве, где игра стоит в другом
  /// месте, не нашёлся бы.
  static String collapse(String absolutePath, {String? gameDir}) {
    final normalized = p.normalize(absolutePath);
    if (gameDir != null) {
      final root = p.normalize(gameDir);
      if (p.equals(root, normalized)) return game;
      if (p.isWithin(root, normalized)) {
        final rest = p.relative(normalized, from: root);
        return '$game/${rest.replaceAll(r'\', '/')}';
      }
    }
    final entries = placeholders.entries.toList()
      ..sort((a, b) {
        // Сначала самый специфичный корень, затем — предпочтение.
        final byLength = b.value.length.compareTo(a.value.length);
        if (byLength != 0) return byLength;
        return _preference.indexOf(a.key).compareTo(_preference.indexOf(b.key));
      });
    for (final entry in entries) {
      if (p.isWithin(entry.value, normalized) ||
          p.equals(entry.value, normalized)) {
        final rest = p.relative(normalized, from: entry.value);
        if (rest == '.') return entry.key;
        return '${entry.key}/${rest.replaceAll(r'\', '/')}';
      }
    }
    return normalized;
  }

  static bool isPortable(String template) =>
      template.contains(game) || placeholders.keys.any(template.contains);

  static String get _home {
    final env = Platform.environment;
    if (Platform.isWindows) {
      return env['USERPROFILE'] ?? r'C:\';
    }
    return env['HOME'] ?? '/';
  }
}

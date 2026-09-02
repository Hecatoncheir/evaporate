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

  /// `{APPSUPPORT}/MyGame/Saves` -> `/Users/me/Library/Application Support/MyGame/Saves`
  static String expand(String template) {
    var result = template;
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
  static String collapse(String absolutePath) {
    final normalized = p.normalize(absolutePath);
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
      placeholders.keys.any(template.contains);

  static String get _home {
    final env = Platform.environment;
    if (Platform.isWindows) {
      return env['USERPROFILE'] ?? r'C:\';
    }
    return env['HOME'] ?? '/';
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../../core/save_path_template.dart';

/// Что установленный Ludusavi знает про одну игру.
class LudusaviLookup {
  const LudusaviLookup({
    required this.title,
    required this.templates,
    this.registryKeys = const [],
  });

  /// Название игры так, как его знает Ludusavi.
  final String title;

  /// Найденные пути, уже свёрнутые в наши шаблоны.
  final List<String> templates;

  /// Ветки реестра Windows. Переносить их мы не умеем, но и молчать нельзя:
  /// иначе пользователь решит, что забрал сейв целиком.
  final List<String> registryKeys;

  bool get isEmpty => templates.isEmpty;
}

class LudusaviCliException implements Exception {
  const LudusaviCliException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Запуск процесса отдельным типом: тесты обходятся без установленного
/// Ludusavi, а заодно проверяют сами аргументы запуска.
typedef ProcessRun = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Опрос установленного Ludusavi — открытого инструмента копирования сейвов.
///
/// Берём у него ровно то, чего не даёт один манифест: развёрнутые пути.
/// Ludusavi знает, где стоят игры и какие есть учётные записи магазинов,
/// поэтому разворачивает `<base>` и `<storeUserId>` — то, что при разборе
/// манифеста приходится отбрасывать как неразрешимое.
///
/// Зависимость мягкая: без Ludusavi всё работает как прежде, по манифесту.
class LudusaviCli {
  LudusaviCli({
    String? Function()? configuredPath,
    ProcessRun? run,
    this.timeout = const Duration(minutes: 2),
  }) : _configuredPath = configuredPath ?? _noPath,
       _run = run ?? _defaultRun;

  final String? Function() _configuredPath;
  final ProcessRun _run;

  /// Первый запуск может обновлять манифест, а опрос — обходить диски,
  /// поэтому ждём долго, но не бесконечно.
  final Duration timeout;

  String? _executable;
  bool _searched = false;
  String? _searchedWith;

  static String? _noPath() => null;

  /// Кодировку задаём явно: иначе на Windows системная кодировка портит
  /// названия игр, а с ними и весь JSON.
  static Future<ProcessResult> _defaultRun(String exe, List<String> args) =>
      Process.run(exe, args, stdoutEncoding: utf8, stderrEncoding: utf8);

  /// Аргументы опроса собраны в одном месте намеренно: `--preview` обязан
  /// присутствовать всегда, иначе вместо опроса выйдет настоящий бэкап.
  static List<String> previewArgs(String title) => [
    'backup',
    '--preview',
    '--api',
    '--force',
    title,
  ];

  static List<String> findArgs({required String title, int? steamAppId}) => [
    'find',
    '--api',
    if (steamAppId != null) ...['--steam-id', '$steamAppId'],
    if (steamAppId == null) ...['--normalized', title],
  ];

  /// Путь к исполняемому файлу или null, если Ludusavi не установлен.
  Future<String?> executable() async {
    final configured = _configuredPath()?.trim();
    // Путь могли задать в настройках уже после прошлого поиска.
    if (_searched && configured == _searchedWith) return _executable;

    _executable = null;
    for (final candidate in _candidates()) {
      if (await _works(candidate)) {
        _executable = candidate;
        break;
      }
    }
    _searched = true;
    _searchedWith = configured;
    return _executable;
  }

  Future<bool> get isAvailable async => await executable() != null;

  /// Сбрасывает найденный путь: настройки могли поменяться.
  void forget() {
    _executable = null;
    _searched = false;
    _searchedWith = null;
  }

  /// Спрашивает Ludusavi, где лежат сейвы игры.
  ///
  /// Возвращает null, если Ludusavi не установлен или игру не знает —
  /// это не ошибка, а повод вернуться к манифесту.
  Future<LudusaviLookup?> lookup({
    required String title,
    int? steamAppId,
  }) async {
    final exe = await executable();
    if (exe == null) return null;

    final canonical = await _resolveTitle(
      exe,
      title: title,
      steamAppId: steamAppId,
    );
    if (canonical == null) return null;

    final output = await _capture(exe, previewArgs(canonical));
    if (output == null) return null;

    final scan = parsePreview(output, title: canonical);
    return LudusaviLookup(
      title: canonical,
      templates: toTemplates(scan.files),
      registryKeys: scan.registry,
    );
  }

  /// Названия из ответа `find`, лучшее — первым.
  static List<String> parseFindTitles(String stdout) {
    final games = _decode(stdout)['games'];
    if (games is! Map) return const [];

    final entries = games.entries.toList()
      ..sort((a, b) => _score(b.value).compareTo(_score(a.value)));
    return [for (final entry in entries) entry.key.toString()];
  }

  /// Пути из ответа `backup --preview`.
  static PreviewScan parsePreview(String stdout, {String? title}) {
    final games = _decode(stdout)['games'];
    if (games is! Map || games.isEmpty) return const PreviewScan();

    final matched = games[title];
    final game = matched is Map
        ? matched
        : games.values.whereType<Map>().firstOrNull;
    if (game == null) return const PreviewScan();

    final files = <String>[];
    final entries = game['files'];
    if (entries is Map) {
      for (final entry in entries.entries) {
        final meta = entry.value;
        // Пропущенное и сбойное Ludusavi помечает само; тащить это к себе
        // незачем — в снимке окажется мусор или недоступный файл.
        if (meta is Map &&
            (meta['ignored'] == true || meta['failed'] == true)) {
          continue;
        }
        files.add(entry.key.toString());
      }
    }

    final registry = <String>[];
    final keys = game['registry'];
    if (keys is Map) {
      for (final key in keys.keys) {
        registry.add(key.toString());
      }
    }

    return PreviewScan(files: files, registry: registry);
  }

  /// Ludusavi отдаёт отдельные файлы, а правило удобнее держать на папке:
  /// тогда в снимок попадут и сейвы, появившиеся позже.
  static List<String> toTemplates(List<String> filePaths) {
    final collected = <String>[];
    for (final raw in filePaths) {
      if (raw.trim().isEmpty) continue;
      final normalized = p.normalize(raw.replaceAll(r'\', p.separator));
      final parent = SavePathTemplate.collapse(p.dirname(normalized));

      // Папка сама оказалась корнем — сейв лежит прямо в «Документах».
      // Забрать её целиком значило бы утащить в снимок всё подряд,
      // поэтому берём один файл.
      final template = _isBareRoot(parent)
          ? SavePathTemplate.collapse(normalized)
          : parent;

      if (!collected.contains(template)) collected.add(template);
    }
    return _withoutNested(collected);
  }

  /// Метка правила: по ней сейвы сопоставляются между устройствами,
  /// поэтому берём имя папки — оно устойчивее порядкового номера.
  static String labelFor(String template) {
    final name = p.basename(template);
    if (name.isEmpty || name.startsWith('{')) return 'Сохранения';
    return name;
  }

  Future<String?> _resolveTitle(
    String exe, {
    required String title,
    int? steamAppId,
  }) async {
    if (steamAppId != null) {
      final byId = await _firstTitle(
        exe,
        findArgs(title: title, steamAppId: steamAppId),
      );
      if (byId != null) return byId;
    }
    if (title.trim().isEmpty) return null;
    return _firstTitle(exe, findArgs(title: title));
  }

  Future<String?> _firstTitle(String exe, List<String> args) async {
    final output = await _capture(exe, args);
    if (output == null) return null;
    return parseFindTitles(output).firstOrNull;
  }

  /// Возвращает stdout либо null, если ответить было нечем.
  ///
  /// Ненайденная игра — это ненулевой код возврата и пустой stdout, а не
  /// сбой: сама документация просит проверять пустоту до разбора JSON.
  Future<String?> _capture(String exe, List<String> args) async {
    final ProcessResult result;
    try {
      result = await _run(exe, args).timeout(timeout);
    } on ProcessException catch (error) {
      throw LudusaviCliException(
        'Не удалось запустить Ludusavi: ${error.message}',
      );
    }

    final output = (result.stdout as String? ?? '').trim();
    if (output.isEmpty) return null;
    return output;
  }

  Iterable<String> _candidates() sync* {
    final configured = _configuredPath()?.trim();
    if (configured != null && configured.isNotEmpty) yield configured;
    yield Platform.isWindows ? 'ludusavi.exe' : 'ludusavi';
    yield* _commonLocations();
  }

  static Iterable<String> _commonLocations() sync* {
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    if (Platform.isWindows) {
      final local = Platform.environment['LOCALAPPDATA'];
      if (local != null) {
        yield p.join(local, 'Programs', 'ludusavi', 'ludusavi.exe');
      }
      if (home != null) {
        yield p.join(home, '.cargo', 'bin', 'ludusavi.exe');
        yield p.join(home, 'scoop', 'shims', 'ludusavi.exe');
      }
      return;
    }
    if (Platform.isMacOS) {
      yield '/opt/homebrew/bin/ludusavi';
      yield '/usr/local/bin/ludusavi';
    } else {
      yield '/usr/bin/ludusavi';
      yield '/usr/local/bin/ludusavi';
    }
    if (home != null) {
      yield p.join(home, '.cargo', 'bin', 'ludusavi');
      yield p.join(home, '.local', 'bin', 'ludusavi');
    }
  }

  Future<bool> _works(String candidate) async {
    try {
      final result = await _run(candidate, const [
        '--version',
      ]).timeout(const Duration(seconds: 10));
      return result.exitCode == 0;
    } on Object {
      // Нет такого файла, нет прав, зависание — для нас всё это одно и
      // то же: этим кандидатом воспользоваться нельзя.
      return false;
    }
  }

  static bool _isBareRoot(String template) =>
      SavePathTemplate.placeholders.keys.contains(template);

  /// Вложенные пути схлопываются: правило на папке уже забирает всё внутри.
  static List<String> _withoutNested(List<String> templates) {
    final sorted = [...templates]..sort((a, b) => a.length.compareTo(b.length));
    final kept = <String>[];
    for (final template in sorted) {
      final covered = kept.any(
        (parent) => template == parent || template.startsWith('$parent/'),
      );
      if (!covered) kept.add(template);
    }
    return kept;
  }

  static double _score(Object? game) {
    if (game is! Map) return 0;
    final score = game['score'];
    if (score is num) return score.toDouble();
    return 0;
  }

  static Map<String, dynamic> _decode(String source) {
    const failure = LudusaviCliException('Ludusavi ответил не в формате JSON');
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      throw failure;
    }
    if (json is Map<String, dynamic>) return json;
    throw failure;
  }
}

/// Разобранный ответ `backup --preview`.
class PreviewScan {
  const PreviewScan({this.files = const [], this.registry = const []});

  final List<String> files;
  final List<String> registry;
}

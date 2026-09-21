import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Папки, которые система держит там, где сама решила, а не там, где их
/// ждёт догадка по домашней папке.
///
/// «Документы», унесённые в OneDrive, — обычное дело на Windows 11, на
/// Linux они бывают `~/Документы`. Правило базы путей `{DOCUMENTS}/My
/// Games/X`, развёрнутое догадкой, указывало в папку, которой нет:
/// автоснимок молча отвечал «сейвов ещё нет», а восстановление с другого
/// устройства клало файлы туда, куда игра не смотрит, и рапортовало успех.
///
/// Спрашиваем один раз на старте (`AppPaths.init`) и отдаём в
/// `SavePathTemplate.useSystemFolders`. Не ответила система — остаётся
/// прежняя догадка по переменным окружения: она верна у большинства.
class SystemFolders {
  const SystemFolders._();

  /// Ключ реестра, где Windows держит пути папок пользователя.
  static const userShellFolders =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer'
      r'\User Shell Folders';

  /// Имя значения Saved Games — GUID папки `FOLDERID_SavedGames`.
  static const savedGamesValue = '{4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4}';

  /// «Документы» и Saved Games этой машины; `null` — не узнали.
  static Future<({String? documents, String? savedGames})> detect() async {
    return (
      documents: await _documents(),
      savedGames: Platform.isWindows ? await _windowsSavedGames() : null,
    );
  }

  /// `path_provider` спрашивает систему сам: на Windows — известную папку
  /// (с учётом переноса в OneDrive), на Linux — `xdg-user-dirs`.
  static Future<String?> _documents() async {
    try {
      return (await getApplicationDocumentsDirectory()).path;
    } on Object {
      return null;
    }
  }

  /// Saved Games `path_provider` не знает — читаем то же, что читает сама
  /// система, из реестра. `reg`, а не пакет с FFI: так уже читает
  /// автозапуск, и новой зависимости ради одного значения не нужно.
  static Future<String?> _windowsSavedGames() async {
    try {
      final result = await Process.run('reg', [
        'query',
        userShellFolders,
        '/v',
        savedGamesValue,
      ]);
      if (result.exitCode != 0) return null;
      final raw = regValue(result.stdout as String, savedGamesValue);
      if (raw == null) return null;
      final expanded = expandWindowsVariables(raw);
      if (expanded.contains('%')) return null;
      // Вывод `reg` идёт в кодовой странице консоли, и путь с кириллицей
      // может прочитаться криво. Кривой путь не существует — берём только
      // тот, что есть на диске.
      return await Directory(expanded).exists() ? expanded : null;
    } on Object {
      return null;
    }
  }

  /// Значение из вывода `reg query`: строка вида
  /// `    <имя>    REG_EXPAND_SZ    <значение>`.
  static String? regValue(String output, String name) {
    final pattern = RegExp(
      '^\\s*${RegExp.escape(name)}\\s+REG_(?:EXPAND_)?SZ\\s+(.+?)\\s*\$',
      caseSensitive: false,
      multiLine: true,
    );
    return pattern.firstMatch(output)?.group(1);
  }

  /// `%USERPROFILE%\Saved Games` → настоящий путь. Незнакомую переменную
  /// оставляем как есть, а такой путь не берётся вовсе: лучше прежняя
  /// догадка, чем папка с `%` в имени.
  static String expandWindowsVariables(
    String value, {
    Map<String, String>? environment,
  }) {
    final env = {
      for (final entry in (environment ?? Platform.environment).entries)
        entry.key.toUpperCase(): entry.value,
    };
    return value.replaceAllMapped(
      RegExp('%([^%]+)%'),
      (match) => env[match.group(1)!.toUpperCase()] ?? match.group(0)!,
    );
  }
}

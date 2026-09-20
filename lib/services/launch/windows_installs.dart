import 'dart:io';

import 'package:path/path.dart' as p;

/// Запись об установленной программе из реестра Windows.
class RegistryInstall {
  const RegistryInstall({required this.name, required this.installDir});

  final String name;
  final String installDir;
}

/// Программы, о которых знает реестр Windows.
///
/// Игры, поставленные обычным установщиком мимо всяких лончеров, иначе не
/// найти ничем: в папках Steam и GOG их нет, а искать по всему диску дорого
/// и бесполезно. Установщик же честно записывает `InstallLocation`.
///
/// Источник слабый и это важно: в тех же ветках лежит вообще всё
/// установленное — браузеры, драйверы, распространяемые пакеты. Отсеять их
/// наверняка нельзя, поэтому найденное здесь помечается неуверенным и в
/// окне поиска галочкой заранее не отмечается. Предложить лишнее не жалко,
/// добавить его молча — нельзя.
class WindowsInstalls {
  const WindowsInstalls._();

  /// Ветки, в которых Windows держит записи об установленном.
  ///
  /// Три, а не одна: `WOW6432Node` — тридцатидвухбитные программы на
  /// шестидесятичетырёхбитной системе, а `HKCU` — поставленные для одного
  /// пользователя, как это делает установщик GOG.
  static const roots = [
    r'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    r'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    r'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall',
  ];

  /// Места, где игр не бывает, а записей — сотни.
  static const _systemPaths = [
    r'\windows\',
    r'\common files\',
    r'\microsoft\',
    r'\windowsapps\',
    r'\system32\',
  ];

  /// Издатели, чьи записи заведомо не игры.
  static const _systemPublishers = [
    'microsoft',
    'intel',
    'nvidia',
    'advanced micro devices',
    'realtek',
    'oracle',
    'python software foundation',
  ];

  /// Читает записи об установленном.
  ///
  /// [run] подменяется в тестах: `reg` есть только на Windows, а прогон идёт
  /// на трёх системах.
  static Future<List<RegistryInstall>> installed({
    Future<ProcessResult> Function(String, List<String>)? run,
    bool checkExists = true,
  }) async {
    if (run == null && !Platform.isWindows) return const [];
    final exec = run ?? Process.run;

    // Ключ пути, приведённый к общему виду: один и тот же каталог в разных
    // ветвях реестра — это одна установка, а не две.
    final found = <String, RegistryInstall>{};
    for (final root in roots) {
      for (final entry in _parse(await _query(exec, root))) {
        if (checkExists && !await _exists(entry.installDir)) continue;
        found.putIfAbsent(
          p.normalize(entry.installDir).toLowerCase(),
          () => entry,
        );
      }
    }

    return found.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Вывод `reg query` по одной ветви.
  ///
  /// Сбой — пустая строка, а не отказ: ветви может не быть вовсе (у
  /// 32-битных записей на 64-битной системе своя), и это обычное дело, а
  /// не повод бросить обход остальных.
  static Future<String> _query(
    Future<ProcessResult> Function(String, List<String>) exec,
    String root,
  ) async {
    try {
      final result = await exec('reg', ['query', root, '/s']);
      return result.exitCode == 0 ? '${result.stdout}' : '';
    } on ProcessException {
      return '';
    }
  }

  /// Есть ли такая папка.
  ///
  /// Отдельно от `Directory.exists`, потому что путь из реестра бывает и
  /// вовсе не путём: на строку с недопустимыми для имени символами Windows
  /// отвечает не «нет такой папки», а ошибкой. Обход, дошедший до одной
  /// испорченной записи, дальше не шёл вовсе — а испорченная запись значит
  /// ровно то же, что и несуществующая папка: эту пропускаем, читаем
  /// следующую.
  static Future<bool> _exists(String path) async {
    try {
      return await Directory(path).exists();
    } on FileSystemException {
      return false;
    }
  }

  /// Снимает кавычки с пути.
  ///
  /// `InstallLocation` пишет установщик, а не Windows, и пишет как придётся:
  /// половина кладёт путь в кавычках, как в командной строке. `"C:\Games\X"`
  /// — не путь, и папка по нему не находится никогда.
  static String _unquoted(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 2) return trimmed;
    if (!trimmed.startsWith('"') || !trimmed.endsWith('"')) return trimmed;
    return trimmed.substring(1, trimmed.length - 1).trim();
  }

  /// Разбирает вывод `reg query ... /s`.
  ///
  /// Он идёт блоками: строка с путём ключа, затем строки его значений с
  /// отступом. Разделителем внутри строки значения служат подряд идущие
  /// пробелы, а не один: и в имени, и в значении пробелы встречаются.
  static List<RegistryInstall> _parse(String output) {
    final result = <RegistryInstall>[];
    var values = <String, String>{};

    void flush() {
      final entry = _entryOf(values);
      if (entry != null) result.add(entry);
      values = {};
    }

    for (final raw in output.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) continue;
      if (!line.startsWith(' ') && !line.startsWith('\t')) {
        // Новый ключ — предыдущий блок закончился.
        flush();
        continue;
      }
      final parts = line.trim().split(RegExp(r' {2,}|\t+'));
      if (parts.length < 2) continue;
      // Имя, тип, значение; значение бывает пустым.
      values[parts.first.toLowerCase()] = parts.length >= 3
          ? parts.sublist(2).join('    ')
          : '';
    }
    flush();
    return result;
  }

  static RegistryInstall? _entryOf(Map<String, String> values) {
    if (values['systemcomponent'] == '0x1') return null;
    final name = values['displayname'];
    final location = _unquoted(values['installlocation'] ?? '');
    if (name == null || name.isEmpty) return null;
    if (location.isEmpty) return null;

    final lower = location.toLowerCase().replaceAll('/', r'\');
    for (final skip in _systemPaths) {
      if (lower.contains(skip)) return null;
    }
    final publisher = values['publisher']?.toLowerCase() ?? '';
    for (final skip in _systemPublishers) {
      if (publisher.contains(skip)) return null;
    }
    // Обновления Windows записываются номером статьи базы знаний.
    if (RegExp(r'^KB\d{6,}').hasMatch(name)) return null;

    return RegistryInstall(name: name, installDir: location);
  }
}

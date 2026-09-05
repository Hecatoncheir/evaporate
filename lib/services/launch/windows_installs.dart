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

    final found = <String, RegistryInstall>{};
    for (final root in roots) {
      final ProcessResult result;
      try {
        result = await exec('reg', ['query', root, '/s']);
      } on ProcessException {
        continue;
      }
      if (result.exitCode != 0) continue;

      for (final entry in _parse('${result.stdout}')) {
        if (checkExists && !await Directory(entry.installDir).exists()) {
          continue;
        }
        found.putIfAbsent(p.normalize(entry.installDir).toLowerCase(), () {
          return entry;
        });
      }
    }

    final list = found.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
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
    final location = values['installlocation'];
    if (name == null || name.isEmpty) return null;
    if (location == null || location.isEmpty) return null;

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

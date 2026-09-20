import 'dart:io';

import 'package:path/path.dart' as p;

import 'steam_install.dart';
import 'vdf.dart';

/// Учётная запись Steam на этой машине.
class SteamProfile {
  const SteamProfile({required this.accountId, required this.configDir});

  /// Номер папки в `userdata` — он же `steamID64` минус смещение Valve.
  final String accountId;

  /// `userdata/<accountId>/config`.
  final String configDir;

  String get shortcutsFile => p.join(configDir, 'shortcuts.vdf');

  /// Сюда Steam кладёт обложки, назначенные вручную.
  String get gridDir => p.join(configDir, 'grid');
}

/// Учётные записи Steam на этой машине.
///
/// Своим файлом, потому что это чтение чужих папок и `loginusers.vdf`, а
/// не запись ярлыков: кому класть игру — вопрос, у которого свой ответ.
class SteamProfiles {
  const SteamProfiles({this.roots});

  /// Где искать Steam. Подменяется в тестах: настоящей установки на машине
  /// прогона нет, а на трёх системах она лежит в трёх разных местах.
  final List<String>? roots;

  /// `steamID64` начинается с этого числа; номер папки в `userdata` — это
  /// остаток. Связь нужна, чтобы сопоставить папку с записью в
  /// `loginusers.vdf` и понять, под кем человек сидел последним.
  static const _steamIdOffset = 76561197960265728;

  /// Все учётные записи, заходившие на этой машине.
  Future<List<SteamProfile>> all() async {
    final found = <SteamProfile>[];
    for (final root in roots ?? SteamInstall.defaultRoots()) {
      final userdata = Directory(p.join(root, 'userdata'));
      if (!await userdata.exists()) continue;
      for (final entity in await userdata.list(followLinks: false).toList()) {
        if (entity is! Directory) continue;
        final id = p.basename(entity.path);
        // `ls` в `userdata` показывает и служебные папки вроде `ac`.
        if (int.tryParse(id) == null) continue;
        final config = Directory(p.join(entity.path, 'config'));
        if (!await config.exists()) continue;
        found.add(SteamProfile(accountId: id, configDir: config.path));
      }
    }
    return found;
  }

  /// Под какой записью сидели последней — из `config/loginusers.vdf`.
  ///
  /// Нужно только тогда, когда записей несколько: гадать, в чью библиотеку
  /// класть игру, нельзя, а спрашивать ради единственной — назойливо.
  Future<String?> mostRecentAccount() async {
    for (final root in roots ?? SteamInstall.defaultRoots()) {
      final text = await _loginUsers(root);
      if (text == null) continue;
      final recent = _recentIn(text);
      if (recent != null) return recent;
    }
    return null;
  }

  /// Содержимое `config/loginusers.vdf`, если его удалось прочитать.
  Future<String?> _loginUsers(String root) async {
    final file = File(p.join(root, 'config', 'loginusers.vdf'));
    if (!await file.exists()) return null;
    try {
      return await file.readAsString();
    } on FileSystemException {
      return null;
    }
  }

  /// Номер записи, помеченной `MostRecent`.
  static String? _recentIn(String text) {
    final users = Vdf.map(Vdf.parse(text), ['users']);
    if (users == null) return null;
    for (final entry in users.entries) {
      final value = entry.value;
      if (value is! Map<String, Object>) continue;
      if (value['MostRecent'] != '1') continue;
      final id64 = int.tryParse(entry.key);
      if (id64 != null) return '${id64 - _steamIdOffset}';
    }
    return null;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/game.dart';
import 'binary_vdf.dart';
import 'steam_install.dart';
import 'vdf.dart';

/// Не вышло завести игру в Steam — с готовым объяснением для человека.
class SteamShortcutException implements Exception {
  SteamShortcutException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Витрина игры в библиотеке Steam — четыре картинки, каждая под своим
/// именем в папке `grid`.
///
/// Одной вертикальной обложки мало: ею Steam рисует только сетку
/// библиотеки. Полка «недавних» берёт горизонтальную плашку, а страница
/// игры — широкий задник с названием поверх. Положив одну, получаешь игру,
/// которая в сетке выглядит как все, а на своей странице — как пустой лист.
class SteamArtwork {
  const SteamArtwork({this.portrait, this.capsule, this.hero, this.logo});

  /// `<appid>p.jpg` — вертикальная, 2:3, для сетки библиотеки.
  final List<int>? portrait;

  /// `<appid>.jpg` — горизонтальная плашка для полок и списков.
  final List<int>? capsule;

  /// `<appid>_hero.jpg` — широкий задник страницы игры.
  final List<int>? hero;

  /// `<appid>_logo.png` — название игры картинкой поверх задника.
  final List<int>? logo;

  bool get isEmpty =>
      portrait == null && capsule == null && hero == null && logo == null;
}

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

/// Заводит игры в Steam как «сторонние» — то же, что его собственное
/// «Добавить стороннюю игру в мою библиотеку».
///
/// Никакого API у Steam для этого нет: список лежит у него в
/// `userdata/<id>/config/shortcuts.vdf`, двоичным VDF, и мы его
/// переписываем. Отсюда три правила, каждое из которых защищает чужое
/// добро, а не наше удобство:
///
/// * **не понял файл — не трогай.** [BinaryVdf.decode] бросает на всём
///   незнакомом, и отказ проходит наружу: переписать список, разобрав его
///   наполовину, значит стереть человеку ярлыки, которые он заводил сам;
/// * **перед записью — копия рядом.** Файл не наш, а откатиться иначе
///   нечем;
/// * **при запущенном Steam не писать вовсе.** Steam держит список в
///   памяти и выкладывает его на диск при выходе — наша запись исчезнет
///   молча, а человек решит, что кнопка не работает.
class SteamShortcuts {
  SteamShortcuts({
    this.roots,
    L Function()? localizations,
    Future<bool> Function()? steamRunning,
  }) : _localizations = localizations ?? _defaultLocalizations,
       _steamRunning = steamRunning ?? _probeSteam;

  /// Где искать Steam. Подменяется в тестах: настоящей установки на машине
  /// прогона нет, а на трёх системах она лежит в трёх разных местах.
  final List<String>? roots;
  final L Function() _localizations;
  final Future<bool> Function() _steamRunning;

  L get _l => _localizations();
  static L _defaultLocalizations() => LRu();

  /// `steamID64` начинается с этого числа; номер папки в `userdata` — это
  /// остаток. Связь нужна, чтобы сопоставить папку с записью в
  /// `loginusers.vdf` и понять, под кем человек сидел последним.
  static const _steamIdOffset = 76561197960265728;

  /// Все учётные записи, заходившие на этой машине.
  Future<List<SteamProfile>> profiles() async {
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
  Future<String?> _mostRecentAccount() async {
    for (final root in roots ?? SteamInstall.defaultRoots()) {
      final file = File(p.join(root, 'config', 'loginusers.vdf'));
      if (!await file.exists()) continue;
      final String text;
      try {
        text = await file.readAsString();
      } on FileSystemException {
        continue;
      }
      final users = Vdf.map(Vdf.parse(text), ['users']);
      if (users == null) continue;
      for (final entry in users.entries) {
        final value = entry.value;
        if (value is! Map<String, Object>) continue;
        if (value['MostRecent'] != '1') continue;
        final id64 = int.tryParse(entry.key);
        if (id64 == null) continue;
        return '${id64 - _steamIdOffset}';
      }
    }
    return null;
  }

  /// Куда класть ярлык. Одна запись — она и есть; несколько — та, под
  /// которой сидели последней.
  Future<SteamProfile> _target() async {
    final all = await profiles();
    if (all.isEmpty) throw SteamShortcutException(_l.steamNotFound);
    if (all.length == 1) return all.single;

    final recent = await _mostRecentAccount();
    final match = all.where((profile) => profile.accountId == recent);
    if (match.isEmpty) throw SteamShortcutException(_l.steamManyProfiles);
    return match.first;
  }

  /// Запущен ли Steam прямо сейчас.
  ///
  /// Подменяется в тестах: спрашивать систему о процессах на трёх ОС в
  /// прогоне негде, а ветку отказа проверить надо.
  static Future<bool> _probeSteam() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('tasklist', [
          '/NH',
          '/FI',
          'IMAGENAME eq steam.exe',
        ]);
        return '${result.stdout}'.toLowerCase().contains('steam.exe');
      }
      final result = await Process.run('pgrep', ['-x', 'steam']);
      return result.exitCode == 0;
    } on ProcessException {
      // Не спросили — не знаем. Запретить из-за этого единственный способ
      // добавить игру было бы хуже, чем понадеяться: худшее, что выйдет, —
      // запись пропадёт, и человек попробует ещё раз, уже закрыв Steam.
      return false;
    }
  }

  /// `appid` стороннего ярлыка.
  ///
  /// Steam назначает его сам и, судя по настоящему файлу, случайно: его
  /// значение не сошлось ни с одной из общепринятых формул, включая
  /// `crc32(Exe + AppName)`, которой пользуются сторонние инструменты. Нам
  /// он его и не назначает — что написали, то и примет.
  ///
  /// Поэтому число выбираем сами и выбираем **устойчивое**: от нашего же
  /// id игры, а не от пути к файлу. Перенесёт человек игру на другой диск и
  /// заведёт ярлык заново — число останется прежним, и положенные в `grid`
  /// обложки не осиротеют. Старший бит взведён: им Steam метит сторонние
  /// ярлыки, и у его собственной записи он стоял.
  static int appIdFor(String gameId) {
    final digest = sha256.convert(utf8.encode(gameId)).bytes;
    final value =
        (digest[0] << 24 | digest[1] << 16 | digest[2] << 8 | digest[3]) |
        0x80000000;
    return value.toSigned(32);
  }

  /// Имя файла обложки в `grid`.
  ///
  /// Steam различает их по имени: вертикальная витрина библиотеки — это
  /// `<appid>p.jpg`, горизонтальная плашка — `<appid>.jpg`. Наша обложка
  /// бывает и той и другой: каталог сначала просит `library_600x900`, а
  /// если её не нарисовали, берёт горизонтальную `header`. Положить
  /// горизонтальную под именем вертикальной — значит растянуть её на
  /// 600×900, и выглядит это хуже, чем пустая рамка.
  static String gridNameFor(int appId, List<int> cover) {
    final size = _imageSize(cover);
    final portrait = size == null || size.height >= size.width;
    final id = appId.toUnsigned(32);
    return portrait ? '${id}p.jpg' : '$id.jpg';
  }

  /// Заводит игру в Steam. Возвращает назначенный ей `appid`.
  ///
  /// Повторный вызов не плодит двойников: запись с тем же `appid`
  /// переписывается на месте.
  Future<int> addGame(Game game, {SteamArtwork? artwork}) async {
    final exe = game.executablePath;
    if (exe == null || exe.isEmpty) {
      throw SteamShortcutException(_l.launchNoExecutable);
    }
    if (await _steamRunning()) {
      throw SteamShortcutException(_l.steamIsRunning);
    }

    final profile = await _target();
    final document = await _read(profile);
    final shortcuts = document.putIfAbsent(
      'shortcuts',
      () => <String, Object>{},
    );
    if (shortcuts is! Map<String, Object>) {
      throw SteamShortcutException(_l.steamShortcutsUnreadable);
    }

    final appId = appIdFor(game.id);
    final entries = <Map<String, Object>>[];
    for (final value in shortcuts.values) {
      // Чужие записи переносим как есть, со всеми их полями: нам они
      // непонятны только на вид, а человеку это его ярлыки.
      if (value is Map<String, Object> && value['appid'] != appId) {
        entries.add(value);
      }
    }
    entries.add(_entryFor(game, appId: appId, exe: exe));

    await _write(profile, {
      ...document,
      // Нумеруем подряд: ключ здесь — порядковый номер, а не имя, и дырка
      // от переписанной записи была бы не находкой, а поводом гадать.
      'shortcuts': <String, Object>{
        for (var i = 0; i < entries.length; i++) '$i': entries[i],
      },
    });
    await _putArtwork(game, profile: profile, appId: appId, artwork: artwork);
    return appId;
  }

  Map<String, Object> _entryFor(
    Game game, {
    required int appId,
    required String exe,
  }) {
    // Рабочая папка — та же, куда смотрит наш собственный запуск: ярлык в
    // Steam обязан вести туда же, куда «Играть», иначе игра, ищущая файлы
    // рядом с собой, из Steam не заведётся.
    var startDir = game.installDir ?? p.dirname(exe);
    if (!startDir.endsWith(p.separator)) startDir += p.separator;

    // Порядок и набор полей — как у самого Steam, вплоть до кавычек:
    // `Exe` он берёт в кавычки, `StartDir` нет.
    return <String, Object>{
      'appid': appId,
      'AppName': game.title,
      'Exe': '"$exe"',
      'StartDir': startDir,
      'icon': '',
      'ShortcutPath': '',
      'LaunchOptions': '',
      'IsHidden': 0,
      'AllowDesktopConfig': 1,
      'AllowOverlay': 1,
      'OpenVR': 0,
      'Devkit': 0,
      'DevkitGameID': '',
      'DevkitOverrideAppID': 0,
      'LastPlayTime': 0,
      'FlatpakAppID': '',
      'sortas': '',
      'tags': <String, Object>{},
    };
  }

  Future<Map<String, Object>> _read(SteamProfile profile) async {
    final file = File(profile.shortcutsFile);
    if (!await file.exists()) return <String, Object>{};
    try {
      return BinaryVdf.decode(await file.readAsBytes());
    } on FormatException {
      // Разобрали не всё — значит, и переписать не вправе.
      throw SteamShortcutException(_l.steamShortcutsUnreadable);
    } on FileSystemException catch (error) {
      throw SteamShortcutException(error.message);
    }
  }

  Future<void> _write(
    SteamProfile profile,
    Map<String, Object> document,
  ) async {
    final file = File(profile.shortcutsFile);
    await file.parent.create(recursive: true);

    // Копия прежнего рядом: файл чужой, и откатиться иначе нечем.
    if (await file.exists()) {
      try {
        await file.copy('${file.path}.evaporate.bak');
      } on FileSystemException {
        // Не вышло — значит, и записи не будет: без пути назад не лезем.
        throw SteamShortcutException(_l.steamShortcutsUnreadable);
      }
    }

    // Через временный файл и переименование: обрыв посреди записи не
    // должен оставить половину списка, которую Steam примет за целый.
    final tmp = File('${file.path}.evaporate.tmp');
    try {
      await tmp.writeAsBytes(BinaryVdf.encode(document), flush: true);
      await tmp.rename(file.path);
    } on Object {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }

  /// Одевает игру в Steam: кладёт в `grid` всё, что для неё есть.
  ///
  /// Витрина из каталога лучше нашей сохранённой обложки: её рисовали для
  /// этой самой игры и во всех четырёх видах. Своя идёт в ход, когда
  /// каталог не дал ничего, — игра могла прийти не из Steam вовсе, и тогда
  /// одна обложка лучше, чем пустая рамка.
  ///
  /// Неудача здесь ярлыка не отменяет: игра без обложки — это игра без
  /// обложки, а отказ ради неё означал бы «не добавили вовсе».
  Future<void> _putArtwork(
    Game game, {
    required SteamProfile profile,
    required int appId,
    required SteamArtwork? artwork,
  }) async {
    final id = appId.toUnsigned(32);
    final files = <String, List<int>>{};
    if (artwork != null) {
      if (artwork.portrait != null) files['${id}p.jpg'] = artwork.portrait!;
      if (artwork.capsule != null) files['$id.jpg'] = artwork.capsule!;
      if (artwork.hero != null) files['${id}_hero.jpg'] = artwork.hero!;
      if (artwork.logo != null) files['${id}_logo.png'] = artwork.logo!;
    }

    try {
      // Своей обложкой закрываем ту створку, которая осталась пустой:
      // класть её поверх присланной каталогом незачем.
      final cover = game.coverPath;
      if (cover != null && cover.isNotEmpty) {
        final source = File(cover);
        if (await source.exists()) {
          final bytes = await source.readAsBytes();
          files.putIfAbsent(gridNameFor(appId, bytes), () => bytes);
        }
      }

      if (files.isEmpty) return;
      final dir = Directory(profile.gridDir);
      await dir.create(recursive: true);
      for (final file in files.entries) {
        await File(p.join(dir.path, file.key))
            .writeAsBytes(file.value, flush: true);
      }
    } on FileSystemException {
      return;
    }
  }
}

/// Размеры картинки, прочитанные из заголовка.
class _ImageSize {
  const _ImageSize(this.width, this.height);

  final int width;
  final int height;
}

/// Ширина и высота JPEG или PNG без полного разбора картинки.
///
/// Обе с CDN Steam, других нам и не приносят. `null` — «не разобрали»;
/// вызывающий считает такую обложку вертикальной, потому что каталог
/// сначала просит именно вертикальную.
_ImageSize? _imageSize(List<int> bytes) {
  if (bytes.length > 24 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    // PNG: размеры лежат в IHDR, сразу за подписью, старшим байтом вперёд.
    final width =
        bytes[16] << 24 | bytes[17] << 16 | bytes[18] << 8 | bytes[19];
    final height =
        bytes[20] << 24 | bytes[21] << 16 | bytes[22] << 8 | bytes[23];
    return _ImageSize(width, height);
  }

  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
  // JPEG: идём по маркерам до любого из SOF — только там лежат размеры.
  var i = 2;
  while (i + 9 < bytes.length) {
    if (bytes[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = bytes[i + 1];
    // Заполнитель между маркерами и маркеры без полезной нагрузки.
    if (marker == 0xFF || (marker >= 0xD0 && marker <= 0xD9)) {
      i += 2;
      continue;
    }
    final length = bytes[i + 2] << 8 | bytes[i + 3];
    final isSof =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 && // таблица Хаффмана
        marker != 0xC8 && // расширение JPEG
        marker != 0xCC; // таблица арифметического кодирования
    if (isSof) {
      final height = bytes[i + 5] << 8 | bytes[i + 6];
      final width = bytes[i + 7] << 8 | bytes[i + 8];
      return _ImageSize(width, height);
    }
    if (length < 2) return null;
    i += 2 + length;
  }
  return null;
}

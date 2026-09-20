import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/game.dart';
import 'binary_vdf.dart';
import 'steam_grid.dart';
import 'steam_profiles.dart';

// Витрина и учётные записи уехали в свои файлы, но зовут их отсюда: у
// ярлыка они обе — часть одного дела.
export 'steam_grid.dart' show SteamArtwork;
export 'steam_profiles.dart' show SteamProfile;

/// Не вышло завести игру в Steam — с готовым объяснением для человека.
class SteamShortcutException implements Exception {
  SteamShortcutException(this.message);

  final String message;

  @override
  String toString() => message;
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
       _steamRunning = steamRunning ?? _probeSteam,
       _profiles = SteamProfiles(roots: roots);

  /// Где искать Steam. Подменяется в тестах: настоящей установки на машине
  /// прогона нет, а на трёх системах она лежит в трёх разных местах.
  final List<String>? roots;
  final L Function() _localizations;
  final Future<bool> Function() _steamRunning;
  final SteamProfiles _profiles;

  /// Все учётные записи, заходившие на этой машине.
  Future<List<SteamProfile>> profiles() => _profiles.all();

  L get _l => _localizations();
  static L _defaultLocalizations() => LRu();

  /// Куда класть ярлык. Одна запись — она и есть; несколько — та, под
  /// которой сидели последней.
  Future<SteamProfile> _target() async {
    final all = await profiles();
    if (all.isEmpty) throw SteamShortcutException(_l.steamNotFound);
    if (all.length == 1) return all.single;

    final recent = await _profiles.mostRecentAccount();
    final match = all.where((profile) => profile.accountId == recent);
    if (match.isEmpty) throw SteamShortcutException(_l.steamManyProfiles);
    return match.first;
  }

  /// Под каким именем процесс Steam виден в системе. На macOS это
  /// `steam_osx`: проверка по `steam` его не видела, и запись при запущенном
  /// Steam молча пропадала — он выкладывает свой список при выходе.
  static List<String> processNamesFor(String system) => switch (system) {
    'windows' => const ['steam.exe'],
    'macos' => const ['steam_osx'],
    _ => const ['steam'],
  };

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
      for (final name in processNamesFor(Platform.operatingSystem)) {
        final result = await Process.run('pgrep', ['-x', name]);
        if (result.exitCode == 0) return true;
      }
      return false;
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
  static String gridNameFor(int appId, List<int> cover) =>
      SteamGrid.nameFor(appId, cover);

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
    // В списке ждём только карты. Непонятное не трогают — ни переписывая
    // рядом, ни теряя при переписывании.
    if (shortcuts.values.any((value) => value is! Map<String, Object>)) {
      throw SteamShortcutException(_l.steamShortcutsUnreadable);
    }
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
    await const SteamGrid().write(
      game,
      gridDir: profile.gridDir,
      appId: appId,
      artwork: artwork,
    );
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
}

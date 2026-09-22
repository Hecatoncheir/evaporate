import 'package:evaporate/input/gamepad_binding.dart';
import 'package:evaporate/input/nav_action.dart';
import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/models/app_theme_mode.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/game_rating.dart';
import 'package:evaporate/models/library_effect.dart';
import 'package:evaporate/models/proxy_settings.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:evaporate/models/speed_limits.dart';
import 'package:evaporate/models/window_start_mode.dart';
import 'package:evaporate/services/saves/snapshot_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';

/// Модель, записанная на диск и прочитанная обратно, обязана остаться
/// собой — и это проверяется, а не поддерживается вручную.
///
/// Цена забытого поля известна: у `Game` его правят в шести местах, и
/// дважды такое уже случалось. Здесь каждое поле выставлено **не в
/// значение по умолчанию**, поэтому забытая строка в `toJson` или
/// `fromJson` роняет прогон, а не теряет данные у человека.
void main() {
  const rule = SavePathRule(
    id: 'r1',
    label: 'Сохранения',
    template: '{HOME}/saves',
    platform: 'windows',
    kind: SavePathKind.file,
  );

  final game = Game(
    id: 'g1',
    title: 'Игра',
    addedAt: DateTime(2026, 3, 4, 5, 6, 7),
    installDir: 'D:/games/Игра',
    executablePath: 'D:/games/Игра/game.exe',
    launchArgs: const ['-windowed'],
    details: const GameDetails(
      coverPath: 'covers/g1.jpg',
      coverUrl: 'https://example.invalid/header.jpg',
      shotPaths: ['shots/g1-0.jpg'],
      description: 'описание',
      rating: GameRating(
        score: 8,
        summary: 'Очень положительные',
        positive: 90,
        negative: 10,
        metacritic: 86,
      ),
      steamAppId: 42,
      steamLookupAttempted: true,
    ),
    saveDiscovery: const SaveDiscovery(
      savePathsLookupAttempted: true,
      ludusaviTemplates: ['{HOME}/база'],
      ludusaviResolvedPaths: ['{HOME}/найдено'],
    ),
    notes: 'заметка',
    saveProfile: const SaveProfile(
      rules: [rule],
      autoSnapshotOnExit: false,
      autoSnapshotOnLaunch: true,
      keepSnapshots: 7,
    ),
    play: PlayStats(
      playtime: const Duration(hours: 3),
      lastPlayed: DateTime(2026, 4, 5),
    ),
    status: GameStatus.paused,
    download: const DownloadLink(
      source: GameSource(
        kind: GameSourceKind.torrentFile,
        value: 'раздача.torrent',
      ),
      downloadTaskId: 'task-1',
      infoHash: 'abcdef',
    ),
    sizeBytes: 1234,
    lastError: 'что-то пошло не так',
  );

  final snapshot = SaveSnapshot(
    id: 's1',
    gameId: 'g1',
    gameTitle: 'Игра',
    createdAt: DateTime(2026, 5, 6, 7, 8),
    deviceName: 'здешний',
    platform: 'windows',
    sizeBytes: 99,
    archivePath: 'snapshots/s1.evsave',
    rules: const [rule],
    playtime: const Duration(minutes: 42),
    note: 'перед восстановлением',
    fileCount: 3,
    origin: SnapshotOrigin.preRestore,
    blobs: const [
      SnapshotBlob(name: 'data/r1/slot.sav', hash: 'ab12', size: 7),
    ],
  );

  const settings = AppSettings(
    installDir: 'D:/games',
    maxConcurrent: 5,
    systemNotifications: false,
    saves: SaveAutomation(
      syncFolder: 'D:/sync',
      autoExportToSync: false,
      autoSnapshotOnExit: false,
      autoSnapshotOnLaunch: true,
    ),
    startup: StartupSettings(
      launchAtStartup: true,
      windowStart: WindowStartMode.minimized,
      checkUpdates: false,
    ),
    appearance: Appearance(
      themeMode: AppThemeMode.light,
      libraryEffects: false,
      // Набор нарочно не совпадает с поставляемым: забытое украшение в
      // `toJson` или `fromJson` иначе прошло бы незамеченным.
      effects: {
        LibraryEffect.particles,
        LibraryEffect.liquidDistortion,
        LibraryEffect.liquidSelection,
        LibraryEffect.drops,
        LibraryEffect.selectionFrame,
      },
      interfaceScale: 1.25,
      libraryScale: 0.9,
      locale: 'en',
    ),
    proxy: ProxySettings(
      enabled: true,
      kind: ProxyKind.socks5,
      host: 'прокси',
      port: 1080,
      username: 'кто-то',
      password: 'тайна',
      useForSteam: false,
    ),
    limits: SpeedLimits(download: 400, upload: 50, whilePlaying: 100),
    gamepad: GamepadBinding(
      buttons: {GamepadButton.a: NavAction.back},
      deadzone: 0.4,
      releaseZone: 0.3,
      enabled: false,
    ),
  );

  test('игра переживает запись и чтение', () {
    expect(Game.fromJson(game.toJson()), game);
  });

  test('снимок переживает запись и чтение', () {
    expect(SaveSnapshot.fromJson(snapshot.toJson()), snapshot);
  });

  test('профиль сохранений переживает запись и чтение', () {
    expect(SaveProfile.fromJson(game.saveProfile.toJson()), game.saveProfile);
  });

  test('настройки переживают запись и чтение', () {
    expect(AppSettings.fromJson(settings.toJson(), 'запасная'), settings);
  });

  test('copyWith без аргументов ничего не меняет', () {
    expect(game.copyWith(), game);
    expect(snapshot.copyWith(), snapshot);
    expect(settings.copyWith(), settings);
    expect(settings.appearance.copyWith(), settings.appearance);
    expect(settings.startup.copyWith(), settings.startup);
    expect(settings.saves.copyWith(), settings.saves);
    expect(game.saveProfile.copyWith(), game.saveProfile);
    expect(game.details.copyWith(), game.details);
    expect(game.saveDiscovery.copyWith(), game.saveDiscovery);
    expect(game.download.copyWith(), game.download);
    expect(game.play.copyWith(), game.play);
  });

  // Части игры — значения, а на диске запись осталась плоской: ключи
  // прежние, вложенных объектов нет. `library.json` лежит у людей на
  // дисках, и разбор модели на части обязан читать то, что записано до
  // него, и писать то, что прочтут сборки, записанные до него.
  test('запись игры осталась плоской, с прежними ключами', () {
    final json = game.toJson();

    expect(json.keys, isNot(contains('details')));
    expect(json.keys, isNot(contains('download')));
    expect(
      json.keys,
      containsAll([
        'coverPath',
        'shotPaths',
        'rating',
        'steamAppId',
        'steamLookupAttempted',
        'savePathsLookupAttempted',
        'ludusaviTemplates',
        'ludusaviResolvedPaths',
        'source',
        'downloadTaskId',
        'infoHash',
        'playtimeSeconds',
        'lastPlayed',
      ]),
    );
  });

  // Настройки разобраны на части так же, и так же обязаны писать прежние
  // ключи: файл настроек лежит у людей на дисках, и сборка до разбора
  // должна прочесть записанное после него.
  test('запись настроек осталась плоской, с прежними ключами', () {
    final json = settings.toJson();

    expect(json.keys, isNot(contains('appearance')));
    expect(json.keys, isNot(contains('startup')));
    expect(json.keys, isNot(contains('saves')));
    expect(
      json.keys,
      containsAll([
        'themeMode',
        'locale',
        'interfaceScale',
        'libraryScale',
        'libraryEffects',
        'particlesEnabled',
        'launchAtStartup',
        'windowStart',
        'checkUpdates',
        'syncFolder',
        'autoExportToSync',
        'autoSnapshotOnExit',
        'autoSnapshotOnLaunch',
      ]),
    );
  });

  // Без этих двух веток библиотека, записанная давно, читалась бы с
  // потерями: загрузка теряла бы связь с игрой, а поиск в Steam
  // повторялся бы для игр, у которых `appid` давно есть.
  test('старые записи читаются, как читались', () {
    final old = Game.fromJson(const {
      'id': 'g1',
      'title': 'Игра',
      'downloadGid': 'gid-1',
      'steamAppId': 42,
    });

    expect(old.download.downloadTaskId, 'gid-1');
    expect(old.details.steamLookupAttempted, isTrue);
  });

  // Заметку ставят перед восстановлением и снимают, когда снимок
  // перестал быть резервным: `null` в обычном параметре значит «не
  // трогать», и снять её было нечем.
  test('заметку снимка можно стереть', () {
    expect(snapshot.copyWith(note: null).note, isNull);
    expect(snapshot.copyWith().note, 'перед восстановлением');
  });
}

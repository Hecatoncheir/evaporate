import 'package:evaporate/input/gamepad_binding.dart';
import 'package:evaporate/input/nav_action.dart';
import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/models/app_theme_mode.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/game_rating.dart';
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
    source: const GameSource(
      kind: GameSourceKind.torrentFile,
      value: 'раздача.torrent',
    ),
    installDir: 'D:/games/Игра',
    executablePath: 'D:/games/Игра/game.exe',
    launchArgs: const ['-windowed'],
    coverPath: 'covers/g1.jpg',
    coverUrl: 'https://example.invalid/header.jpg',
    shotPaths: const ['shots/g1-0.jpg'],
    description: 'описание',
    rating: const GameRating(
      score: 8,
      summary: 'Очень положительные',
      positive: 90,
      negative: 10,
      metacritic: 86,
    ),
    steamAppId: 42,
    steamLookupAttempted: true,
    savePathsLookupAttempted: true,
    ludusaviTemplates: const ['{HOME}/база'],
    ludusaviResolvedPaths: const ['{HOME}/найдено'],
    notes: 'заметка',
    saveProfile: const SaveProfile(
      rules: [rule],
      autoSnapshotOnExit: false,
      autoSnapshotOnLaunch: true,
      keepSnapshots: 7,
    ),
    playtime: const Duration(hours: 3),
    lastPlayed: DateTime(2026, 4, 5),
    status: GameStatus.paused,
    downloadTaskId: 'task-1',
    infoHash: 'abcdef',
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
    syncFolder: 'D:/sync',
    autoExportToSync: false,
    autoSnapshotOnExit: false,
    autoSnapshotOnLaunch: true,
    systemNotifications: false,
    launchAtStartup: true,
    windowStart: WindowStartMode.minimized,
    checkUpdates: false,
    themeMode: AppThemeMode.light,
    libraryEffects: false,
    particlesEnabled: true,
    wavesEnabled: false,
    foilEnabled: false,
    cardTiltEnabled: false,
    liquidDistortionEnabled: true,
    liquidSelectionEnabled: true,
    ambientEnabled: false,
    heroSweepEnabled: false,
    shotsBackdropEnabled: false,
    coverBackdropEnabled: false,
    interfaceAnimationsEnabled: false,
    dropsEnabled: true,
    portalEnabled: false,
    selectionFrameEnabled: true,
    interfaceScale: 1.25,
    libraryScale: 0.9,
    locale: 'en',
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
    expect(game.saveProfile.copyWith(), game.saveProfile);
  });

  // Заметку ставят перед восстановлением и снимают, когда снимок
  // перестал быть резервным: `null` в обычном параметре значит «не
  // трогать», и снять её было нечем.
  test('заметку снимка можно стереть', () {
    expect(snapshot.copyWith(note: null).note, isNull);
    expect(snapshot.copyWith().note, 'перед восстановлением');
  });
}

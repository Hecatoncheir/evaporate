import 'dart:io';

import 'package:flutter/foundation.dart';

import 'game_roots.dart';
import 'library_scanner.dart';
import 'steam_install.dart';
import 'windows_installs.dart';

/// Один заход сканирования: что уже нашли, где сейчас смотрим и можно ли
/// это прервать.
///
/// Обход дисков идёт секундами, а то и дольше. Пока он идёт, человеку надо
/// показывать, на чём приложение стоит, — иначе окно с вертушкой ничем не
/// отличается от зависшего. И прерывать его надо уметь: выбор папки в
/// системном окне отменяет начатый заход, а не встаёт за ним в очередь.
///
/// Сканирование начинается **до** того, как человек выберет папку: пока он
/// ищет её в системном окне, известные места уже осматриваются. Выбрал —
/// начинаем заново по его папке; закрыл окно, ничего не выбрав, — просто
/// останавливаемся и показываем найденное. Остановка не выбрасывает то, что
/// уже нашли: это результат, а не черновик.
class ScanSession extends ChangeNotifier {
  ScanSession({
    required this.existingDirs,
    this.installDir,
    @visibleForTesting this.steamRoots,
    @visibleForTesting this.fixedRoots,
    @visibleForTesting this.registryQuery,
  });

  /// Папки, уже известные библиотеке: их незачем предлагать снова.
  final Set<String> existingDirs;

  /// Куда качает само приложение — самое вероятное место из всех.
  final String? installDir;

  /// Подменяются в тестах: настоящая установка Steam есть не на всякой
  /// машине, а прогон идёт на трёх.
  final List<String>? steamRoots;
  final List<GameRoot>? fixedRoots;

  /// Чем спрашивать реестр Windows. `reg` есть только там, а прогон идёт
  /// на трёх системах.
  final Future<ProcessResult> Function(String, List<String>)? registryQuery;

  final List<ScannedGame> _found = [];
  String? _directory;
  bool _running = false;

  /// Поколение захода: остановленный заход не должен дописывать найденное
  /// в список, который уже принадлежит следующему.
  int _generation = 0;

  List<ScannedGame> get found => List.unmodifiable(_found);

  /// Папка, которую осматривают прямо сейчас.
  String? get directory => _directory;

  bool get isRunning => _running;

  /// Заход хотя бы раз доходил до конца сам, а не был прерван.
  bool get isComplete => _completed;
  bool _completed = false;

  /// Осматривает известные места: библиотеки Steam, папки лончеров, тома.
  Future<void> scanKnownRoots() async {
    final roots =
        fixedRoots ??
        await GameRoots.suggest(steamRoots: steamRoots, installDir: installDir);
    await _run([for (final root in roots) root.path]);
  }

  /// Осматривает одну папку, выбранную человеком, отменив всё начатое.
  Future<void> scanOnly(String directory) => _run([directory]);

  /// Останавливает заход, оставляя найденное.
  void stop() {
    if (!_running) return;
    _generation++;
    _running = false;
    _directory = null;
    notifyListeners();
  }

  Future<void> _run(List<String> roots) async {
    final generation = ++_generation;
    _found.clear();
    _running = true;
    _completed = false;
    _directory = null;
    notifyListeners();

    // Steam спрашиваем один раз на заход: он знает точные названия и
    // идентификаторы тех игр, что поставил сам.
    final steam = SteamInstall.byInstallDir(
      await SteamInstall.installed(roots: steamRoots),
    );
    if (generation != _generation) return;

    for (final root in roots) {
      if (generation != _generation) return;
      final games = await LibraryScanner.scan(
        root,
        existingDirs: {
          ...existingDirs,
          for (final game in _found) game.installDir,
        },
        steamApps: steam,
        isCancelled: () => generation != _generation,
        onDirectory: (dir) {
          if (generation != _generation) return;
          _directory = dir;
          notifyListeners();
        },
      );
      if (generation != _generation) return;
      _found.addAll(games);
      _found.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      notifyListeners();
    }

    if (generation != _generation) return;
    await _addRegistryInstalls(generation, steam);

    if (generation != _generation) return;
    _running = false;
    _completed = true;
    _directory = null;
    notifyListeners();
  }

  /// Добавляет игры, о которых знает только реестр Windows.
  ///
  /// Установщик записывает `InstallLocation`, и это единственный след игры,
  /// поставленной мимо всяких лончеров. В тех же ветках лежит вообще всё
  /// установленное, поэтому найденное здесь помечается неуверенным: оно
  /// предлагается, но галочкой заранее не отмечается.
  Future<void> _addRegistryInstalls(
    int generation,
    Map<String, SteamApp> steam,
  ) async {
    final entries = await WindowsInstalls.installed(run: registryQuery);
    final known = {...existingDirs, for (final game in _found) game.installDir};

    for (final entry in entries) {
      if (generation != _generation) return;
      final game = await LibraryScanner.inspect(
        entry.installDir,
        title: entry.name,
        existingDirs: known,
        steamApps: steam,
        confident: false,
      );
      if (game == null) continue;
      _found.add(game);
      known.add(game.installDir);
    }
    if (generation != _generation) return;
    _found.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}

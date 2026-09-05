import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Все директории, которыми пользуется приложение.
///
/// Данные приложения (библиотека, снапшоты сейвов) лежат в системной папке
/// поддержки приложения, а сами игры по умолчанию — в домашней директории:
/// они большие, и пользователь обычно хочет держать их на отдельном диске.
class AppPaths {
  AppPaths._({required this.dataDir, required this.defaultInstallDir});

  final String dataDir;
  final String defaultInstallDir;

  static AppPaths? _instance;

  static AppPaths get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('AppPaths.init() не был вызван');
    }
    return value;
  }

  /// Для тестов и нестандартных сборок: каталоги задаются напрямую,
  /// без обращения к системным API.
  factory AppPaths.custom({
    required String dataDir,
    required String defaultInstallDir,
  }) => AppPaths._(dataDir: dataDir, defaultInstallDir: defaultInstallDir);

  static Future<AppPaths> init() async {
    final support = await getApplicationSupportDirectory();
    final home = _homeDir();
    final paths = AppPaths._(
      dataDir: support.path,
      defaultInstallDir: p.join(home, 'Games', 'Evaporate'),
    );
    await Directory(paths.savesDir).create(recursive: true);
    await Directory(paths.blobsDir).create(recursive: true);
    await Directory(paths.coversDir).create(recursive: true);
    await Directory(paths.torrentsDir).create(recursive: true);
    _instance = paths;
    return paths;
  }

  String get libraryFile => p.join(dataDir, 'library.json');

  String get settingsFile => p.join(dataDir, 'settings.json');

  /// Архивы снапшотов сейвов: `saves/<gameId>/<snapshotId>.evsave`.
  ///
  /// Так лежат снимки, снятые до появления хранилища по содержимому. Новые
  /// хранятся в [blobsDir] и своего архива не имеют.
  String get savesDir => p.join(dataDir, 'saves');

  /// Файлы снимков, сложенные по содержимому: `blobs/<две буквы>/<sha256>`.
  ///
  /// Двадцать снимков одной игры — это двадцать полных копий её сохранений,
  /// хотя между соседними меняется обычно один файл. Здесь одинаковое
  /// содержимое лежит один раз, сколько бы снимков на него ни ссылалось.
  String get blobsDir => p.join(dataDir, 'blobs');

  String snapshotDirFor(String gameId) => p.join(savesDir, gameId);

  /// Обложки, скопированные в хранилище приложения.
  String get coversDir => p.join(dataDir, 'covers');

  /// Копии .torrent файлов, чтобы загрузку можно было возобновить.
  String get torrentsDir => p.join(dataDir, 'torrents');

  /// Кэш открытой базы путей сохранений.
  String get savePathsCacheFile => p.join(dataDir, 'save-paths.json');

  /// Размер и положение окна. Отдельно от настроек: это не выбор
  /// пользователя, а состояние, которое меняется само.
  String get windowStateFile => p.join(dataDir, 'window.json');

  /// Список загрузок движка: он переживает перезапуск приложения.
  String get engineStateFile => p.join(dataDir, 'downloads.json');

  static String _homeDir() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      return env['USERPROFILE'] ?? env['HOMEPATH'] ?? r'C:\';
    }
    return env['HOME'] ?? '/';
  }

  static String get home => _homeDir();
}

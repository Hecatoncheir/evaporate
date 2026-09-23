import 'dart:io';

/// Домашняя папка по переменным окружения; `null` — окружение её не называет.
///
/// Одна догадка на всё приложение. Прежде их было две: корни поиска игр
/// брали `USERPROFILE`, а за ним `HOMEPATH`, корни шаблонов сохранений —
/// один `USERPROFILE`, и без него две половины приложения молча смотрели в
/// разные папки. К тому же `HOMEPATH` — путь без диска (`\Users\имя`): диск
/// лежит отдельно, в `HOMEDRIVE`, и взятый один он указывал бы на тот
/// диск, что окажется текущим.
///
/// Окружение — параметром: там, где его подменяют в тестах (автозапуск,
/// запись в меню), догадка та же самая.
String? homeDirIn(Map<String, String> environment, {required bool windows}) {
  String? named(String key) {
    final value = environment[key];
    return value == null || value.isEmpty ? null : value;
  }

  if (!windows) return named('HOME');
  final drive = named('HOMEDRIVE');
  final path = named('HOMEPATH');
  return named('USERPROFILE') ??
      (drive != null && path != null ? '$drive$path' : null);
}

/// Домашняя папка этой машины. Не назвало её окружение — корень диска:
/// пути от неё строятся всегда, и пустой строке тут не место.
String homeDir() =>
    homeDirIn(Platform.environment, windows: Platform.isWindows) ??
    (Platform.isWindows ? r'C:\' : '/');

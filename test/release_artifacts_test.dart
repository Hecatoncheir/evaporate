import 'dart:io';

import 'package:evaporate/services/system/update_check.dart';
import 'package:flutter_test/flutter_test.dart';

/// Что уезжает в релиз, знает не приложение, а `.github/workflows/ci.yml` —
/// и разойтись они могут молча. Приложение ищет в релизе архив по хвосту
/// имени: переименуй сборка файл, и обновление по нажатию перестанет
/// находить, что скачивать, ничем себя не выдав до следующего выпуска.
///
/// Проверять здесь нечего, кроме имён, — но именно на именах всё и держится.
void main() {
  final ci = File('.github/workflows/ci.yml').readAsStringSync();

  group('сборка кладёт в релиз то, что ищет приложение', () {
    for (final platform in ['macos', 'windows', 'linux']) {
      test('архив для $platform собирается под ожидаемым именем', () {
        final suffix = Release.archiveSuffix(platform);

        expect(suffix, isNotNull);
        expect(
          ci,
          contains(suffix!),
          reason:
              'Приложение ищет в релизе файл с хвостом «$suffix». Сборка '
              'такого не делает — обновление по нажатию на $platform не '
              'найдёт, что скачивать.',
        );
      });
    }

    // Задача выпуска забирает артефакты по маске `evaporate-*` и по ней же
    // считает контрольные суммы. Файл с другим именем не попадёт ни в
    // релиз, ни в SHA256SUMS — и снова молча.
    test('установщики названы так, что попадают под маску релиза', () {
      final names = <String, String>{
        'windows/installer.iss': 'OutputBaseFilename=evaporate-',
        'tool/package_macos.sh': 'evaporate-\$version-macos.dmg',
        'tool/package_linux.sh': 'evaporate-\$version-linux-amd64.deb',
        'tool/package_run.sh': 'evaporate-\$version-linux-x86_64.run',
      };

      names.forEach((path, expected) {
        expect(
          File(path).readAsStringSync(),
          contains(expected),
          reason: '$path называет свой файл не так, как ждёт выпуск релиза',
        );
      });
    });

    // Запись в меню Linux одна на два установщика, и пути в ней подставляют
    // они сами: пакет знает их заранее, `.run` — только в момент установки.
    // Забудь подстановку один из них — в меню появится ярлык, запускающий
    // «@EXEC@».
    test('оба установщика Linux подставляют пути в запись меню', () {
      final template = File('linux/packaging/evaporate.desktop.in')
          .readAsStringSync();

      expect(template, contains('@EXEC@'));
      expect(template, contains('@ICON@'));
      for (final packager in ['tool/package_linux.sh', 'tool/package_run.sh']) {
        final text = File(packager).readAsStringSync();
        expect(text, contains('@EXEC@'), reason: '$packager не ставит путь');
        expect(text, contains('@ICON@'), reason: '$packager не ставит значок');
      }
    });

    // Установщик каждой системы должен доезжать до релиза: ради него всё и
    // затевалось — поставить приложение, не разбираясь с архивом.
    test('каждая сборка вызывает свою упаковку установщика', () {
      expect(ci, contains('tool/package_macos.sh'));
      expect(ci, contains('tool/package_linux.sh'));
      expect(ci, contains('tool/package_run.sh'));
      expect(ci, contains(r'windows\installer.iss'));
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:evaporate/services/system/update_check.dart';
import 'package:evaporate/services/system/update_install.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/temp_dir.dart';

/// Что уезжает в релиз, знает не приложение, а `.github/workflows/ci.yml` —
/// и разойтись они могут молча. Приложение ищет в релизе файл по хвосту
/// имени: переименуй сборка файл, и обновление по нажатию перестанет
/// находить, что скачивать, ничем себя не выдав до следующего выпуска.
///
/// Проверять здесь нечего, кроме имён, — но именно на именах всё и держится.
void main() {
  final ci = File('.github/workflows/ci.yml').readAsStringSync();

  /// То же, но без строк-комментариев.
  ///
  /// Хвост имени встречается в `ci.yml` дважды: в команде упаковки и в
  /// пояснении рядом с ней. Ищи страж по всему тексту — переименуй сборка
  /// файл, пояснение осталось бы прежним, и он промолчал бы ровно там, где
  /// заведён кричать.
  final commands = LineSplitter.split(ci)
      .where((line) => !line.trimLeft().startsWith('#'))
      .join('\n');

  group('сборка кладёт в релиз то, что ищет приложение', () {
    test('обновление для macos собирается под ожидаемым именем', () {
      final suffix = Release.updateSuffix('macos');

      expect(suffix, isNotNull);
      expect(
        commands,
        contains(suffix!),
        reason:
            'Приложение ищет в релизе файл с хвостом «$suffix». Сборка '
            'такого не делает — обновление по нажатию на macos не найдёт, '
            'что скачивать.',
      );
    });

    // Архив Linux пакует отдельный скрипт: у него корневая папка и маркер,
    // и одной строкой `tar` в ci.yml это уже не записать.
    test('обновление для linux собирается под ожидаемым именем', () {
      final suffix = Release.updateSuffix('linux');

      expect(commands, contains('tool/package_tarball.sh'));
      expect(
        File('tool/package_tarball.sh').readAsStringSync(),
        contains('evaporate-\$version$suffix'),
        reason:
            'Приложение ищет в релизе файл с хвостом «$suffix». Сборка '
            'такого не делает — обновление по нажатию на linux не найдёт, '
            'что скачивать.',
      );
      // Прежний хвост в релиз класть нельзя: его найдут сборки, чей
      // помощник удаляет папку приложения, не проверяя, чья она.
      expect(commands, isNot(contains('-linux.tar.gz')));
    });

    // По маркеру приложение узнаёт папку, которую положила сборка, и только
    // такую заменяет целиком. Архив и `.run` его несут; пакет — нет: его
    // файлы принадлежат dpkg.
    test('маркер своей папки несут архив и .run, но не пакет', () {
      for (final packager in [
        'tool/package_tarball.sh',
        'tool/package_run.sh',
      ]) {
        final text = File(packager).readAsStringSync();
        expect(
          text,
          contains('/${InstallLayout.marker}"'),
          reason: '$packager не кладёт маркер',
        );
      }
      expect(
        File('tool/package_linux.sh').readAsStringSync(),
        contains('rm -f "\$stage/opt/evaporate/${InstallLayout.marker}"'),
      );
    });

    // Россыпью архив распаковывали прямо в «Загрузки», и они становились
    // папкой приложения. Проверяется настоящей упаковкой, а не текстом.
    test('в архиве Linux одна корневая папка с маркером', () async {
      final tmp = await Directory.systemTemp.createTemp('evaporate_tar_');
      addTearDown(() => deleteTempDir(tmp));
      final bundle = Directory('${tmp.path}/bundle');
      await Directory('${bundle.path}/lib').create(recursive: true);
      await Directory('${bundle.path}/data').create(recursive: true);
      await File('${bundle.path}/evaporate').writeAsString('бинарь');

      final packed = await Process.run('bash', [
        'tool/package_tarball.sh',
        '9.9.9',
        bundle.path,
        '${tmp.path}/dist',
      ]);
      expect(packed.exitCode, 0, reason: '${packed.stderr}');

      final listed = await Process.run('tar', [
        '-tzf',
        '${tmp.path}/dist/evaporate-9.9.9${Release.updateSuffix('linux')}',
      ]);
      final entries = LineSplitter.split(listed.stdout as String)
          .map((entry) => entry.replaceFirst(RegExp('^\\./'), ''))
          .where((entry) => entry.isNotEmpty)
          .toList();
      expect(entries.map((entry) => entry.split('/').first).toSet(), {
        'evaporate',
      });
      expect(entries, contains('evaporate/${InstallLayout.marker}'));
    }, skip: Platform.isWindows ? 'упаковка Linux идёт в bash' : null);

    test('windows обновляется файлом Inno Setup', () {
      expect(Release.updateSuffix('windows'), '-windows-setup.exe');
      expect(
        File('windows/installer.iss').readAsStringSync(),
        contains('OutputBaseFilename=evaporate-{#AppVersion}-windows-setup'),
      );
    });

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
      expect(commands, contains('tool/package_macos.sh'));
      expect(commands, contains('tool/package_linux.sh'));
      expect(commands, contains('tool/package_run.sh'));
      expect(commands, contains(r'windows\installer.iss'));
    });
  });
}

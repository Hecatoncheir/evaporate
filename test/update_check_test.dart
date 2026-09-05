import 'dart:io';

import 'package:evaporate/services/system/update_check.dart';

import 'dart:convert';

import 'package:evaporate/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Ответ GitHub, урезанный до полей, которые мы читаем.
  String releaseBody(
    String tag, {
    bool draft = false,
    bool prerelease = false,
  }) =>
      '''
      {"tag_name": "$tag",
       "html_url": "https://github.com/Hecatoncheir/evaporate/releases/tag/$tag",
       "body": "Что нового",
       "published_at": "2026-09-01T19:44:31Z",
       "draft": $draft, "prerelease": $prerelease}''';

  UpdateCheck checkWith(String body, {String current = '0.2.0'}) =>
      UpdateCheck(currentVersion: current, fetch: (uri) async => body);

  group('разбор версий', () {
    test('приставка v не мешает', () {
      expect(AppVersion.parse('v1.2.3'), [1, 2, 3]);
      expect(AppVersion.parse('1.2.3'), [1, 2, 3]);
    });

    test('недостающие числа считаются нулями', () {
      expect(AppVersion.parse('2'), [2, 0, 0]);
      expect(AppVersion.parse('2.1'), [2, 1, 0]);
    });

    test('хвост после числа отбрасывается', () {
      expect(AppVersion.parse('1.2.3-beta'), [1, 2, 3]);
      expect(AppVersion.parse('1.2.3+7'), [1, 2, 3]);
    });

    test('несуразное не разбирается', () {
      expect(AppVersion.parse('неизвестно'), isNull);
      expect(AppVersion.parse('1.2.3.4'), isNull);
      expect(AppVersion.parse(''), isNull);
    });
  });

  group('сравнение версий', () {
    test('старшее число важнее младших', () {
      expect(AppVersion.isNewer('1.0.0', '0.99.99'), isTrue);
      expect(AppVersion.isNewer('0.3.0', '0.2.9'), isTrue);
      expect(AppVersion.isNewer('0.2.10', '0.2.9'), isTrue);
    });

    test('та же версия новее не считается', () {
      expect(AppVersion.isNewer('0.2.0', '0.2.0'), isFalse);
      expect(AppVersion.isNewer('v0.2.0', '0.2.0'), isFalse);
    });

    test('более старая версия не выдаётся за новую', () {
      expect(AppVersion.isNewer('0.1.9', '0.2.0'), isFalse);
    });

    // Иначе мусор в ответе привёл бы к вечному «доступно обновление».
    test('неразбираемое сравнение ничего не утверждает', () {
      expect(AppVersion.compare('чепуха', '0.2.0'), isNull);
      expect(AppVersion.isNewer('чепуха', '0.2.0'), isFalse);
    });
  });

  group('чтение ответа GitHub', () {
    test('вышедшая версия распознаётся', () async {
      final release = await checkWith(releaseBody('v0.3.0')).latest();

      expect(release, isNotNull);
      expect(release!.version, 'v0.3.0');
      expect(release.url, contains('releases/tag/v0.3.0'));
      expect(release.notes, 'Что нового');
      expect(release.publishedAt, isNotNull);
    });

    test('своя версия обновлением не считается', () async {
      expect(await checkWith(releaseBody('v0.2.0')).latest(), isNull);
    });

    test('версия старше установленной пропускается', () async {
      expect(await checkWith(releaseBody('v0.1.0')).latest(), isNull);
    });

    // Черновики и предрелизы выкладывают не для того, чтобы на них звали.
    test('черновик не предлагается', () async {
      final body = releaseBody('v9.0.0', draft: true);

      expect(await checkWith(body).latest(), isNull);
    });

    test('предрелиз не предлагается', () async {
      final body = releaseBody('v9.0.0', prerelease: true);

      expect(await checkWith(body).latest(), isNull);
    });

    test('не-json приводит к понятной ошибке', () {
      expect(
        () => UpdateCheck.parseRelease('<html>сбой</html>'),
        throwsA(isA<UpdateCheckException>()),
      );
    });

    test('ответ без метки версии ничего не ломает', () {
      expect(UpdateCheck.parseRelease('{"message": "Not Found"}'), isNull);
    });

    test('ошибка сети пробрасывается вызывающему', () async {
      final check = UpdateCheck(
        fetch: (uri) async => throw const UpdateCheckException('нет связи'),
      );

      await expectLater(check.latest(), throwsA(isA<UpdateCheckException>()));
    });
  });

  group('версия приложения', () {
    // Версия держится константой, чтобы не тащить зависимость ради строки.
    // Цена такого решения — риск разойтись с pubspec.yaml, и стережёт от
    // этого только тест.
    test('совпадает с версией в pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
        multiLine: true,
      ).firstMatch(pubspec);

      expect(match, isNotNull, reason: 'в pubspec.yaml нет строки version');
      expect(
        match!.group(1),
        AppVersion.current,
        reason: 'подняли версию в pubspec — поднимите и в AppVersion.current',
      );
    });

    test('своя версия разбирается', () {
      expect(AppVersion.parse(AppVersion.current), isNotNull);
    });
  });

  // Обновление скачивается по этим ссылкам, и брать их надо из ответа
  // GitHub, а не собирать по шаблону: имя файла содержит версию, а хост
  // раздачи Valve менять не обещал.
  group('файлы релиза', () {
    String body(List<Map<String, Object>> assets) => jsonEncode({
      'tag_name': 'v9.9.9',
      'html_url': 'https://example.invalid/release',
      'body': 'Описание',
      'assets': assets,
    });

    test('архивы и суммы читаются из ответа', () {
      final release = UpdateCheck.parseRelease(
        body([
          {
            'name': 'evaporate-9.9.9-macos.zip',
            'browser_download_url': 'https://example.invalid/macos.zip',
            'size': 100,
          },
          {
            'name': 'evaporate-9.9.9-windows.zip',
            'browser_download_url': 'https://example.invalid/windows.zip',
            'size': 200,
          },
          {
            'name': 'evaporate-9.9.9-linux.tar.gz',
            'browser_download_url': 'https://example.invalid/linux.tar.gz',
            'size': 300,
          },
          {
            'name': 'SHA256SUMS',
            'browser_download_url': 'https://example.invalid/SHA256SUMS',
            'size': 400,
          },
        ]),
      )!;

      expect(release.assets, hasLength(4));
      expect(release.checksums?.url, 'https://example.invalid/SHA256SUMS');
      // Своя система — та, на которой идёт прогон.
      expect(release.archiveForThisPlatform, isNotNull);
      expect(
        release.archiveForThisPlatform!.name,
        contains(currentPlatformKey()),
      );
    });

    test('релиз без файлов не обещает обновления', () {
      final release = UpdateCheck.parseRelease(body(const []))!;

      expect(release.assets, isEmpty);
      expect(release.archiveForThisPlatform, isNull);
      expect(release.checksums, isNull);
    });

    test('запись без имени или ссылки пропускается', () {
      final release = UpdateCheck.parseRelease(
        body([
          {'name': 'evaporate-9.9.9-macos.zip', 'size': 1},
          {'browser_download_url': 'https://example.invalid/x', 'size': 1},
        ]),
      )!;

      expect(release.assets, isEmpty);
    });
  });
}

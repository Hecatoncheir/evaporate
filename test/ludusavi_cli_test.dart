import 'dart:io';

import 'package:evaporate/core/save_path_template.dart';
import 'package:evaporate/services/saves/ludusavi_cli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  /// Подменённый запуск процесса: ни одного настоящего Ludusavi.
  ProcessRun fakeRun({
    String find = '{"games": {}}',
    String preview = '{"games": {}}',
    List<List<String>>? calls,
    bool missing = false,
  }) {
    return (exe, args) async {
      calls?.add([exe, ...args]);
      if (missing) {
        throw ProcessException(exe, args, 'нет такого файла', 2);
      }
      if (args.contains('--version')) {
        return ProcessResult(0, 0, 'ludusavi 0.29.1', '');
      }
      if (args.first == 'find') return ProcessResult(0, 0, find, '');
      if (args.first == 'backup') return ProcessResult(0, 0, preview, '');
      return ProcessResult(0, 1, '', 'неизвестная команда');
    };
  }

  /// Ответ `find --api`: ключи — названия, известные Ludusavi.
  const findBody = '''
  {"games": {
    "Hollow Knight": {"score": 1.0},
    "Hollow Knight: Silksong": {"score": 0.42}
  }}''';

  group('аргументы запуска', () {
    // Главная страховка этого модуля: без `--preview` та же команда
    // сделала бы настоящий бэкап вместо опроса.
    test('опрос всегда идёт с --preview', () {
      final args = LudusaviCli.previewArgs('Hollow Knight');

      expect(args, contains('--preview'));
      expect(args.first, 'backup');
      expect(args.last, 'Hollow Knight');
    });

    test('поиск по идентификатору Steam не передаёт название', () {
      final args = LudusaviCli.findArgs(
        title: 'Hollow Knight',
        steamAppId: 367520,
      );

      expect(args, containsAllInOrder(['--steam-id', '367520']));
      expect(args, isNot(contains('--normalized')));
      expect(args, isNot(contains('Hollow Knight')));
    });

    test('без идентификатора ищем по приведённому названию', () {
      final args = LudusaviCli.findArgs(title: 'Hollow Knight');

      expect(args, containsAllInOrder(['--normalized', 'Hollow Knight']));
      expect(args, isNot(contains('--steam-id')));
    });
  });

  group('разбор ответов', () {
    test('названия отсортированы по совпадению', () {
      expect(LudusaviCli.parseFindTitles(findBody), [
        'Hollow Knight',
        'Hollow Knight: Silksong',
      ]);
    });

    test('пустая выдача — пустой список, а не ошибка', () {
      expect(LudusaviCli.parseFindTitles('{"games": {}}'), isEmpty);
    });

    test('не-json приводит к понятной ошибке', () {
      expect(
        () => LudusaviCli.parseFindTitles('паника: не найдено'),
        throwsA(isA<LudusaviCliException>()),
      );
    });

    test('пути берутся из выбранной игры', () {
      const body = '''
      {"games": {
        "Hollow Knight": {"files": {
          "/tmp/a/slot1.dat": {"ignored": false, "failed": false},
          "/tmp/a/slot2.dat": {"ignored": false, "failed": false}
        }, "registry": {}}
      }}''';

      final scan = LudusaviCli.parsePreview(body, title: 'Hollow Knight');

      expect(scan.files, ['/tmp/a/slot1.dat', '/tmp/a/slot2.dat']);
      expect(scan.registry, isEmpty);
    });

    // Ludusavi сам помечает, что пропустил или не смог прочитать.
    test('пропущенные и сбойные файлы не берутся', () {
      const body = '''
      {"games": {"Игра": {"files": {
        "/tmp/ok.dat": {"ignored": false, "failed": false},
        "/tmp/skip.dat": {"ignored": true, "failed": false},
        "/tmp/broken.dat": {"ignored": false, "failed": true}
      }}}}''';

      final scan = LudusaviCli.parsePreview(body);

      expect(scan.files, ['/tmp/ok.dat']);
    });

    test('ветки реестра собираются отдельно', () {
      const body = '''
      {"games": {"Игра": {"files": {},
        "registry": {"HKEY_CURRENT_USER/Software/Игра": {"failed": false}}}}}''';

      final scan = LudusaviCli.parsePreview(body);

      expect(scan.registry, hasLength(1));
      expect(scan.files, isEmpty);
    });

    test('игра без файлов даёт пустой результат, а не сбой', () {
      final scan = LudusaviCli.parsePreview('{"games": {}}');

      expect(scan.files, isEmpty);
      expect(scan.registry, isEmpty);
    });
  });

  group('пути превращаются в шаблоны', () {
    // Корни берём у самого приложения: иначе тест проверял бы не то,
    // что произойдёт на этой машине.
    final appSupport = SavePathTemplate.expand(SavePathTemplate.appSupport);
    final documents = SavePathTemplate.expand(SavePathTemplate.documents);

    test('файлы одной папки дают одно правило на папку', () {
      final templates = LudusaviCli.toTemplates([
        p.join(appSupport, 'Игра', 'slot1.dat'),
        p.join(appSupport, 'Игра', 'slot2.dat'),
      ]);

      expect(templates, hasLength(1));
      expect(
        SavePathTemplate.expand(templates.single),
        p.join(appSupport, 'Игра'),
        reason: 'правило на папке заберёт и сейвы, появившиеся позже',
      );
    });

    test('вложенная папка не добавляется отдельным правилом', () {
      final templates = LudusaviCli.toTemplates([
        p.join(appSupport, 'Игра', 'slot.dat'),
        p.join(appSupport, 'Игра', 'profiles', 'p1.dat'),
      ]);

      expect(templates, hasLength(1));
      expect(
        SavePathTemplate.expand(templates.single),
        p.join(appSupport, 'Игра'),
      );
    });

    // Иначе в снимок уехали бы все «Документы» целиком.
    test('файл прямо в корне берётся файлом, а не папкой', () {
      final file = p.join(documents, 'save.dat');

      final templates = LudusaviCli.toTemplates([file]);

      expect(templates, hasLength(1));
      expect(SavePathTemplate.expand(templates.single), file);
    });

    test('разные папки дают разные правила', () {
      final templates = LudusaviCli.toTemplates([
        p.join(appSupport, 'Игра', 'slot.dat'),
        p.join(documents, 'Игра', 'profile.dat'),
      ]);

      expect(templates, hasLength(2));
    });

    test('метка правила — имя папки', () {
      expect(LudusaviCli.labelFor('{APPSUPPORT}/Игра/Saves'), 'Saves');
      expect(LudusaviCli.labelFor('{DOCUMENTS}'), 'Сохранения');
    });
  });

  group('опрос установленного Ludusavi', () {
    test('находит игру и отдаёт её пути', () async {
      final dir = p.join(SavePathTemplate.expand('{APPSUPPORT}'), 'HK');
      final preview =
          '{"games": {"Hollow Knight": {"files": {'
          '"${p.join(dir, 'user1.dat').replaceAll(r'\', r'\\')}": '
          '{"ignored": false, "failed": false}}}}}';
      final calls = <List<String>>[];
      final cli = LudusaviCli(
        run: fakeRun(find: findBody, preview: preview, calls: calls),
      );

      final found = await cli.lookup(title: 'Hollow.Knight-GOG');

      expect(found, isNotNull);
      expect(found!.title, 'Hollow Knight');
      expect(SavePathTemplate.expand(found.templates.single), dir);
      expect(
        calls.any((c) => c.contains('--preview')),
        isTrue,
        reason: 'опрос обязан идти предпросмотром, а не бэкапом',
      );
    });

    test('без установленного Ludusavi возвращается null', () async {
      final cli = LudusaviCli(run: fakeRun(missing: true));

      expect(await cli.lookup(title: 'Hollow Knight'), isNull);
      expect(await cli.isAvailable, isFalse);
    });

    test('неизвестная игра — это null, а не ошибка', () async {
      final cli = LudusaviCli(run: fakeRun(find: ''));

      expect(await cli.lookup(title: 'Что-то своё'), isNull);
    });

    test('идентификатор Steam пробуется первым', () async {
      final calls = <List<String>>[];
      final cli = LudusaviCli(
        run: fakeRun(find: findBody, calls: calls),
      );

      await cli.lookup(title: 'Hollow Knight', steamAppId: 367520);

      final firstFind = calls.firstWhere((c) => c.contains('find'));
      expect(firstFind, contains('--steam-id'));
    });

    test('если по идентификатору не нашлось, ищем по названию', () async {
      final calls = <List<String>>[];
      var byId = true;
      final cli = LudusaviCli(
        run: (exe, args) async {
          calls.add([exe, ...args]);
          if (args.contains('--version')) {
            return ProcessResult(0, 0, 'ludusavi 0.29.1', '');
          }
          if (args.first == 'find') {
            // Первый запрос — по идентификатору, он и остаётся пустым.
            if (byId) {
              byId = false;
              return ProcessResult(0, 1, '', 'game is not recognized');
            }
            return ProcessResult(0, 0, findBody, '');
          }
          return ProcessResult(0, 0, '{"games": {}}', '');
        },
      );

      await cli.lookup(title: 'Hollow Knight', steamAppId: 999999);

      final finds = calls.where((c) => c.contains('find')).toList();
      expect(finds, hasLength(2));
      expect(finds.last, contains('--normalized'));
    });

    test('путь из настроек пробуется раньше поиска по системе', () async {
      final calls = <List<String>>[];
      final cli = LudusaviCli(
        configuredPath: () => '/opt/мой/ludusavi',
        run: fakeRun(find: findBody, calls: calls),
      );

      await cli.executable();

      expect(calls.first.first, '/opt/мой/ludusavi');
    });

    test('смена пути в настройках заставляет искать заново', () async {
      var configured = '/opt/первый/ludusavi';
      final calls = <List<String>>[];
      final cli = LudusaviCli(
        configuredPath: () => configured,
        run: fakeRun(calls: calls),
      );

      expect(await cli.executable(), '/opt/первый/ludusavi');
      configured = '/opt/второй/ludusavi';

      expect(
        await cli.executable(),
        '/opt/второй/ludusavi',
        reason: 'иначе настройка применилась бы только после перезапуска',
      );
    });
  });
}

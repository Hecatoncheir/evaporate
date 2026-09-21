import 'dart:io';

import 'package:evaporate/core/save_path_template.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('SavePathTemplate', () {
    test('сворачивает домашний путь в переносимый шаблон', () {
      final home = SavePathTemplate.placeholders[SavePathTemplate.home]!;
      final path = p.join(home, 'Documents', 'MyGame', 'Saves');

      final template = SavePathTemplate.collapse(path);

      expect(SavePathTemplate.isPortable(template), isTrue);
      expect(template, contains('MyGame/Saves'));
    });

    test('разворачивание возвращает исходный путь', () {
      final appSupport =
          SavePathTemplate.placeholders[SavePathTemplate.appSupport]!;
      final original = p.join(appSupport, 'SomeGame', 'save');

      final restored = SavePathTemplate.expand(
        SavePathTemplate.collapse(original),
      );

      expect(
        p.equals(restored, original),
        isTrue,
        reason: '$restored != $original',
      );
    });

    test('выбирается самый специфичный корень, а не просто HOME', () {
      final documents =
          SavePathTemplate.placeholders[SavePathTemplate.documents]!;

      final template = SavePathTemplate.collapse(p.join(documents, 'Game'));

      expect(template, startsWith(SavePathTemplate.documents));
    });

    test('путь вне известных корней остаётся абсолютным и непереносимым', () {
      final foreign = Platform.isWindows ? r'D:\Games\Save' : '/opt/games/save';

      final template = SavePathTemplate.collapse(foreign);

      expect(SavePathTemplate.isPortable(template), isFalse);
      expect(p.isAbsolute(template), isTrue);
    });

    test('шаблон с прямыми слэшами разворачивается под разделитель ОС', () {
      final expanded = SavePathTemplate.expand('${SavePathTemplate.home}/a/b');

      expect(expanded, contains(p.join('a', 'b')));
    });

    // На macOS и Linux несколько плейсхолдеров указывают в одну папку, и
    // раньше выбор между ними зависел от сортировки, а `List.sort` в Dart
    // нестабилен. На Windows это уже разные папки: сейв, свёрнутый здесь в
    // `{SAVEDGAMES}`, уехал бы там не туда.
    test('совпадающие корни сворачиваются предсказуемо', () {
      final root = SavePathTemplate.expand(SavePathTemplate.appSupport);

      final collapsed = SavePathTemplate.collapse(p.join(root, 'Игра'));

      expect(collapsed, '${SavePathTemplate.appSupport}/Игра');
    });

    test('выбор корня не меняется от вызова к вызову', () {
      final root = SavePathTemplate.expand(SavePathTemplate.appSupport);
      final target = p.join(root, 'Игра', 'Saves');

      final results = {
        for (var i = 0; i < 20; i++) SavePathTemplate.collapse(target),
      };

      expect(results, hasLength(1));
    });
  });

  group('папка игры', () {
    test('{GAME} разворачивается в папку установки', () {
      // Шаблоны всегда пишутся через `/`, а expand приводит путь к
      // разделителю системы — на Windows это `\`, поэтому normalize.
      expect(
        SavePathTemplate.expand('{GAME}/saves', gameDir: '/opt/hk'),
        p.normalize(p.join('/opt/hk', 'saves')),
      );
    });

    // Пустить такой путь дальше значило бы искать папку с фигурными
    // скобками в имени — она не нашлась бы никогда, и молча.
    test('без папки установки плейсхолдер остаётся на месте', () {
      expect(SavePathTemplate.expand('{GAME}/saves'), contains('{GAME}'));
      expect(SavePathTemplate.needsGameDir('{GAME}/saves'), isTrue);
      expect(SavePathTemplate.needsGameDir('{HOME}/saves'), isFalse);
    });

    test('путь внутри игры сворачивается в {GAME}', () {
      final dir = p.join('/opt', 'hk');
      expect(
        SavePathTemplate.collapse(p.join(dir, 'saves'), gameDir: dir),
        '{GAME}/saves',
      );
      expect(SavePathTemplate.collapse(dir, gameDir: dir), '{GAME}');
    });

    // Игра может стоять внутри домашней папки. Свернись такой путь в
    // {HOME}, на другом устройстве с другой папкой игры он не нашёлся бы.
    test('папка игры важнее домашней', () {
      final home = SavePathTemplate.expand(SavePathTemplate.home);
      final dir = p.join(home, 'Games', 'HK');

      expect(
        SavePathTemplate.collapse(p.join(dir, 'saves'), gameDir: dir),
        '{GAME}/saves',
      );
    });

    test('{GAME} считается переносимым', () {
      expect(SavePathTemplate.isPortable('{GAME}/saves'), isTrue);
    });
  });

  group('метки новых правил', () {
    const own = SavePathRule(
      id: 'own',
      label: SavePathRule.defaultLabel,
      template: '{HOME}/Своё',
    );

    test('единственный новый путь не берёт метку заданного правила', () {
      const profile = SaveProfile(rules: [own]);

      final added = profile.rulesForNewPaths(['{HOME}/Найденное/Saves']);

      expect(added, hasLength(1));
      expect(profile.labelTaken(added.single.label), isFalse);
    });

    test('метка, которую человек дал сам, тоже занята', () {
      const profile = SaveProfile(
        rules: [SavePathRule(id: 'x', label: ' SAVES ', template: '{HOME}/a')],
      );

      final added = profile.rulesForNewPaths(['{HOME}/b/saves']);

      expect(added.single.label.trim().toLowerCase(), isNot('saves'));
    });

    test('уже заданный шаблон и повтор в списке правилом не становятся', () {
      const profile = SaveProfile(rules: [own]);

      final added = profile.rulesForNewPaths([
        own.template,
        '{HOME}/b',
        '{HOME}/b',
      ]);

      expect([for (final rule in added) rule.template], ['{HOME}/b']);
    });

    // Ради этого метка и существует: одна игра, разные пути на разных
    // системах, и снимок с одной ложится в путь на другой.
    test('правила разных систем делят метку законно', () {
      const profile = SaveProfile(
        rules: [
          SavePathRule(
            id: 'w',
            label: SavePathRule.defaultLabel,
            template: '{HOME}/w',
            platform: 'windows',
          ),
        ],
      );

      expect(
        profile.labelTaken(SavePathRule.defaultLabel, platform: 'macos'),
        isFalse,
      );
      expect(
        profile.labelTaken(SavePathRule.defaultLabel, platform: 'windows'),
        isTrue,
      );
      expect(profile.labelTaken(SavePathRule.defaultLabel), isTrue);
    });
  });

  // Пустой шаблон разворачивается в `.`, то есть в рабочую папку процесса:
  // снимок унёс бы её целиком, а восстановление с очисткой цели — очистило
  // бы. Относительный путь опасен тем же, только глубже.
  group('правило без абсолютного пути', () {
    SavePathRule rule(String template) =>
        SavePathRule(id: 'r', label: 'Сохранения', template: template);

    test('пустой шаблон никуда не разворачивается', () {
      expect(rule('').resolve(), isNull);
      expect(rule('').resolve(gameDir: p.join('/opt', 'hk')), isNull);
      expect(rule('  ').resolve(), isNull);
    });

    test('относительный путь никуда не разворачивается', () {
      expect(rule('Saves').resolve(), isNull);
      expect(rule('../Saves').resolve(), isNull);
    });

    test('шаблон с корнем разворачивается как прежде', () {
      expect(
        rule('{GAME}/saves').resolve(gameDir: p.join('/opt', 'hk')),
        p.normalize(p.join('/opt', 'hk', 'saves')),
      );
    });
  });

  // Выбрал в диалоге правила «Документы» — и восстановление с очисткой
  // отодвигало их целиком, клало на их место файлы снимка и удаляло
  // отодвинутое. Правило, развёрнутое в корень, не разворачивается никуда.
  group('правило шире папки сохранений', () {
    SavePathRule rule(String template) =>
        SavePathRule(id: 'r', label: 'Сохранения', template: template);

    for (final placeholder in SavePathTemplate.placeholders.keys) {
      test('$placeholder целиком — не папка сохранений', () {
        expect(rule(placeholder).resolve(), isNull);
        expect(rule('$placeholder/').resolve(), isNull);
        // Предок корня опаснее самого корня.
        expect(rule('$placeholder/..').resolve(), isNull);
      });
    }

    test('корень диска — не папка сохранений', () {
      final root = p.rootPrefix(p.current);
      expect(rule(root).resolve(), isNull);
      expect(SavePathTemplate.isTooBroad(root, roots: const []), isTrue);
    });

    test('папка игры целиком и её предок — не папка сохранений', () {
      final game = p.join(p.rootPrefix(p.current), 'Games', 'Hollow');
      expect(rule('{GAME}').resolve(gameDir: game), isNull);
      expect(rule('{GAME}/..').resolve(gameDir: game), isNull);
      expect(
        rule('{GAME}/saves').resolve(gameDir: game),
        p.join(game, 'saves'),
      );
    });

    test('папка внутри корня — обычная папка сохранений', () {
      for (final placeholder in SavePathTemplate.placeholders.keys) {
        expect(rule('$placeholder/Игра/Saves').resolve(), isNotNull);
      }
    });

    test('шире — сам корень и любой его предок, но не то, что внутри', () {
      final home = p.join(p.rootPrefix(p.current), 'Users', 'me');
      bool broad(String path) =>
          SavePathTemplate.isTooBroad(path, roots: [home]);

      expect(broad(home), isTrue);
      expect(broad(p.dirname(home)), isTrue);
      expect(broad(p.join(home, 'Игра')), isFalse);
    });
  });

  group('метки для набора путей', () {
    test('единственному пути — метка по умолчанию', () {
      expect(SavePathRule.labelsFor(['{HOME}/saves']), [
        SavePathRule.defaultLabel,
      ]);
    });

    test('разные имена папок становятся метками', () {
      expect(
        SavePathRule.labelsFor(['{HOME}/game/saves', '{HOME}/game/config']),
        ['saves', 'config'],
      );
    });

    // Одинаковые метки склеили бы разные сейвы при переносе на другое
    // устройство: сопоставление идёт именно по метке.
    test('совпавшие имена разводятся родительской папкой', () {
      expect(
        SavePathRule.labelsFor([
          '{GAME}/profiles/alice/save',
          '{GAME}/profiles/bob/save',
        ]),
        ['alice/save', 'bob/save'],
      );
    });

    test('метки всегда различны', () {
      final labels = SavePathRule.labelsFor([
        '{HOME}/a/save',
        '{HOME}/b/save',
        '{HOME}/a/b/save',
      ]);

      expect(labels.toSet(), hasLength(3));
    });
  });
}

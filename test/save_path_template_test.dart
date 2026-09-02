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

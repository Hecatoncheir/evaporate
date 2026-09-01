import 'dart:io';

import 'package:evaporate/core/save_path_template.dart';
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
}

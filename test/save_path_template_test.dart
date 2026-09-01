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
  });
}

import 'package:flutter_test/flutter_test.dart';

import '../support/guards.dart';
import '../support/layering.dart';

/// Скрипты `tool/` CI запускает голой Dart VM — `dart tool/…`, — а там
/// Flutter нет: `dart:ui` есть только под `flutter`.
///
/// Тесты этого не видят, они идут под Flutter, а сборки, где запускается
/// репетиция обновления, — только на теге и по расписанию. Так не вышла
/// 0.40.1: исключение обновления взяло переводы, переводы тянут Flutter, и
/// `tool/rehearse_update.dart` через распаковку перестал собираться —
/// узнали об этом, уже поставив тег.
///
/// Разрешённые пакеты — списком, как у моделей в `layering_test`: пакет,
/// которому нужен Flutter, прошёл бы, пока его не назовут поимённо.
void main() {
  test('скрипты tool/ собираются голой Dart VM', () {
    final graph = importGraph([...dartSources('tool'), ...dartSources('lib')]);
    expect(
      layerViolations(graph, ['tool'], needsFlutter).toList(),
      isEmpty,
      reason: '`dart tool/…` не соберётся: Flutter есть только под flutter',
    );
  });

  group('страж ловит нарушение', () {
    test('Flutter, dart:ui и незнакомый пакет — нельзя', () {
      expect(needsFlutter('package:flutter/foundation.dart'), isTrue);
      expect(needsFlutter('dart:ui'), isTrue);
      expect(needsFlutter('package:flutter_bloc/flutter_bloc.dart'), isTrue);
    });

    test('dart: и чистые пакеты — можно', () {
      expect(needsFlutter('dart:io'), isFalse);
      expect(needsFlutter('package:path/path.dart'), isFalse);
      expect(needsFlutter('package:archive/archive_io.dart'), isFalse);
    });

    test('запретное через свой импорт — тоже нарушение', () {
      final graph = importGraph([
        SourceFile('tool/x.dart', "import '../lib/a.dart';"),
        SourceFile('lib/a.dart', "import 'package:flutter/widgets.dart';"),
      ]);
      expect(layerViolations(graph, ['tool'], needsFlutter), [
        'tool/x.dart -> package:flutter/widgets.dart (через lib/a.dart)',
      ]);
    });
  });
}

/// Нужен ли импорту Flutter: `dart:ui` и всякий пакет вне списка чистых.
bool needsFlutter(String uri) {
  if (uri == 'dart:ui') return true;
  if (uri.startsWith('dart:') || !uri.startsWith('package:')) return false;
  return !const {
    'analyzer',
    'archive',
    'path',
  }.contains(uri.substring('package:'.length).split('/').first);
}

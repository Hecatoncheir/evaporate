import 'package:flutter_test/flutter_test.dart';

import '../support/guards.dart';

/// С блоком говорят событиями, и каждый публичный метод блока — исключение
/// с объяснением.
///
/// Правило `avoid_public_bloc_methods` из `bloc_lint` 0.4.2 этого не
/// держит: члены после первого `@override` оно не видит вовсе, и так без
/// пометки прошли `persist` у двух блоков, `snapshotBeforeLaunch`,
/// `applyLimits` и `torrents`, которые снаружи не нужны были вовсе. Страж
/// проверяет весь класс, а пометка `// ignore:` здесь — место для
/// объяснения, почему событием не выразить.
void main() {
  test('публичный метод блока помечен и объяснён', () {
    expect(
      dartSources('lib/bloc').expand(unmarkedBlocMembers).toList(),
      isEmpty,
      reason:
          'с блоком говорят событиями; если событием не выразить — пометьте '
          '`// ignore: avoid_public_bloc_methods` и объясните рядом, почему',
    );
  });

  group('страж ловит нарушение', () {
    SourceFile file(String code) => SourceFile('lib/bloc/x.dart', code);

    test('метод после @override', () {
      final code = file('''
class A extends Bloc<int, int> {
  @override
  Future<void> close() => super.close();

  void later() {}
}
''');
      expect(unmarkedBlocMembers(code), ['lib/bloc/x.dart: A.later']);
    });

    test('заголовок блока перенесён на две строки', () {
      final code = file('''
class LongNameBloc
    extends Bloc<int, int> {
  void open() {}
}
''');
      expect(unmarkedBlocMembers(code), ['lib/bloc/x.dart: LongNameBloc.open']);
    });

    test('геттер', () {
      final code = file(
        'class A extends Bloc<int, int> {\n  int get size => 1;\n}',
      );
      expect(unmarkedBlocMembers(code), ['lib/bloc/x.dart: A.size']);
    });

    test('помеченное, приватное, поля и статика не в счёт', () {
      final code = file('''
class A extends Bloc<int, int> {
  A() : super(0);

  final SettingsBloc settings;
  static const key = 'k';
  void _private() {}

  // ignore: avoid_public_bloc_methods
  Future<void> persist() async {}

  @override
  Future<void> close() => super.close();
}
''');
      expect(unmarkedBlocMembers(code), isEmpty);
    });
  });
}

/// Публичные методы и геттеры классов-блоков без пометки: `путь: Блок.член`.
Iterable<String> unmarkedBlocMembers(SourceFile file) sync* {
  final lines = file.code.split('\n');
  final original = file.text.split('\n');
  String? bloc;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    // Заголовок бывает перенесён: `class DownloadHistoryBloc` на одной
    // строке, `extends Bloc<…>` на следующей.
    final next = i + 1 < lines.length ? lines[i + 1] : '';
    final header = RegExp(r'^class\s+(\w+)\b[^{]*\bextends\s+Bloc<')
        .firstMatch(line.contains('{') ? line : '$line $next');
    if (header != null) {
      bloc = header.group(1);
      continue;
    }
    if (line.startsWith('}')) bloc = null;
    if (bloc == null) continue;
    final member = _publicMember.firstMatch(line);
    if (member == null) continue;
    final above = i > 0 ? original[i - 1].trim() : '';
    if (above == '@override' ||
        above.contains('ignore: avoid_public_bloc_methods')) {
      continue;
    }
    yield '${file.path}: $bloc.${member.group(1)}';
  }
}

/// Член класса на отступе в два пробела: тип, затем имя со строчной буквы
/// и скобки или стрелка — метод или геттер. Поля (`final`, `late`),
/// статика и конструктор сюда не попадают.
final _publicMember = RegExp(
  r'^  (?!static\b|final\b|late\b|const\b|factory\b)[A-Z\w][\w<>?, ]*\s+(?:get\s+)?([a-z]\w*)\s*(?:\(|=>|\{)',
);

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/gate.dart';

/// `tool/gate.dart` обещает «ровно то, что гоняет CI», и обещание это
/// проверяется чтением самого `ci.yml`, а не памятью.
void main() {
  final ci = File('.github/workflows/ci.yml').readAsStringSync();

  test('каждый шаг проверки в CI есть в воротах или назван чисто CI-шагом', () {
    final local = {for (final step in gateSteps) step.ciName};
    final names = ciCheckNames(ci);

    expect(names, isNotEmpty, reason: 'разбор ci.yml ничего не нашёл');
    expect([
      for (final name in names)
        if (!local.contains(name) && !ciOnlySteps.contains(name)) name,
    ], isEmpty);
  });

  test('шаг ворот не ссылается на шаг, которого в CI нет', () {
    final names = ciCheckNames(ci).toSet();

    expect([
      for (final step in gateSteps)
        if (!names.contains(step.ciName)) step.ciName,
    ], isEmpty);
    expect(ciOnlySteps.difference(names), isEmpty);
  });

  test('команда шага совпадает с той, что стоит в CI', () {
    // Тесты — исключение: в CI зерно выбирает шаг, здесь — сам `flutter`.
    final exact = gateSteps.where(
      (s) => s.executable != 'flutter' || s.arguments.first != 'test',
    );

    for (final step in exact) {
      expect(ci, contains(step.command), reason: step.ciName);
    }
  });

  test('версия Flutter читается из ci.yml', () {
    expect(pinnedFlutterVersion(ci), matches(RegExp(r'^\d+\.\d+\.\d+$')));
    expect(pinnedFlutterVersion('env:\n  FLUTTER_VERSION: 3.1.4\n'), '3.1.4');
    expect(pinnedFlutterVersion('env: {}\n'), isNull);
  });
}

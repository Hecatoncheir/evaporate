import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Ждёт, пока условие выполнится, вместо отмеренной паузы.
///
/// Пауза «на глаз» — главный источник плавающих тестов: файловый
/// ввод-вывод и обход папок на занятой машине сборки не укладываются ни в
/// тридцать миллисекунд, ни в триста, и те же тесты на том же коде
/// проходят в одном прогоне и падают в соседнем. Ожидание по условию от
/// скорости диска не зависит.
///
/// Срок нужен, но он здесь только чтобы прогон не висел вечно: не
/// дождавшись, тест всё равно упадёт на своей проверке — и упадёт там,
/// где смотрит человек, а не внутри ожидания.
Future<void> waitUntil(
  FutureOr<bool> Function() done, {
  Duration timeout = const Duration(seconds: 5),
  Duration step = const Duration(milliseconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await done()) {
    if (DateTime.now().isAfter(deadline)) return;
    await Future<void>.delayed(step);
  }
}

/// То же в виджет-тесте: ожидание идёт в настоящем времени, а кадры — в
/// фейковом.
///
/// Настоящая работа с диском под фейковым временем не завершается вовсе,
/// поэтому ждать приходится внутри [WidgetTester.runAsync], а
/// перестраивать дерево — снаружи.
Future<void> pumpUntil(
  WidgetTester tester,
  FutureOr<bool> Function() done, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  await tester.runAsync(() => waitUntil(done, timeout: timeout));
  await tester.pumpAndSettle();
}

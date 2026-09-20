import 'package:flutter_bloc/flutter_bloc.dart';

/// Ждёт состояния блока, которое отвечает условию.
///
/// Копия этой функции лежала в десятке тестов, и у всех одна и та же
/// ловушка: **нынешнее состояние проверяется первым**. События блок
/// обрабатывает асинхронно, но иногда успевает до того, как тест начнёт
/// слушать поток, — и ожидание того, что уже случилось, висело до
/// таймаута. Разъезжались копии и в сроке: где пять секунд, где десять.
///
/// Срок нужен, но он здесь не про скорость машины, а про то, чтобы
/// прогон не висел вечно: условие либо выполняется за миллисекунды, либо
/// не выполнится вовсе.
Future<S> waitForState<S>(
  BlocBase<S> bloc,
  bool Function(S state) condition, {
  Duration timeout = const Duration(seconds: 10),
}) {
  if (condition(bloc.state)) return Future.value(bloc.state);
  return bloc.stream.firstWhere(condition).timeout(timeout);
}

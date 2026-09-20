import 'package:evaporate/services/download/download_queue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Правила очереди — кто раньше, сколько идёт разом, кто занимает слот.
///
/// Раньше они жили внутри подъёма задач и проверялись только живой
/// загрузкой; здесь хватает одних идентификаторов.
void main() {
  late DownloadQueue queue;

  setUp(() => queue = DownloadQueue());

  /// Задачи, готовые начать, при пределе [slots] и списке уже идущих.
  List<String> starting(
    int slots, {
    Set<String> active = const {},
    Set<String> notWaiting = const {},
  }) => queue
      .readyToStart(
        slots: slots,
        isActive: active.contains,
        isWaiting: (id) => !active.contains(id) && !notWaiting.contains(id),
      )
      .toList();

  test('порядок — тот, в каком ставили', () {
    queue
      ..add('a')
      ..add('b')
      ..add('c');

    expect(queue.ids, ['a', 'b', 'c']);
    expect(queue.positionOf('b'), 1);
    expect(queue.positionOf('нет такой'), -1);
  });

  // Задачу поднимают заново после перезапуска движка, и её место в
  // очереди то же самое — в конец она от этого не уходит.
  test('повторное добавление порядок не меняет', () {
    queue
      ..add('a')
      ..add('b')
      ..add('a');

    expect(queue.ids, ['a', 'b']);
  });

  test('перестановка двигает задачу на своё место', () {
    queue
      ..add('a')
      ..add('b')
      ..add('c');

    expect(queue.moveTo('c', 0), isTrue);
    expect(queue.ids, ['c', 'a', 'b']);
  });

  // Номер приходит из интерфейса, а список мог измениться между нажатием
  // и обработкой: за границы он не выводит.
  test('номер вне списка зажимается, а не ломает очередь', () {
    queue
      ..add('a')
      ..add('b');

    expect(queue.moveTo('a', 99), isTrue);
    expect(queue.ids, ['b', 'a']);
    expect(queue.moveTo('a', -5), isTrue);
    expect(queue.ids, ['a', 'b']);
  });

  test('переставлять нечего — и незачем сообщать об успехе', () {
    queue.add('a');

    expect(queue.moveTo('нет такой', 0), isFalse);
    expect(queue.moveTo('a', 0), isFalse, reason: 'уже на месте');
  });

  test('слоты раздаются по очереди и ровно в заданном числе', () {
    queue
      ..add('a')
      ..add('b')
      ..add('c');

    expect(starting(2), ['a', 'b']);
  });

  test('занятые слоты считаются до раздачи', () {
    queue
      ..add('идёт')
      ..add('ждёт')
      ..add('тоже ждёт');

    expect(starting(2, active: {'идёт'}), ['ждёт']);
  });

  // Прежде сорвавшаяся задача держала слот: очередь её обходила, но
  // считала запущенной, и три такие запирали очередь до перезапуска.
  test('остановленные и сорвавшиеся слот не занимают и не ждут', () {
    queue
      ..add('на паузе')
      ..add('сорвалась')
      ..add('ждёт');

    expect(starting(1, notWaiting: {'на паузе', 'сорвалась'}), ['ждёт']);
  });

  test('свободных слотов нет — никого не поднимаем', () {
    queue
      ..add('идёт')
      ..add('ждёт');

    expect(starting(1, active: {'идёт'}), isEmpty);
  });

  test('снятая задача уходит из очереди', () {
    queue
      ..add('a')
      ..add('b')
      ..remove('a');

    expect(queue.ids, ['b']);

    queue.clear();
    expect(queue.ids, isEmpty);
  });
}

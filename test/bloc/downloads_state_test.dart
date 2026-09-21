import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/services/download/download_queue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Что считается задачей «в работе», решает одно место — состояние.
///
/// Прежде определений было два: метка в обойме считала идущие и на паузе,
/// а страница загрузок — всё незавершённое вне очереди, вместе с
/// сорвавшимися, и это число уходило в показание «N / предел», хотя слота
/// ни пауза, ни ошибка не держат.
void main() {
  DownloadTask task(String id, DownloadState state, {bool queued = false}) =>
      DownloadTask(id: id, name: id, state: state, isQueued: queued);

  final state = DownloadsState(
    tasks: [
      task('качается', DownloadState.active),
      task('ищет пиров', DownloadState.waiting),
      task('на паузе', DownloadState.paused),
      task('сорвалась', DownloadState.error),
      task('ждёт слота', DownloadState.waiting, queued: true),
      task('готова', DownloadState.complete),
    ],
  );

  List<String> ids(List<DownloadTask> tasks) => [for (final t in tasks) t.id];

  test('в работе — всё незавершённое вне очереди', () {
    expect(ids(state.inWork), [
      'качается',
      'ищет пиров',
      'на паузе',
      'сорвалась',
    ]);
  });

  test('слот держат только идущие', () {
    expect(ids(state.holdingSlots), ['качается', 'ищет пиров']);
  });

  test('очередь — только ждущие слота', () {
    expect(ids(state.queued), ['ждёт слота']);
  });

  group('перестановка очереди', () {
    // Место у движка своё — в общем порядке всех задач, а очередь только
    // его часть. Считать это в виджете значило бы знать там устройство
    // движка.
    test('соседа переводят в место среди всех задач', () {
      expect(state.orderIndexBefore('ждёт слота'), 4);
    });

    test('без соседа — в конец', () {
      expect(state.orderIndexBefore(null), 5);
    });

    test('пропавший сосед не двигает ничего', () {
      expect(state.orderIndexBefore('такой задачи нет'), isNull);
      expect(const DownloadsState().orderIndexBefore(null), isNull);
    });

    // [a, b, c], «a перед c»: номер соседа — 2, но вынутая `a` сдвигает
    // `c` на место 1, и moveTo(a, 2) ставил её после c — [b, c, a]. Все
    // тесты двигали только вверх.
    test('вниз по очереди задача встаёт перед соседом, а не за ним', () {
      DownloadTask waiting(String id) => DownloadTask(
        id: id,
        name: id,
        state: DownloadState.waiting,
        isQueued: true,
      );
      final three = DownloadsState(
        tasks: [waiting('a'), waiting('b'), waiting('c')],
      );
      final queue = DownloadQueue()
        ..add('a')
        ..add('b')
        ..add('c');

      queue.moveTo('a', three.orderIndexBefore('c', moving: 'a')!);
      expect(queue.ids, ['b', 'a', 'c']);

      // Вверх — как было.
      final up = DownloadQueue()
        ..add('a')
        ..add('b')
        ..add('c');
      up.moveTo('c', three.orderIndexBefore('a', moving: 'c')!);
      expect(up.ids, ['c', 'a', 'b']);
    });
  });
}

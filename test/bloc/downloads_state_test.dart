import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/models/download_task.dart';
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
  });
}

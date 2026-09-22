import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Барьер «обработчики всех блоков закончили» вместо паузы.
///
/// «Ничего не произошло за 50 мс» проходит вхолостую на медленной машине:
/// обработчик просто не успел. А положительная проверка после паузы там же
/// плавает. Наблюдатель считает события, принятые и отработанные каждым
/// блоком, и [settle] ждёт, пока в работе не останется ни одного, — сколько
/// бы это ни заняло.
///
/// Ставится на время одного теста (`installHandlerTracker` в `setUp`):
/// `Bloc.observer` общий на весь файл, и прежний возвращается на место.
class HandlerTracker extends BlocObserver {
  final _pending = <BlocBase<dynamic>, int>{};

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    _pending[bloc] = (_pending[bloc] ?? 0) + 1;
  }

  @override
  void onDone(
    Bloc<dynamic, dynamic> bloc,
    Object? event, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    super.onDone(bloc, event, error, stackTrace);
    // Событие, принятое до того, как наблюдателя поставили, в счёт не
    // вошло — и уводить счёт в минус оно не должно.
    final left = (_pending[bloc] ?? 0) - 1;
    _pending[bloc] = left < 0 ? 0 : left;
  }

  bool get idle => _pending.values.every((count) => count == 0);

  /// Дожидается, пока у всех блоков не останется обработчиков в работе.
  ///
  /// Спокойствие проверяется два оборота подряд: закончившись, обработчик
  /// мог передать соседнему блоку событие через поток, и оно доходит
  /// оборотом позже.
  Future<void> settle({Duration timeout = const Duration(seconds: 10)}) async {
    final deadline = DateTime.now().add(timeout);
    var calm = 0;
    while (calm < 2) {
      await Future<void>.delayed(Duration.zero);
      calm = idle ? calm + 1 : 0;
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('обработчики блоков не закончились', timeout);
      }
    }
  }
}

/// Ставит [HandlerTracker] на время теста и возвращает его.
HandlerTracker installHandlerTracker() {
  final previous = Bloc.observer;
  final tracker = HandlerTracker();
  Bloc.observer = tracker;
  addTearDown(() => Bloc.observer = previous);
  return tracker;
}

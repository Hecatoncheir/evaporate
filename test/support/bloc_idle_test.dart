import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bloc_idle.dart';

/// Барьер обязан ждать настоящего конца обработчика: иначе «ничего не
/// произошло» снова проходило бы вхолостую — только уже без паузы.
void main() {
  late HandlerTracker handlers;
  setUp(() => handlers = installHandlerTracker());

  test('ждёт обработчик, сколько бы тот ни шёл', () async {
    final gate = Completer<void>();
    final bloc = _Slow(gate.future);
    addTearDown(bloc.close);

    bloc.add(const _Go());
    var settled = false;
    unawaited(handlers.settle().then((_) => settled = true));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(settled, isFalse, reason: 'барьер не дождался обработчика');

    gate.complete();
    await handlers.settle();
    expect(bloc.state, 1);
  });

  test('ждёт и событие, которое обработчик передал дальше', () async {
    final second = _Slow(Future.value());
    final first = _Relay(second);
    addTearDown(first.close);
    addTearDown(second.close);

    first.add(const _Go());
    await handlers.settle();

    expect(second.state, 1);
  });

  test('без событий расходится сразу', () async {
    await handlers.settle(timeout: const Duration(seconds: 1));
  });
}

final class _Go {
  const _Go();
}

class _Slow extends Bloc<_Go, int> {
  _Slow(Future<void> gate) : super(0) {
    on<_Go>((event, emit) async {
      await gate;
      emit(state + 1);
    });
  }
}

/// Передаёт событие соседу через поток — так, как блоки приложения
/// подписаны друг на друга.
class _Relay extends Bloc<_Go, int> {
  _Relay(_Slow next) : super(0) {
    on<_Go>((event, emit) async {
      await Future<void>.delayed(Duration.zero);
      emit(state + 1);
    });
    _forward = stream.listen((_) => next.add(const _Go()));
  }

  late final StreamSubscription<int> _forward;

  @override
  Future<void> close() async {
    await _forward.cancel();
    return super.close();
  }
}

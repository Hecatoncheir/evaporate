import 'dart:async';
import 'dart:io';

import 'package:evaporate/bloc/logging_observer.dart';
import 'package:evaporate/services/system/app_log.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir.dart';

/// Счётчик: событие прибавляет единицу, а «сломай» роняет обработчик.
class _CounterBloc extends Bloc<String, int> {
  _CounterBloc() : super(0) {
    on<String>((event, emit) {
      if (event == 'сломай') throw StateError('обработчик не справился');
      emit(state + 1);
    });
  }
}

void main() {
  late Directory tmp;
  late AppLog log;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_observer_');
    log = AppLog(
      path: p.join(tmp.path, 'evaporate.log'),
      previousPath: p.join(tmp.path, 'evaporate.1.log'),
    );
    AppLog.instance = log;
  });

  tearDown(() async {
    AppLog.instance = AppLog(path: '', previousPath: '');
    try {
      await deleteTempDir(tmp);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  Future<String> written() async {
    await log.flush();
    final file = File(log.path);
    return file.existsSync() ? file.readAsString() : '';
  }

  // Ошибка блока раньше печаталась в консоль, которой у человека нет.
  test('сбой блока доходит до журнала', () async {
    Bloc.observer = const LoggingBlocObserver(verbose: false);
    addTearDown(
      () => Bloc.observer = const LoggingBlocObserver(verbose: false),
    );
    // Блок пробрасывает пойманное дальше, в зону: ловим его здесь, иначе
    // упадёт сам тест, а проверяем мы не это.
    await runZonedGuarded(() async {
      final bloc = _CounterBloc();
      bloc.add('сломай');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await bloc.close();
    }, (error, stack) {});

    final text = await written();
    expect(text, contains('_CounterBloc'));
    expect(text, contains('обработчик не справился'));
  });

  // Движок загрузок шлёт своё состояние каждую секунду на каждую задачу:
  // рассказ о случившемся утонул бы в этой ленте.
  test('в обычной сборке переходы в журнал не идут', () async {
    Bloc.observer = const LoggingBlocObserver(verbose: false);
    addTearDown(
      () => Bloc.observer = const LoggingBlocObserver(verbose: false),
    );
    final bloc = _CounterBloc();

    bloc.add('плюс');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await bloc.close();

    expect(await written(), isEmpty);
  });

  test('в отладке видно, какое событие что изменило', () async {
    Bloc.observer = const LoggingBlocObserver(verbose: true);
    addTearDown(
      () => Bloc.observer = const LoggingBlocObserver(verbose: false),
    );
    final bloc = _CounterBloc();

    bloc.add('плюс');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await bloc.close();

    expect(await written(), contains('_CounterBloc: String'));
  });
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/system/app_log.dart';
import 'notice.dart';

/// Состояние с указателями занятости и одноразовым сообщением.
///
/// Нужен затем, чтобы общее у блоков жило примесью: без него она не могла
/// бы ни прочитать `busy`, ни собрать новое состояние.
abstract interface class BusyState<S> {
  /// Ключи выполняющихся операций — виджетам не нужен собственный `_busy`.
  Set<String> get busy;

  Notice? get notice;

  /// Копия с другим набором занятых ключей.
  ///
  /// `notice` не задан — прежнее сообщение остаётся: молчаливая работа не
  /// должна гасить то, что человек ещё не прочитал.
  S withBusy(Set<String> busy, {Notice? notice});
}

/// Одноразовые сообщения: у каждого свой номер, ошибки идут ещё и в журнал.
///
/// Номер обязателен: без него два одинаковых сообщения подряд считались бы
/// одним состоянием, и второе не показалось бы вовсе.
mixin NoticeBloc<S> on BlocBase<S> {
  /// Как назвать себя в журнале: «библиотека», «загрузки», «сохранения».
  String get logTag;

  int _seq = 0;

  Notice notice(String message, {bool isError = false}) {
    // SnackBar живёт секунды, а рассказ о случившемся доходит через день.
    if (isError) AppLog.instance.write('$logTag: $message');
    return Notice(message: message, seq: ++_seq, isError: isError);
  }
}

/// Занятость операций: взвести ключ, погасить, рассказать о случившемся.
mixin BusyBloc<E, S extends BusyState<S>> on Bloc<E, S>, NoticeBloc<S> {
  /// Набор занятых ключей с добавленным или убранным [key].
  Set<String> busyWith(String key, {required bool value}) {
    final next = Set<String>.from(state.busy);
    if (value) {
      next.add(key);
    } else {
      next.remove(key);
    }
    return next;
  }

  /// Гасит указатель занятости и, если есть что сказать, показывает
  /// сообщение. Работа, которую человек не просил, идёт молча — ей
  /// сообщение не нужно.
  void finishBusy(
    Emitter<S> emit,
    String key, {
    String? message,
    bool isError = false,
  }) {
    emit(
      state.withBusy(
        busyWith(key, value: false),
        notice: message == null ? null : notice(message, isError: isError),
      ),
    );
  }

  /// Взводит ключ, делает работу и гасит ключ — что бы с работой ни
  /// случилось.
  ///
  /// Гашение в `finally` не ради красоты: обработчик, упавший на чужом
  /// исключении, оставлял клавишу погашенной навсегда, и починить это
  /// человек мог только перезапуском.
  ///
  /// Работа возвращает то, что сказать человеку, или `null` — если
  /// говорить нечего.
  Future<void> busyWhile(
    Emitter<S> emit,
    String key,
    Future<String?> Function() work,
  ) async {
    emit(state.withBusy(busyWith(key, value: true)));
    String? message;
    var isError = false;
    try {
      message = await work();
    } on Object catch (error) {
      message = error.toString();
      isError = true;
    } finally {
      finishBusy(emit, key, message: message, isError: isError);
    }
  }
}

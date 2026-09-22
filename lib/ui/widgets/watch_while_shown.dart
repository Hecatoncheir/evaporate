import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Подписка на блок, которая молчит, пока раздел скрыт.
///
/// Разделы живут в `IndexedStack` все разом: невидимый не выброшен, а
/// только не нарисован, и подписка целиком перестраивала его на каждую
/// перемену — у загрузок это снимок задач каждую секунду, пока человек
/// смотрит в библиотеку. Скрытому разделу `FadeIndexedStack` выключает
/// `TickerMode`, и селектор тогда отдаёт постоянное `null`: перестраиваться
/// не от чего. Показался — перестройку вызывает смена `TickerMode`, и
/// раздел читает свежее.
extension WatchWhileShown on BuildContext {
  S watchWhileShown<B extends StateStreamable<S>, S>() =>
      selectWhileShown<B, S, S>((state) => state);

  /// То же, но только часть состояния: раздел перестраивается, когда
  /// меняется она, а не любое поле рядом.
  T selectWhileShown<B extends StateStreamable<S>, S, T>(
    T Function(S state) selector,
  ) {
    final shown = TickerMode.valuesOf(this).enabled;
    return select<B, T?>((bloc) => shown ? selector(bloc.state) : null) ??
        selector(read<B>().state);
  }
}

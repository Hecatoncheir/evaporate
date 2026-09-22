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
  S watchWhileShown<B extends StateStreamable<S>, S>() {
    final shown = TickerMode.valuesOf(this).enabled;
    return select<B, S?>((bloc) => shown ? bloc.state : null) ??
        read<B>().state;
  }
}

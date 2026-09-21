import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/system/app_log.dart';
import 'frequent_event.dart';

/// Сводит в журнал то, что случилось у блоков.
///
/// Ошибка блока раньше не доходила никуда: `Notice` о ней узнавал только
/// тот обработчик, который её поймал сам, — а упавший `emit` или
/// брошенное из обработчика исключение просто печатались в консоль,
/// которой у человека нет.
///
/// **Имя каждого события пишется всегда**, и в выпускной сборке тоже: это
/// тот самый «журнал причин», ради которого приложение держится Bloc, — у
/// события есть имя, и по журналу видно, что человек нажал и что пришло
/// извне. Прежде события писались только в отладке, то есть у человека
/// журнала причин не было вовсе, и о паузе, отмене или перестановке —
/// событиях, не меняющих состояние, — не оставалось следа нигде. Пишется
/// только имя, не содержимое: пароль прокси в журнал не попадает.
///
/// Частые события ([FrequentEvent]) не пишутся: движок загрузок сообщает о
/// задачах каждую секунду, и рассказ о случившемся утонул бы в этой ленте.
/// Переходы «событие → состояние» с изменением — только в отладке.
class LoggingBlocObserver extends BlocObserver {
  const LoggingBlocObserver({this.verbose = kDebugMode});

  /// Писать ли ещё и переходы и стек ошибок.
  final bool verbose;

  @override
  void onEvent(Bloc<Object?, Object?> bloc, Object? event) {
    if (event is! FrequentEvent) {
      AppLog.instance.write('${bloc.runtimeType}: ${event.runtimeType}');
    }
    super.onEvent(bloc, event);
  }

  @override
  void onError(BlocBase<Object?> bloc, Object error, StackTrace stackTrace) {
    AppLog.instance.write(
      '${bloc.runtimeType}: сбой',
      error,
      verbose ? stackTrace : null,
    );
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onTransition(
    Bloc<Object?, Object?> bloc,
    Transition<Object?, Object?> transition,
  ) {
    if (verbose && transition.event is! FrequentEvent) {
      AppLog.instance.write(
        '${bloc.runtimeType}: ${transition.event.runtimeType} изменил состояние',
      );
    }
    super.onTransition(bloc, transition);
  }
}

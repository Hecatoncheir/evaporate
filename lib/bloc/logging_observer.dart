import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/system/app_log.dart';

/// Сводит в журнал то, что случилось у блоков.
///
/// Ошибка блока раньше не доходила никуда: `Notice` о ней узнавал только
/// тот обработчик, который её поймал сам, — а упавший `emit` или
/// брошенное из обработчика исключение просто печатались в консоль,
/// которой у человека нет.
///
/// Переходы пишем только в отладочной сборке, и это не осторожность, а
/// смысл журнала: он существует ради рассказа о том, что случилось у
/// человека, а не ради ленты из сотен строк в секунду, в которой этот
/// рассказ утонет. Движок загрузок шлёт `EngineStatsChanged` каждую
/// секунду на каждую задачу.
class LoggingBlocObserver extends BlocObserver {
  const LoggingBlocObserver({this.verbose = kDebugMode});

  /// Писать ли ещё и переходы «событие → состояние».
  final bool verbose;

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
    if (verbose) {
      AppLog.instance.write(
        '${bloc.runtimeType}: ${transition.event.runtimeType}',
      );
    }
    super.onTransition(bloc, transition);
  }
}

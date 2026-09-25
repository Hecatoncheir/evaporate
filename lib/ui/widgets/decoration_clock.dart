import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'frame_step.dart';
import 'window_visibility.dart';

/// Часы украшения: тикер, шаг между кадрами и одно правило, когда им идти.
///
/// Правило «можно ли двигаться» ([decorationMayRun]) прежде было выписано
/// в четырёх местах, а тикер с шагом кадра — в трёх, и копии расходились:
/// фон библиотеки при запуске не спрашивал, видно ли окно. Украшение с
/// этими часами говорит только своё — хочет ли оно кадров ([wantsFrames])
/// и что делать с шагом ([onFrame]); когда стоять, решают часы.
///
/// Пересчитываются часы при смене зависимостей (просьба не двигаться,
/// `TickerMode`, маршрут), виджета и видимости окна. Украшение, у которого
/// желание кадров меняется само — плитка, вернувшаяся в покой, — зовёт
/// [syncClock] и из кадра.
mixin DecorationClock<T extends StatefulWidget>
    on SingleTickerProviderStateMixin<T> {
  late final Ticker _clock = createTicker(_frame);
  final _step = FrameStep();
  late final _lifecycle = _LifecycleHook(syncClock);

  /// Хочет ли украшение кадров само: включено ли оно, есть ли чему
  /// двигаться. Окно, система и маршрут сюда не входят — их спросят часы.
  bool get wantsFrames;

  /// Кадр часов: [dt] — шаг в секундах, ограниченный сверху ([FrameStep]).
  void onFrame(double dt);

  /// Идут ли часы и не заглушены ли.
  @visibleForTesting
  bool get isAnimating => _clock.isActive && !_clock.muted;

  /// Идут ли часы — для самого украшения: без них, например, частицам не
  /// за чем следить курсором.
  bool get clockRunning => _clock.isActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncClock();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncClock();
  }

  /// Пускает или останавливает часы по правилу. Отсчёт прошлого кадра
  /// сбрасывается на обеих границах: после паузы первый шаг вышел бы
  /// длиной во всю паузу.
  @mustCallSuper
  void syncClock() {
    final run = wantsFrames && decorationMayRun(context);
    if (run == _clock.isActive) return;
    _step.reset();
    if (run) {
      _clock.start();
    } else {
      _clock.stop();
    }
  }

  void _frame(Duration elapsed) {
    final dt = _step.next(elapsed);
    if (dt != null) onFrame(dt);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycle);
    _clock.dispose();
    super.dispose();
  }
}

/// Наблюдатель за окном отдельным объектом: миксин часов не может сам
/// быть `WidgetsBindingObserver`, не требуя этого от каждого украшения.
/// `AppLifecycleListener` не годится — он проверяет порядок переходов
/// утверждениями, а настольные системы переходят как придётся.
class _LifecycleHook with WidgetsBindingObserver {
  _LifecycleHook(this.onChange);

  final VoidCallback onChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => onChange();
}

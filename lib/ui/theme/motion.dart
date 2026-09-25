import 'package:flutter/material.dart';

/// Моторика интерфейса: длительности и кривые в одном месте.
///
/// Разбросанные по виджетам `Duration(milliseconds: 120)` расходятся сами
/// собой — соседние элементы начинают двигаться с разной скоростью, и
/// собранного ощущения не выходит. Здесь их четыре ступени, и каждая
/// означает роль, а не число.
///
/// Ступени одни на обе схемы. Дневной корпус отличается материалом —
/// плоским цветом и тем, что не светится, — но не темпом: приложение,
/// которое в светлой теме двигается иначе, читается как другое приложение.
class EvaporateMotion extends ThemeExtension<EvaporateMotion> {
  const EvaporateMotion({
    required this.instant,
    required this.fast,
    required this.base,
    required this.slow,
    required this.track,
    required this.stagger,
    required this.staggerLimit,
  });

  /// Переключение состояния, у которого нет промежутка по смыслу:
  /// галочка, цвет значка, рамка фокуса.
  final Duration instant;

  /// Ответ на нажатие и наведение — то, что должно поспевать за рукой.
  final Duration fast;

  /// Основная ступень: проявления, переезды, смена содержимого панели.
  final Duration base;

  /// Появление крупного: обложка героя, всход полки, переход раздела.
  final Duration slow;

  /// Ход полосы, которую двигают сообщения извне: прогресс загрузки. Чуть
  /// дольше, чем приходят сообщения о ходе, — полоса едет непрерывно, не
  /// успевая замереть между ними. Ступенью, а не числом в виджете: число
  /// шло мимо системной просьбы не двигаться.
  final Duration track;

  /// Шаг задержки между соседними плитками при всходе полки.
  final Duration stagger;

  /// Сколько плиток успевают набрать задержку. Без предела полка из
  /// шестидесяти игр всходила бы три секунды, и последние ряды человек
  /// увидел бы уже после того, как начал их искать.
  final int staggerLimit;

  /// Кинематографичное затухание: быстрый старт, долгая остановка. Им
  /// двигается почти всё — оно и задаёт «дорогой» характер оболочки.
  static const ease = Cubic(0.16, 1, 0.3, 1);

  /// Появление снизу вверх: тот же характер, но мягче на старте.
  static const enter = Cubic(0.22, 1, 0.36, 1);

  /// Уход с экрана. Обратная [enter]: разгоняется и обрывается.
  static const exit = Cubic(0.4, 0, 0.9, 0.4);

  static const standard = EvaporateMotion(
    instant: Duration(milliseconds: 120),
    fast: Duration(milliseconds: 200),
    base: Duration(milliseconds: 380),
    slow: Duration(milliseconds: 760),
    track: Duration(milliseconds: 900),
    stagger: Duration(milliseconds: 55),
    staggerLimit: 12,
  );

  /// Всё выключено. Возвращается, когда система просит не двигаться.
  static const still = EvaporateMotion(
    instant: Duration.zero,
    fast: Duration.zero,
    base: Duration.zero,
    slow: Duration.zero,
    track: Duration.zero,
    stagger: Duration.zero,
    staggerLimit: 0,
  );

  /// Задержка появления плитки с этим номером в полке.
  Duration staggerAt(int index) =>
      stagger * (index < staggerLimit ? index : staggerLimit);

  @override
  EvaporateMotion copyWith({
    Duration? instant,
    Duration? fast,
    Duration? base,
    Duration? slow,
    Duration? track,
    Duration? stagger,
    int? staggerLimit,
  }) => EvaporateMotion(
    instant: instant ?? this.instant,
    fast: fast ?? this.fast,
    base: base ?? this.base,
    slow: slow ?? this.slow,
    track: track ?? this.track,
    stagger: stagger ?? this.stagger,
    staggerLimit: staggerLimit ?? this.staggerLimit,
  );

  @override
  EvaporateMotion lerp(ThemeExtension<EvaporateMotion>? other, double t) {
    if (other is! EvaporateMotion) return this;
    final k = t.clamp(0.0, 1.0);
    Duration mix(Duration a, Duration b) => Duration(
      microseconds:
          (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * k)
              .round(),
    );
    return EvaporateMotion(
      instant: mix(instant, other.instant),
      fast: mix(fast, other.fast),
      base: mix(base, other.base),
      slow: mix(slow, other.slow),
      track: mix(track, other.track),
      stagger: mix(stagger, other.stagger),
      staggerLimit: t < 0.5 ? staggerLimit : other.staggerLimit,
    );
  }
}

/// Короткий доступ: `context.motion.base`.
///
/// Здесь же соблюдается системная просьба не двигаться: проверять её в
/// каждом виджете значило бы однажды забыть — а забытое место выглядит
/// поломкой именно у того, кому анимации мешают.
extension EvaporateMotionAccess on BuildContext {
  EvaporateMotion get motion {
    if (MediaQuery.maybeOf(this)?.disableAnimations ?? false) {
      return EvaporateMotion.still;
    }
    return Theme.of(this).extension<EvaporateMotion>() ??
        EvaporateMotion.standard;
  }
}

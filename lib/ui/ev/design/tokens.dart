import 'package:flutter/widgets.dart';

/// Палитра. Три температуры источника света на одной земле.
///
/// Земля во всех трёх почти чёрная с уходом в фиолетовый и никогда не чистый
/// `#000`: на OLED чистый чёрный даёт ступеньку на градиентах.
@immutable
class EvColors {
  const EvColors({
    required this.ground,
    required this.sub,
    required this.surface,
    required this.raised,
    required this.line,
    required this.lineSoft,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.hot1,
    required this.hot2,
    required this.hotDeep,
    required this.cool,
    required this.arc,
  });

  /// Земля окна. Не осветляется даже под модальным окном.
  final Color ground;

  /// Подложка героя.
  final Color sub;

  /// Панели и карточки.
  final Color surface;

  /// Поповеры и палитра команд — только то, что лежит поверх модального слоя.
  final Color raised;

  final Color line;
  final Color lineSoft;

  final Color ink;
  final Color ink2;
  final Color ink3;

  /// Метки и неактивное. Ниже 12 px не используется.
  final Color ink4;

  /// Акцент. Насыщенная заливка — не больше одного объекта на экран.
  final Color hot1;
  final Color hot2;
  final Color hotDeep;

  /// Данные, приём, пиры. Только для чисел и графиков, никогда для кнопок.
  final Color cool;

  final Color arc;

  /// Семантика одна во всех темах и не заменяет акцент.
  static const ok = Color(0xFF3BE39B);
  static const warn = Color(0xFFFFC24D);
  static const bad = Color(0xFFFF4D5E);

  static const magma = EvColors(
    ground: Color(0xFF06060A),
    sub: Color(0xFF0A0B11),
    surface: Color(0xFF0E0F16),
    raised: Color(0xFF15161F),
    line: Color(0xFF22242F),
    lineSoft: Color(0xFF191B24),
    ink: Color(0xFFF2F3F7),
    ink2: Color(0xFFA8ACBD),
    ink3: Color(0xFF6E7387),
    ink4: Color(0xFF464A5C),
    hot1: Color(0xFFFF7A18),
    hot2: Color(0xFFFFC24D),
    hotDeep: Color(0xFFC93A05),
    cool: Color(0xFF5EE7FF),
    arc: Color(0xFFA66BFF),
  );

  static const nebula = EvColors(
    ground: Color(0xFF07050D),
    sub: Color(0xFF0B0814),
    surface: Color(0xFF100C1B),
    raised: Color(0xFF181226),
    line: Color(0xFF2A2140),
    lineSoft: Color(0xFF1E1830),
    ink: Color(0xFFF2F3F7),
    ink2: Color(0xFFB0A4C8),
    ink3: Color(0xFF7A6F92),
    ink4: Color(0xFF464A5C),
    hot1: Color(0xFFC15BFF),
    hot2: Color(0xFFFF4FD8),
    hotDeep: Color(0xFF6C15A8),
    cool: Color(0xFF37D6FF),
    arc: Color(0xFFFF8AE0),
  );

  static const cryo = EvColors(
    ground: Color(0xFF04070D),
    sub: Color(0xFF070B13),
    surface: Color(0xFF0B1019),
    raised: Color(0xFF111823),
    line: Color(0xFF1E2836),
    lineSoft: Color(0xFF161E2A),
    ink: Color(0xFFF2F3F7),
    ink2: Color(0xFF9FB0C6),
    ink3: Color(0xFF647588),
    ink4: Color(0xFF464A5C),
    hot1: Color(0xFF3B82F6),
    hot2: Color(0xFF22D3EE),
    hotDeep: Color(0xFF0B3F8F),
    cool: Color(0xFFFF6B3D),
    arc: Color(0xFF8FB6FF),
  );

  /// Заливка кнопки «Играть». Горячее всегда сверху-слева.
  LinearGradient get playFill => LinearGradient(
    begin: const Alignment(-0.9, -0.6),
    end: const Alignment(0.9, 0.6),
    colors: [hot2, hot1, hotDeep],
    stops: const [0.0, 0.58, 1.0],
  );

  static EvColors lerp(EvColors a, EvColors b, double t) => EvColors(
    ground: Color.lerp(a.ground, b.ground, t)!,
    sub: Color.lerp(a.sub, b.sub, t)!,
    surface: Color.lerp(a.surface, b.surface, t)!,
    raised: Color.lerp(a.raised, b.raised, t)!,
    line: Color.lerp(a.line, b.line, t)!,
    lineSoft: Color.lerp(a.lineSoft, b.lineSoft, t)!,
    ink: Color.lerp(a.ink, b.ink, t)!,
    ink2: Color.lerp(a.ink2, b.ink2, t)!,
    ink3: Color.lerp(a.ink3, b.ink3, t)!,
    ink4: Color.lerp(a.ink4, b.ink4, t)!,
    hot1: Color.lerp(a.hot1, b.hot1, t)!,
    hot2: Color.lerp(a.hot2, b.hot2, t)!,
    hotDeep: Color.lerp(a.hotDeep, b.hotDeep, t)!,
    cool: Color.lerp(a.cool, b.cool, t)!,
    arc: Color.lerp(a.arc, b.arc, t)!,
  );
}

/// Потолок радиуса. По умолчанию 8 px — приборная геометрия.
///
/// Градация сохранена, просто сжата: чипы острее панелей, панели острее героя.
/// Стадионов в системе нет — кнопка запуска скруглена так же, как панель.
@immutable
class EvRadii {
  const EvRadii({
    required this.r1,
    required this.r2,
    required this.r3,
    required this.r4,
    required this.r5,
    required this.pill,
  });

  /// Чипы и микрометки.
  final double r1;

  /// Кнопки.
  final double r2;

  /// Карточки и обложки.
  final double r3;

  /// Панели.
  final double r4;

  /// Герой и модалки.
  final double r5;

  /// То, что раньше было стадионом.
  final double pill;

  /// Приборная геометрия — по умолчанию.
  static const tight = EvRadii(r1: 3, r2: 5, r3: 7, r4: 8, r5: 8, pill: 8);

  /// Промежуточный потолок.
  static const soft = EvRadii(r1: 6, r2: 10, r3: 16, r4: 22, r5: 24, pill: 24);

  /// Прежняя шкала со стадионами.
  static const full = EvRadii(r1: 6, r2: 10, r3: 16, r4: 22, r5: 30, pill: 999);

  BorderRadius get b1 => BorderRadius.circular(r1);
  BorderRadius get b2 => BorderRadius.circular(r2);
  BorderRadius get b3 => BorderRadius.circular(r3);
  BorderRadius get b4 => BorderRadius.circular(r4);
  BorderRadius get b5 => BorderRadius.circular(r5);
  BorderRadius get bPill => BorderRadius.circular(pill);

  static EvRadii lerp(EvRadii a, EvRadii b, double t) => EvRadii(
    r1: _l(a.r1, b.r1, t),
    r2: _l(a.r2, b.r2, t),
    r3: _l(a.r3, b.r3, t),
    r4: _l(a.r4, b.r4, t),
    r5: _l(a.r5, b.r5, t),
    pill: _l(a.pill, b.pill, t),
  );

  static double _l(double a, double b, double t) => a + (b - a) * t;
}

/// Тайминги и кривые. Длительности кратны 40 мс.
///
/// Всё, что появляется, приходит с ускорением наружу; всё, что исчезает,
/// уходит линейно и быстро.
abstract final class EvMotion {
  static const easeOut = Cubic(0.16, 1, 0.3, 1);
  static const ease = Cubic(0.22, 0.9, 0.24, 1);

  /// Наведение на карточку.
  static const hover = Duration(milliseconds: 400);

  /// Смена раздела.
  static const screen = Duration(milliseconds: 340);

  /// Смена раздела, движение: экран проявляется за [screen], а «доезжает»
  /// на место ещё сотню миллисекунд — так он садится, а не выскакивает.
  static const screenSettle = Duration(milliseconds: 440);

  /// Удержание кнопки «Играть». Защита от случайного запуска.
  static const hold = Duration(milliseconds: 620);

  /// Ритуал запуска: шесть стадий.
  static const ritual = Duration(milliseconds: 2600);

  /// Палитра команд.
  static const popover = Duration(milliseconds: 280);

  /// Дыхание ядра.
  static const breathe = Duration(milliseconds: 3600);

  static const fast = Duration(milliseconds: 200);
}

/// Шаг сетки. Отступы кратны четырём.
/// Цвет аватара. Градиенты из прототипа: первые три идут от облика,
/// четвёртый — зелёный «в сети», два последних в палитру интерфейса
/// не входят и нужны только чтобы шесть соседних кружков различались.
enum EvAvatarTint { hot, cool, arc, ok, rose, sky }

abstract final class EvSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Боковое поле экрана — значение по умолчанию, когда размер окна
  /// неизвестен. В каркасе поле считается по окну: [gutterFor].
  static const gutter = 28.0;

  /// Боковое поле для окна данного размера. Те же ступени, что в прототипе:
  /// 2,2 % ширины в пределах 16…30; на низких окнах (до 800) — 18, чтобы
  /// полка помещалась под героем; от 1800 по ширине — 30…44, и это правило
  /// сильнее высоты, как в CSS, где оно объявлено позже.
  static double gutterFor(Size window) {
    final fluid = window.width * 0.022;
    if (window.width >= 1800) return fluid.clamp(30.0, 44.0).roundToDouble();
    if (window.height <= 800) return 18;
    return fluid.clamp(16.0, 30.0).roundToDouble();
  }

  /// Каркас окна.
  static const railWidth = 76.0;
  static const topBarHeight = 58.0;
  static const hintsHeight = 32.0;
  static const bottomNavHeight = 60.0;

  /// Уже этого окно теряет рейл и строку подсказок: навигация уходит вниз.
  static const narrowBreakpoint = 760.0;
}

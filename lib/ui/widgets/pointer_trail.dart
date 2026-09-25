import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'decoration_clock.dart';

/// Курсор над окном — один на все украшения, которые за ним тянутся.
///
/// Прежде курсор у каждого украшения был свой: волна держала сглаженное
/// положение в своём художнике, частицы ловили его своим `MouseRegion`. Два
/// источника одного и того же расходятся, а украшений, которым нужен
/// курсор, становится больше. Здесь положение одно, в долях области
/// оболочки, и сглажено одними часами.
///
/// [value] догоняет [target] — 5,5 % пути за кадр при 60 Гц, пересчитанные
/// во время: на экране 120 Гц курсор не должен догоняться вдвое быстрее.
/// Сырое [target] нужно тому, кто отвечает на курсор сразу, — частицам.
class PointerTrail extends ChangeNotifier implements ValueListenable<Offset> {
  PointerTrail();

  /// Где курсор, пока его не было: чуть выше середины, как у прототипа, —
  /// туда смотрит взгляд, пока рука не взялась за мышь.
  static const rest = Offset(0.5, 0.4);

  /// Ближе этого значение считается догнавшим: на слое глубиной в
  /// тридцать точек это сотая доля точки.
  static const settleDistance = 5e-4;

  Offset _value = rest;
  Offset _target = rest;
  bool _hasInput = false;
  RenderBox? Function() _area = _noArea;

  /// Сглаженное положение, в долях области.
  @override
  Offset get value => _value;

  /// Куда курсор смотрит сейчас, без сглаживания.
  Offset get target => _target;

  /// Над областью ли курсор. Нет — когда он ушёл или ещё не приходил:
  /// тогда отвечать на него незачем.
  bool get hasInput => _hasInput;

  /// Значение ещё не догнало цель — часам есть что делать.
  bool get settling => _value != _target;

  /// Курсор над областью в [fraction] её размера.
  void aim(Offset fraction) {
    _target = fraction;
    _hasInput = true;
  }

  /// Курсор ушёл: цель возвращается к [rest].
  void leave() {
    _target = rest;
    _hasInput = false;
  }

  /// Сдвинуть значение к цели на [seconds] секунд сглаживания.
  void advance(double seconds) {
    if (!settling) return;
    final k = 1 - math.pow(1 - 0.055, seconds * 60).toDouble();
    var next = Offset.lerp(_value, _target, k)!;
    if ((_target - next).distance <= settleDistance) next = _target;
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }

  /// Поставить курсор в [fraction] сразу, без сглаживания.
  void jumpTo(Offset fraction) {
    _target = fraction;
    if (fraction == _value) return;
    _value = fraction;
    notifyListeners();
  }

  /// Доля области [fraction] — в точках [box], или `null`, если области
  /// нет: оболочка не собрана, или [box] не в ней.
  Offset? localIn(RenderBox box, Offset fraction) {
    final area = _area();
    if (area == null || !area.attached || !area.hasSize || !box.attached) {
      return null;
    }
    final point = Offset(
      fraction.dx * area.size.width,
      fraction.dy * area.size.height,
    );
    return box.globalToLocal(area.localToGlobal(point));
  }

  /// Курсор ближайшей оболочки, или `null` без неё — как в тестах, где
  /// украшение поднимают без окна вокруг.
  ///
  /// Ищется без подписки: курсор у оболочки один на всю её жизнь, и
  /// следить, не сменился ли он, незачем. Украшение берёт его один раз, в
  /// `didChangeDependencies`, а дальше слушает сам курсор.
  static PointerTrail? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<_PointerTrailScopeState>()?._trail;

  static RenderBox? _noArea() => null;
}

/// Ловит курсор над оболочкой и сглаживает его.
///
/// Ловит `Listener`, а не `MouseRegion`: нажатая кнопка мыши гасит события
/// наведения, а тянуть за курсором украшению нужно и когда его тащат.
/// Уход курсора из окна слышит только `MouseRegion` — он стоит рядом,
/// прозрачным, и ни у кого ничего не отнимает.
class PointerTrailScope extends StatefulWidget {
  const PointerTrailScope({super.key, required this.child});

  final Widget child;

  @override
  State<PointerTrailScope> createState() => _PointerTrailScopeState();
}

class _PointerTrailScopeState extends State<PointerTrailScope>
    with SingleTickerProviderStateMixin, DecorationClock {
  final _trail = PointerTrail();

  @override
  void initState() {
    super.initState();
    _trail._area = () => context.findRenderObject() as RenderBox?;
  }

  @override
  bool get wantsFrames => _trail.settling;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Просьба не двигаться — курсор стоит там, где стоял бы без мыши:
    // тянуться за ним украшению нельзя. Ставится после кадра: слушатели
    // курсора перестраиваются, а посреди сборки этого делать нельзя.
    if (MediaQuery.disableAnimationsOf(context)) {
      _trail.leave();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _trail.jumpTo(PointerTrail.rest);
      });
    }
  }

  @override
  void onFrame(double dt) {
    _trail.advance(dt);
    if (!_trail.settling) syncClock();
  }

  void _aim(PointerEvent event) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    final size = context.size;
    if (size == null || size.isEmpty) return;
    _trail.aim(
      Offset(
        (event.localPosition.dx / size.width).clamp(0.0, 1.0),
        (event.localPosition.dy / size.height).clamp(0.0, 1.0),
      ),
    );
    syncClock();
  }

  void _leave() {
    _trail.leave();
    syncClock();
  }

  @override
  void dispose() {
    _trail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    opaque: false,
    onExit: (_) => _leave(),
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: _aim,
      onPointerMove: _aim,
      child: widget.child,
    ),
  );
}

import 'dart:math' as math;
import 'dart:ui';

/// Одна искра. Скорости — в пикселях за кадр при 60 Гц, как в прототипе;
/// шаг симуляции переводит их во время, чтобы на 120 Гц угли не летели
/// вдвое быстрее.
class EvEmber {
  EvEmber({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.life,
    required this.phase,
    required this.sway,
    required this.cool,
  });

  double x;
  double y;
  final double vx;
  final double vy;
  final double radius;

  /// Сколько искра живёт, в секундах.
  final double life;

  double age = 0;
  double phase;
  final double sway;

  /// Холодная искра — цвета данных, а не акцента. Примерно каждая четвёртая.
  final bool cool;

  /// Доля прожитого, 0…1.
  double get progress => (age / life).clamp(0.0, 1.0);

  /// Яркость: разгорается и гаснет по синусу, пик 0.42.
  double get opacity => math.sin(math.pi * math.min(1, progress * 1.15)) * 0.42;

  /// Радиус ядра: к концу жизни искра усыхает на треть.
  double get coreRadius => radius * (1 - progress * 0.35);
}

/// Восходящие угли — перенос системы частиц из прототипа.
///
/// Одно исправление: в прототипе жизнь искры копилась в миллисекундах, а
/// сама была записана в кадрах (340…900). Искры гасли за секунду, новые
/// рождались под нижней кромкой и не успевали подняться — через пару
/// секунд все угли жили в нижних 30 px окна. Здесь жизнь — 340…900 кадров,
/// то есть 5,7…15 с, и угли поднимаются через весь экран.
class EvEmberField {
  EvEmberField({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  final List<EvEmber> embers = [];
  Size _size = Size.zero;

  /// Сколько искр нужно окну: ширина / 17 в пределах 34…104,
  /// умноженная на уровень эффектов.
  static int countFor(double width, double quality) =>
      ((width / 17).clamp(34.0, 104.0) * quality).round();

  /// Под новый размер или уровень искры рождаются заново по нижним двум
  /// третям экрана и в разных фазах жизни. В прототипе все начинали с нуля
  /// и разгорались разом; к тому же неподвижный кадр при «уменьшить
  /// движение» из таких искр был бы пустым.
  void resize(Size size, double quality) {
    final count = countFor(size.width, quality);
    if (size == _size && embers.length == count) return;
    _size = size;
    embers
      ..clear()
      ..addAll(List.generate(count, (_) => _spawn(anywhere: true)));
  }

  EvEmber _spawn({required bool anywhere}) {
    final r = _random;
    final ember = EvEmber(
      x: r.nextDouble() * _size.width,
      y: anywhere
          ? _size.height * (0.30 + r.nextDouble() * 0.72)
          : _size.height + 12,
      vy: -(0.16 + r.nextDouble() * 0.55),
      vx: (r.nextDouble() - 0.5) * 0.14,
      radius: 0.5 + r.nextDouble() * 1.7,
      life: (340 + r.nextDouble() * 560) / 60,
      phase: r.nextDouble() * 7,
      sway: 0.28 + r.nextDouble() * 0.7,
      cool: r.nextDouble() < 0.24,
    );
    if (anywhere) ember.age = r.nextDouble() * ember.life * 0.5;
    return ember;
  }

  /// Сколько живёт искра выброса, с: 84 кадра при 60 Гц.
  static const burstLife = 84 / 60;

  /// Выброс ритуала запуска — интерфейс испаряется: каждая искра срывается
  /// вверх со скоростью 1,4…4 px за кадр, в разы быстрее обычной, вбок
  /// до ±0,75, в полтора раза крупнее и живёт 1,4 с. Догоревшие рождаются
  /// снова обычными углями у нижней кромки.
  ///
  /// В прототипе у выброса осталась жизнь 1400 — миллисекунды, записанные
  /// до перевода жизни углей на кадры. После перевода это 23 с: искра
  /// разгоралась бы десять секунд и за ритуал так и не становилась видна.
  void burst() {
    final r = _random;
    for (var i = 0; i < embers.length; i++) {
      final e = embers[i];
      embers[i] = EvEmber(
        x: e.x,
        y: e.y,
        vx: (r.nextDouble() - 0.5) * 1.5,
        vy: -(1.4 + r.nextDouble() * 2.6),
        radius: e.radius * 1.5,
        life: burstLife,
        phase: e.phase,
        sway: e.sway,
        cool: e.cool,
      );
    }
  }

  /// Панель испаряется: [count] искр срываются из прямоугольника [rect]
  /// вверх и в стороны и живут 0,7…1,4 с — ритуал в миниатюре. Так
  /// уходит разобранный дайджест «Пока вас не было».
  void burstFrom(Rect rect, {int count = 90}) {
    if (embers.isEmpty) return;
    final r = _random;
    for (var i = 0; i < count; i++) {
      final e = embers[i % embers.length];
      final a = r.nextDouble() * math.pi * 2, speed = r.nextDouble();
      embers[i % embers.length] = EvEmber(
        x: rect.left + r.nextDouble() * rect.width,
        y: rect.top + r.nextDouble() * rect.height,
        vx: math.cos(a) * (.5 + speed * 2.4) * .6,
        vy: -(.8 + r.nextDouble() * 2.6),
        radius: .7 + r.nextDouble() * 2.2,
        life: (42 + r.nextDouble() * 42) / 60,
        phase: e.phase,
        sway: e.sway,
        cool: r.nextDouble() < .3,
      );
    }
  }

  /// Шаг на [dt] секунд. Длинные паузы режутся до 64 мс, как в прототипе:
  /// после сворачивания окна угли не должны разом прыгнуть вверх.
  void step(double dt) {
    final seconds = math.min(dt, 0.064);
    final frames = seconds * 60;
    for (var i = 0; i < embers.length; i++) {
      final e = embers[i];
      e.age += seconds;
      if (e.age > e.life || e.y < -20) {
        embers[i] = _spawn(anywhere: false);
        continue;
      }
      e.phase += seconds * 2.4;
      e.x += (e.vx + math.sin(e.phase) * e.sway * 0.5) * frames;
      e.y += e.vy * (1 + e.age / e.life * 0.8) * frames;
    }
  }
}

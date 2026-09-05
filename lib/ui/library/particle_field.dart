import 'dart:math' as math;
import 'dart:ui';

/// Ровно рассыпанные фоновые точки с местным притяжением к карточке.
/// Близость меняет плотность, цвет и движение, но не радиус точки: растущие
/// точки читаются как рябь, а сгущение — как свет.
class InkParticle {
  InkParticle(this.position, this.velocity, this.phase, this.life);

  static const radius = 1.25;
  Offset position;
  Offset velocity;
  final double phase;
  double life;
  double glow = 0;
}

class ParticleField {
  ParticleField({int seed = 42}) : _random = math.Random(seed);

  static const ambientCount = 4800;
  static const maxCount = ambientCount + 2000;
  static const densityMultiplier = 5.0;
  static const maxSpeed = 360.0;
  final math.Random _random;
  final List<InkParticle> particles = [];
  Size size = Size.zero;
  Rect? card;
  Offset? pointer;
  double time = 0;
  double _spawnBudget = 0;

  double _rand(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  void resize(Size value) {
    if (value.isEmpty || !value.width.isFinite || !value.height.isFinite) {
      return;
    }
    if (size == value) return;
    final previous = size;
    size = value;
    if (particles.isNotEmpty && !previous.isEmpty) {
      // При смене размера точки растягиваем, а не прижимаем к краям: иначе
      // после каждого изменения окна они сползались бы к границам.
      for (final p in particles) {
        p.position = Offset(
          p.position.dx / previous.width * size.width,
          p.position.dy / previous.height * size.height,
        );
      }
      return;
    }
    // Выборка по слоям, а не сплошь случайная: у равномерного случая
    // получаются и заметные проплешины, и различимая сетка. У каждого ряда
    // одна и та же ожидаемая плотность, включая последнюю ячейку.
    final rows = math
        .sqrt(ambientCount * size.height / size.width)
        .round()
        .clamp(1, ambientCount);
    var remaining = ambientCount;
    for (var row = 0; row < rows; row++) {
      final columns = remaining ~/ (rows - row);
      remaining -= columns;
      for (var column = 0; column < columns; column++) {
        particles.add(
          _newParticle(
            Offset(
              (column + _rand(0, 1)) * size.width / columns,
              (row + _rand(0, 1)) * size.height / rows,
            ),
            -1,
          ),
        );
      }
    }
  }

  InkParticle _newParticle(Offset position, double life) => InkParticle(
    position,
    Offset(_rand(-12, 12), _rand(-12, 12)),
    _rand(0, math.pi * 2),
    life,
  );

  /// Ближайшая точка периметра — в том числе для точек внутри карточки.
  static Offset edgePoint(Rect rect, Offset point) {
    final clamped = Offset(
      point.dx.clamp(rect.left, rect.right),
      point.dy.clamp(rect.top, rect.bottom),
    );
    if (!rect.contains(point)) return clamped;
    final distances = [
      point.dx - rect.left,
      rect.right - point.dx,
      point.dy - rect.top,
      rect.bottom - point.dy,
    ];
    final side = distances.indexOf(distances.reduce(math.min));
    return switch (side) {
      0 => Offset(rect.left, point.dy),
      1 => Offset(rect.right, point.dy),
      2 => Offset(point.dx, rect.top),
      _ => Offset(point.dx, rect.bottom),
    };
  }

  Offset? _target(Offset point) {
    final edge = card == null ? null : edgePoint(card!, point);
    final mouse = pointer;
    if (edge == null) return mouse;
    // Внутри выбранной карточки полем правит её периметр, а не центр:
    // иначе точки собирались бы в одну кучу посреди обложки.
    if (mouse == null || card!.contains(mouse)) return edge;
    return (mouse - point).distance < (edge - point).distance ? mouse : edge;
  }

  double proximity(Offset point) {
    final target = _target(point);
    if (target == null) return 0;
    return (1 - (target - point).distance / 180).clamp(0, 1);
  }

  Offset _emissionPoint() {
    final rect = card;
    Offset center;
    if (rect != null &&
        (pointer == null ||
            rect.contains(pointer!) ||
            _random.nextDouble() < 0.75)) {
      // Точку рождения берём равномерно по периметру: иначе они копятся
      // в углах и в центре.
      final d = _rand(0, 2 * (rect.width + rect.height));
      if (d < rect.width) {
        center = Offset(rect.left + d, rect.top);
      } else if (d < rect.width + rect.height) {
        center = Offset(rect.right, rect.top + d - rect.width);
      } else if (d < 2 * rect.width + rect.height) {
        center = Offset(
          rect.right - (d - rect.width - rect.height),
          rect.bottom,
        );
      } else {
        center = Offset(
          rect.left,
          rect.bottom - (d - 2 * rect.width - rect.height),
        );
      }
    } else {
      center = pointer ?? Offset(size.width / 2, size.height / 2);
    }
    final angle = _rand(0, math.pi * 2);
    final distance = _rand(10, 100);
    return center + Offset(math.cos(angle), math.sin(angle)) * distance;
  }

  void step(double seconds) {
    if (size.isEmpty || !seconds.isFinite || seconds <= 0) return;
    // Шаг ограничен сверху: после сворачивания окна или подвисшего кадра
    // симуляция иначе догоняла бы упущенное одним рывком.
    final dt = seconds.clamp(0.0, 1 / 30);
    time += dt;
    var near = 0;
    for (final p in particles) {
      final target = _target(p.position);
      final delta = target == null ? Offset.zero : target - p.position;
      final distance = delta.distance;
      final proximity = target == null
          ? 0.0
          : (1 - distance / 180).clamp(0.0, 1.0);
      final direction = distance < 0.1 ? Offset.zero : delta / distance;
      p.glow = proximity * proximity;
      if (proximity > 0.7) near++;
      var acceleration = Offset(
        math.sin(time * 1.7 + p.phase) * 50 +
            math.sin(time * 4.1 + p.phase * 3) * 18,
        math.cos(time * 1.3 + p.phase * 2) * 50 +
            math.cos(time * 3.7 + p.phase * 5) * 18,
      );
      // У притяжения конечный радиус: дальние точки продолжают бродить,
      // иначе весь фон рано или поздно всосало бы в одну карточку.
      if (target != null && proximity > 0) {
        var tangent = Offset(-direction.dy, direction.dx);
        final rect = card;
        if (rect != null && edgePoint(rect, p.position) == target) {
          tangent = target.dy == rect.top
              ? const Offset(1, 0)
              : target.dx == rect.right
              ? const Offset(0, 1)
              : target.dy == rect.bottom
              ? const Offset(-1, 0)
              : const Offset(0, -1);
        }
        final chaos = 12 + 210 * proximity * proximity;
        final boost = 1 + 1.5 * proximity * proximity;
        final noise = Offset(
          math.sin(time * (4 + proximity * 17) + p.phase * 9),
          math.cos(time * (5 + proximity * 19) + p.phase * 7),
        );
        acceleration +=
            (direction * (distance * 3.8).clamp(0, 230) * proximity +
                tangent * (proximity * 130) +
                noise * chaos) *
            boost;
      }
      p.velocity = (p.velocity + acceleration * dt) * math.exp(-2.2 * dt);
      final speed = p.velocity.distance;
      final limit = 180 + (maxSpeed - 180) * proximity * proximity;
      if (speed > limit) p.velocity = p.velocity / speed * limit;
      p.position += p.velocity * dt;
      p.position = Offset(
        (p.position.dx + size.width) % size.width,
        (p.position.dy + size.height) % size.height,
      );
      if (p.life >= 0) p.life -= dt;
    }
    particles.removeWhere((p) => p.life < 0 && p.life > -0.5);
    if (card != null || pointer != null) {
      // Чем больше точек у цели, тем больше рождается короткоживущих.
      // Жёсткий предел не даёт этому расти лавиной за долгий сеанс.
      _spawnBudget +=
          dt *
          densityMultiplier *
          (42 + math.min(near / densityMultiplier, 160) * 0.8);
      while (_spawnBudget >= 1 && particles.length < maxCount) {
        particles.add(_newParticle(_emissionPoint(), _rand(1.6, 3.2)));
        _spawnBudget--;
      }
      _spawnBudget = math.min(_spawnBudget, 1);
    } else {
      _spawnBudget = 0;
    }
  }
}

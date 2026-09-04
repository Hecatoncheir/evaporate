import 'dart:math' as math;
import 'dart:ui';

/// Fixed-size particles: attraction changes density, light and velocity,
/// never radius. Pure simulation, independent of widgets and frame rate.
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

  static const ambientCount = 240;
  static const maxCount = 640;
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
    size = value;
    for (final p in particles) {
      p.position = Offset(
        p.position.dx.clamp(0, size.width),
        p.position.dy.clamp(0, size.height),
      );
    }
    while (particles.length < ambientCount) {
      particles.add(
        _newParticle(Offset(_rand(0, size.width), _rand(0, size.height)), -1),
      );
    }
  }

  InkParticle _newParticle(Offset position, double life) => InkParticle(
    position,
    Offset(_rand(-12, 12), _rand(-12, 12)),
    _rand(0, math.pi * 2),
    life,
  );

  /// Nearest point on the perimeter, including for points inside the card.
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
    // Inside a selected card the perimeter owns the field, not its centre.
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
      // Uniform perimeter sampling; avoid a corner/centre pile-up.
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
    // No simulation catch-up burst after minimization or a stalled frame.
    final dt = seconds.clamp(0.0, 1 / 30);
    time += dt;
    var near = 0;
    for (final p in particles) {
      final target = _target(p.position);
      final proximity = this.proximity(p.position);
      p.glow = proximity * proximity;
      if (proximity > 0.7) near++;
      var acceleration = Offset(
        math.sin(time * 1.7 + p.phase) * 50 +
            math.sin(time * 4.1 + p.phase * 3) * 18,
        math.cos(time * 1.3 + p.phase * 2) * 50 +
            math.cos(time * 3.7 + p.phase * 5) * 18,
      );
      // Attraction has a finite range: distant dots keep wandering instead
      // of the entire background eventually being vacuumed into one card.
      if (target != null && proximity > 0) {
        final delta = target - p.position;
        final distance = delta.distance;
        final direction = distance < 0.1 ? Offset.zero : delta / distance;
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
        acceleration +=
            direction * (distance * 3.8).clamp(0, 230) * proximity +
            tangent * (proximity * 130) +
            Offset(
                  math.sin(time * (4 + proximity * 17) + p.phase * 9),
                  math.cos(time * (5 + proximity * 19) + p.phase * 7),
                ) *
                chaos;
      }
      p.velocity = (p.velocity + acceleration * dt) * math.exp(-2.2 * dt);
      final speed = p.velocity.distance;
      if (speed > 180) p.velocity = p.velocity / speed * 180;
      p.position += p.velocity * dt;
      p.position = Offset(
        (p.position.dx + size.width) % size.width,
        (p.position.dy + size.height) % size.height,
      );
      if (p.life >= 0) p.life -= dt;
    }
    particles.removeWhere((p) => p.life < 0 && p.life > -0.5);
    if (card != null || pointer != null) {
      // More particles near a target -> more short-lived particles emitted.
      // A hard budget prevents exponential growth during long sessions.
      _spawnBudget += dt * (42 + math.min(near, 160) * 0.8);
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

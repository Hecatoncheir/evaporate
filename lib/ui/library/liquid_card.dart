import 'dart:async';

import 'package:dough/dough.dart';
import 'package:flutter/material.dart';

/// Programmatic Dough also responds to keyboard/gamepad selection; a gesture-
/// only wrapper would leave those users without the requested deformation.
class LiquidCard extends StatefulWidget {
  const LiquidCard({
    super.key,
    required this.active,
    required this.enabled,
    required this.child,
  });
  final bool active;
  final bool enabled;
  final Widget child;

  @override
  State<LiquidCard> createState() => _LiquidCardState();
}

class _LiquidCardState extends State<LiquidCard> {
  final _dough = DoughController();
  Timer? _release;
  bool get _enabled =>
      widget.enabled && !MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(LiquidCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active ||
        widget.enabled != oldWidget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.active && _enabled) {
          _stretch(const Offset(18, -12));
          _release = Timer(const Duration(milliseconds: 140), _stop);
        } else {
          _stop();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _stop();
      });
    }
  }

  void _stretch(Offset delta) {
    _release?.cancel();
    if (!_enabled) return;
    if (_dough.isActive) {
      _dough.update(target: delta);
    } else {
      _dough.start(origin: Offset.zero, target: delta);
    }
  }

  void _stop() {
    _release?.cancel();
    if (_dough.isActive) _dough.stop();
  }

  @override
  void dispose() {
    _release?.cancel();
    _dough.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final morph = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.active ? 1 : 0),
      duration: _enabled ? const Duration(milliseconds: 420) : Duration.zero,
      curve: Curves.easeOutCubic,
      child: widget.child,
      builder: (context, amount, child) => Transform.rotate(
        angle: -0.012 * amount,
        child: Transform.scale(
          scale: 1 + 0.025 * amount,
          child: ClipPath(clipper: LiquidCardClipper(amount), child: child),
        ),
      ),
    );
    // Even with motion disabled, selection has a distinct static silhouette.
    if (!_enabled) return morph;
    return MouseRegion(
      onExit: (_) => _stop(),
      child: Listener(
        onPointerDown: (_) => _stretch(const Offset(10, 16)),
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: DoughRecipe(
          data: DoughRecipeData(
            viscosity: 2200,
            adhesion: 24,
            expansion: 1.008,
            entryDuration: const Duration(milliseconds: 110),
            exitDuration: const Duration(milliseconds: 480),
          ),
          child: Dough(controller: _dough, child: morph),
        ),
      ),
    );
  }
}

/// Changes the card itself: asymmetric rounded corners and gently bowed
/// sides, not a second shape painted around its perimeter.
class LiquidCardClipper extends CustomClipper<Path> {
  const LiquidCardClipper(this.amount);
  final double amount;

  @override
  Path getClip(Size size) {
    final t = amount.clamp(0.0, 1.0);
    final w = size.width;
    final h = size.height;
    final tl = 8 + 40 * t;
    final tr = 8 + 14 * t;
    final br = 8 + 34 * t;
    final bl = 8 + 16 * t;
    return Path()
      ..moveTo(tl, 0)
      ..cubicTo(w * 0.46, 10 * t, w * 0.72, 0, w - tr, 3 * t)
      ..quadraticBezierTo(w, 3 * t, w, tr)
      ..cubicTo(w - 12 * t, h * 0.35, w, h * 0.62, w - 3 * t, h - br)
      ..quadraticBezierTo(w - 3 * t, h - 3 * t, w - br, h - 3 * t)
      ..cubicTo(w * 0.6, h - 12 * t, w * 0.35, h, bl, h)
      ..quadraticBezierTo(0, h, 0, h - bl)
      ..cubicTo(9 * t, h * 0.66, 0, h * 0.35, 0, tl)
      ..quadraticBezierTo(0, 0, tl, 0)
      ..close();
  }

  @override
  bool shouldReclip(LiquidCardClipper oldClipper) =>
      oldClipper.amount != amount;
}

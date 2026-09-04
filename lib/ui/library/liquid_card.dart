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
    if (!_enabled) return widget.child;
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
          child: Dough(controller: _dough, child: widget.child),
        ),
      ),
    );
  }
}

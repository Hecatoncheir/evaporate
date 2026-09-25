import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../sound/ev_sound.dart';
import '../sound/voices.dart';

/// Делает элемент доступным с клавиатуры: Tab и стрелки доводят до него
/// фокус, Enter и пробел срабатывают как клик.
///
/// Рамка фокуса — 2 px цвета `hot2` с отступом 3 px, как `:focus-visible`
/// в прототипе. Мышью её не видно: она появляется только в режиме
/// клавиатурной навигации, поэтому клик по кнопке не оставляет обводки.
class EvFocusable extends StatefulWidget {
  const EvFocusable({
    super.key,
    required this.onActivate,
    required this.child,
    this.radius = 0,
    this.onFocusHighlight,
  });

  /// `null` — элемент неактивен и фокус не получает.
  final VoidCallback? onActivate;

  final Widget child;

  /// Скругление самого элемента; рамка повторяет его с поправкой на отступ.
  final double radius;

  /// Рамка фокуса появилась или исчезла. Нужна тем, кто показывает
  /// подсказку по фокусу так же, как по наведению.
  final ValueChanged<bool>? onFocusHighlight;

  @override
  State<EvFocusable> createState() => _EvFocusableState();
}

class _EvFocusableState extends State<EvFocusable> {
  bool _ring = false;

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) {
        _activate();
        return null;
      },
    ),
  };

  /// Нажатие звучит здесь — у всего, что нажимается, один голос.
  void _activate() {
    final activate = widget.onActivate;
    if (activate == null) return;
    EvSoundScope.maybeOf(context)?.play(EvVoice.tap);
    activate();
  }

  void _handleHighlight(bool value) {
    setState(() => _ring = value);
    widget.onFocusHighlight?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onActivate != null;
    return FocusableActionDetector(
      enabled: enabled,
      actions: _actions,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: _handleHighlight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onActivate == null ? null : _activate,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            if (_ring)
              Positioned(
                left: -5,
                top: -5,
                right: -5,
                bottom: -5,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.radius + 5),
                      border: Border.all(color: context.evc.hot2, width: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

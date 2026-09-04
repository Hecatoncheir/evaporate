import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gamepad_service.dart';
import 'nav_action.dart';

class SectionChangeIntent extends Intent {
  const SectionChangeIntent(this.delta);

  final int delta;
}

class PrimaryActionIntent extends Intent {
  const PrimaryActionIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class NavBackIntent extends Intent {
  const NavBackIntent();
}

/// Offered only by the library search, not by general text editors.
class ReturnToLibraryIntent extends Intent {
  const ReturnToLibraryIntent();
}

/// Общий слой ввода: клавиатура и геймпад приводятся к одним и тем же
/// действиям и дальше двигают фокус одинаково.
///
/// Стрелки, Tab, Enter и Escape Flutter обрабатывает сам — здесь добавлены
/// только те привязки, которых в наборе по умолчанию нет, и мост от геймпада.
class InputScope extends StatefulWidget {
  const InputScope({
    super.key,
    required this.child,
    required this.gamepad,
    required this.onSectionChange,
    required this.onPrimaryAction,
    required this.onSearch,
    required this.onBack,
  });

  final Widget child;
  final GamepadService gamepad;
  final void Function(int delta) onSectionChange;
  final VoidCallback onPrimaryAction;
  final VoidCallback onSearch;

  /// Что закрыть по «назад». Возвращает `true`, если что-то закрылось: тогда
  /// фокус остаётся на месте, иначе он сбрасывается, как и раньше.
  final bool Function() onBack;

  @override
  State<InputScope> createState() => _InputScopeState();
}

class _InputScopeState extends State<InputScope> {
  StreamSubscription<NavAction>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.gamepad.actions.listen(_handleAction);
  }

  @override
  void didUpdateWidget(InputScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gamepad != widget.gamepad) {
      _subscription?.cancel();
      _subscription = widget.gamepad.actions.listen(_handleAction);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleAction(NavAction action) {
    if (!mounted) return;
    switch (action) {
      case NavAction.up:
        _move(TraversalDirection.up);
      case NavAction.down:
        _move(TraversalDirection.down);
      case NavAction.left:
        _move(TraversalDirection.left);
      case NavAction.right:
        _move(TraversalDirection.right);
      case NavAction.confirm:
        _activate();
      case NavAction.back:
        _back();
      case NavAction.nextSection:
        widget.onSectionChange(1);
      case NavAction.prevSection:
        widget.onSectionChange(-1);
      case NavAction.primaryAction:
        widget.onPrimaryAction();
      case NavAction.search:
        widget.onSearch();
      case NavAction.scrollUp:
        _scroll(-60);
      case NavAction.scrollDown:
        _scroll(60);
    }
  }

  /// Первое нажатие направления при пустом фокусе должно во что-то попасть,
  /// иначе геймпад выглядит нерабочим.
  void _move(TraversalDirection direction) {
    final scope = FocusScope.of(context);
    final focused = primaryFocus;
    if (direction == TraversalDirection.down && _returnFromSearch()) return;
    if (focused == null || !focused.hasFocus || focused == scope) {
      scope.nextFocus();
      return;
    }
    if (!focused.focusInDirection(direction)) {
      // Упёрлись в край — пробуем обычный порядок обхода.
      if (direction == TraversalDirection.down ||
          direction == TraversalDirection.right) {
        scope.nextFocus();
      } else {
        scope.previousFocus();
      }
    }
  }

  void _activate() {
    if (_returnFromSearch()) return;
    final target = primaryFocus?.context;
    if (target == null) return;
    Actions.maybeInvoke(target, const ActivateIntent());
  }

  void _back() {
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }
    // Из текстового поля выходим раньше, чем закрываем страницу: Escape в
    // поиске должен отпускать поле, а не уводить с открытой игры.
    if (_returnFromSearch()) return;
    final focused = primaryFocus;
    if (focused != null && focused.context?.widget is EditableText) {
      focused.unfocus();
      return;
    }
    if (widget.onBack()) return;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  bool _returnFromSearch() {
    final target = primaryFocus?.context;
    if (target == null) return false;
    final action = Actions.maybeFind<ReturnToLibraryIntent>(target);
    if (action == null) return false;
    Actions.invoke(target, const ReturnToLibraryIntent());
    return true;
  }

  void _scroll(double delta) {
    final target = primaryFocus?.context ?? context;
    final position = Scrollable.maybeOf(target)?.position;
    if (position == null) return;
    position.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.slash): const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.tab, control: true):
            const SectionChangeIntent(1),
        const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        ): const SectionChangeIntent(
          -1,
        ),
        const SingleActivator(LogicalKeyboardKey.bracketRight, meta: true):
            const SectionChangeIntent(1),
        const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
            const SectionChangeIntent(-1),
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            const PrimaryActionIntent(),
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            const PrimaryActionIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const NavBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          // Стрелки идут через тот же код, что и крестовина геймпада:
          // штатный обработчик не умеет стартовать с пустого фокуса, и
          // первое нажатие стрелки в свежем окне не делало ничего.
          // В текстовых полях стрелки перехватываются раньше, до этого места.
          DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
            onInvoke: (intent) {
              _move(intent.direction);
              return null;
            },
          ),
          SectionChangeIntent: CallbackAction<SectionChangeIntent>(
            onInvoke: (intent) {
              widget.onSectionChange(intent.delta);
              return null;
            },
          ),
          PrimaryActionIntent: CallbackAction<PrimaryActionIntent>(
            onInvoke: (_) {
              widget.onPrimaryAction();
              return null;
            },
          ),
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (_) {
              widget.onSearch();
              return null;
            },
          ),
          NavBackIntent: CallbackAction<NavBackIntent>(
            onInvoke: (_) {
              _back();
              return null;
            },
          ),
        },
        // Пока фокуса нет вообще, нажатия клавиш до Shortcuts не доходят:
        // они идут в корневой скоуп над MaterialApp. Эта нода забирает фокус
        // на старте, но пропускается при обходе, чтобы не мешать навигации.
        child: Focus(autofocus: true, skipTraversal: true, child: widget.child),
      ),
    );
  }
}

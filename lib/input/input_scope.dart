import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gamepad_service.dart';
import 'nav_action.dart';

/// Одно намерение на все клавиши: что делать, говорит сам [NavAction].
///
/// Прежде здесь лежало пять классов-намерений и пять `CallbackAction` к
/// ним, и каждый повторял ветку того же `switch`, который уже есть у
/// геймпада. Клавиатура сводилась не к `NavAction`, как обещано в
/// `CLAUDE.md`, а к своему набору, который приходилось держать в голове
/// рядом с ним.
class NavActionIntent extends Intent {
  const NavActionIntent(this.action);

  final NavAction action;
}

/// Сдвинуть значение на шаг — влево или вправо с геймпада.
///
/// Стрелки клавиатуры ползунок понимает сам, а геймпад идёт мимо клавиш —
/// прямо в обход фокуса, и мёртвую зону стика с самого геймпада было не
/// поменять: влево и вправо уводили к соседнему элементу. Теперь обход
/// сначала предлагает направление фокусу, и тот, кто объявил это
/// действие, меняет значение, а фокус остаётся на месте.
class AdjustValueIntent extends Intent {
  const AdjustValueIntent(this.steps);

  /// На сколько шагов: `1` — вправо, `-1` — влево.
  final int steps;
}

/// «/» — поиск, но только вне текстового поля.
///
/// Своим намерением, а не `NavActionIntent`: «/» — ещё и обычный символ.
/// Перехваченная всегда, она не набиралась ни в пароле прокси, ни в самом
/// поиске — «Fate/stay» было не найти. `Ctrl+F` и `⌘F` символов не
/// набирают и уводят в поиск откуда угодно.
class TypedSearchIntent extends Intent {
  const TypedSearchIntent();
}

/// Выключено, пока фокус в поле: выключенное действие `Shortcuts` не
/// обрабатывают, и клавиша доходит до поля как символ.
class _TypedSearchAction extends Action<TypedSearchIntent> {
  _TypedSearchAction(this._search);

  final VoidCallback _search;

  @override
  bool isEnabled(TypedSearchIntent intent) => !focusInTextField();

  @override
  Object? invoke(TypedSearchIntent intent) {
    _search();
    return null;
  }
}

/// Предлагается только поиском по библиотеке, а не текстовыми полями вообще.
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
    final focused = primaryFocus;
    // Обход идёт по той области, где сейчас фокус, а не по той, где висит
    // сам слой ввода. Слой лежит под навигатором и продолжает получать
    // события геймпада, когда поверх открыто окно, — а `FocusScope.of`
    // отдаёт область оболочки. Дойдя до нижней кнопки окна, обход уходил в
    // библиотеку под ним, и вернуться в окно было уже нечем.
    final scope = focused?.nearestScope ?? FocusScope.of(context);
    if (direction == TraversalDirection.down && _returnFromSearch()) return;
    if (_adjust(focused, direction)) return;
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

  /// Влево и вправо сначала — тому, кто умеет менять значение: ползунку.
  bool _adjust(FocusNode? focused, TraversalDirection direction) {
    final horizontal =
        direction == TraversalDirection.left ||
        direction == TraversalDirection.right;
    final target = focused?.context;
    if (!horizontal || target == null) return false;
    if (Actions.maybeFind<AdjustValueIntent>(target) == null) return false;
    Actions.invoke(
      target,
      AdjustValueIntent(direction == TraversalDirection.right ? 1 : -1),
    );
    return true;
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
    if (focusInTextField()) {
      primaryFocus?.unfocus();
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
      shortcuts: _shortcuts,
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
          // Всё остальное — тот же путь, которым идут нажатия геймпада.
          NavActionIntent: CallbackAction<NavActionIntent>(
            onInvoke: (intent) {
              _handleAction(intent.action);
              return null;
            },
          ),
          TypedSearchIntent: _TypedSearchAction(
            () => _handleAction(NavAction.search),
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

/// Клавиши, которых нет в наборе Flutter по умолчанию.
///
/// Таблицей, а не ветвлениями: добавить клавишу — значит дописать строку,
/// а что она делает, видно по имени действия.
const _shortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.slash): TypedSearchIntent(),
  SingleActivator(LogicalKeyboardKey.keyF, meta: true): NavActionIntent(
    NavAction.search,
  ),
  SingleActivator(LogicalKeyboardKey.keyF, control: true): NavActionIntent(
    NavAction.search,
  ),
  SingleActivator(LogicalKeyboardKey.tab, control: true): NavActionIntent(
    NavAction.nextSection,
  ),
  SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
      NavActionIntent(NavAction.prevSection),
  SingleActivator(LogicalKeyboardKey.bracketRight, meta: true): NavActionIntent(
    NavAction.nextSection,
  ),
  SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true): NavActionIntent(
    NavAction.prevSection,
  ),
  SingleActivator(LogicalKeyboardKey.enter, meta: true): NavActionIntent(
    NavAction.primaryAction,
  ),
  SingleActivator(LogicalKeyboardKey.enter, control: true): NavActionIntent(
    NavAction.primaryAction,
  ),
  SingleActivator(LogicalKeyboardKey.escape): NavActionIntent(NavAction.back),
};

/// Фокус — в текстовом поле.
///
/// Контекст узла фокуса — не само поле, а `Focus` внутри его `EditableText`,
/// поэтому поле ищется среди предков: проверка «сам виджет — поле» не
/// срабатывала никогда.
bool focusInTextField() {
  final context = primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}

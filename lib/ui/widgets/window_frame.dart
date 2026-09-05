import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'app_mark.dart';

/// Размеры обрамления, вынесенные из виджета: их сверяет тест.
///
/// Полосы, за которые тянут края окна, лежат поверх всего остального — иначе
/// до них не дотянуться. Значит они могут накрыть и кнопки окна, а кнопка
/// под невидимой полосой — это уже не просто мёртвая точка: нажатие уходит
/// в системный цикл изменения размера, Flutter отпускания мыши не видит, и
/// отложенное нажатие достаётся кнопке под полосой. Верхняя из них шла по
/// всем трём кнопкам сразу, включая «Закрыть».
///
/// Отсюда правило: полоса тонкая (в [edge] точки), уголок берётся уголком, а
/// не квадратом, и панель с кнопками отступает от края ровно на [edge].
class WindowChrome {
  const WindowChrome._();

  /// Толщина полосы у края окна.
  static const edge = 4.0;

  /// Длина уголка вдоль каждой стороны.
  static const corner = 8.0;

  static const barHeight = 42.0;
  static const buttonWidth = 48.0;
  static const buttonCount = 3;

  /// Куда попадают кнопки окна при ширине [width].
  static Rect buttonsRect(double width) => Rect.fromLTWH(
    width - edge - buttonWidth * buttonCount,
    edge,
    buttonWidth * buttonCount,
    barHeight - edge,
  );

  /// Полосы и уголки для окна размера [size]. Уголок — две полосы, сходящиеся
  /// под прямым углом: квадрат восемь на восемь залез бы на кнопку, а полоса
  /// в четыре точки под кнопками уже не проходит.
  static List<({ResizeEdge edge, Rect rect})> resizeZones(Size size) {
    final w = size.width;
    final h = size.height;
    return [
      (
        edge: ResizeEdge.top,
        rect: Rect.fromLTWH(corner, 0, w - corner * 2, WindowChrome.edge),
      ),
      (
        edge: ResizeEdge.bottom,
        rect: Rect.fromLTWH(
          corner,
          h - WindowChrome.edge,
          w - corner * 2,
          WindowChrome.edge,
        ),
      ),
      (
        edge: ResizeEdge.left,
        rect: Rect.fromLTWH(0, corner, WindowChrome.edge, h - corner * 2),
      ),
      (
        edge: ResizeEdge.right,
        rect: Rect.fromLTWH(
          w - WindowChrome.edge,
          corner,
          WindowChrome.edge,
          h - corner * 2,
        ),
      ),
      (
        edge: ResizeEdge.topLeft,
        rect: const Rect.fromLTWH(0, 0, corner, WindowChrome.edge),
      ),
      (
        edge: ResizeEdge.topLeft,
        rect: const Rect.fromLTWH(0, 0, WindowChrome.edge, corner),
      ),
      (
        edge: ResizeEdge.topRight,
        rect: Rect.fromLTWH(w - corner, 0, corner, WindowChrome.edge),
      ),
      (
        edge: ResizeEdge.topRight,
        rect: Rect.fromLTWH(
          w - WindowChrome.edge,
          0,
          WindowChrome.edge,
          corner,
        ),
      ),
      (
        edge: ResizeEdge.bottomLeft,
        rect: Rect.fromLTWH(
          0,
          h - WindowChrome.edge,
          corner,
          WindowChrome.edge,
        ),
      ),
      (
        edge: ResizeEdge.bottomLeft,
        rect: Rect.fromLTWH(0, h - corner, WindowChrome.edge, corner),
      ),
      (
        edge: ResizeEdge.bottomRight,
        rect: Rect.fromLTWH(
          w - corner,
          h - WindowChrome.edge,
          corner,
          WindowChrome.edge,
        ),
      ),
      (
        edge: ResizeEdge.bottomRight,
        rect: Rect.fromLTWH(
          w - WindowChrome.edge,
          h - corner,
          WindowChrome.edge,
          corner,
        ),
      ),
    ];
  }

  /// Курсор говорит, что край можно потянуть: полосу в четыре точки иначе
  /// не заметить вовсе.
  static MouseCursor cursorFor(ResizeEdge edge) => switch (edge) {
    ResizeEdge.top || ResizeEdge.bottom => SystemMouseCursors.resizeUpDown,
    ResizeEdge.left || ResizeEdge.right => SystemMouseCursors.resizeLeftRight,
    ResizeEdge.topLeft ||
    ResizeEdge.bottomRight => SystemMouseCursors.resizeUpLeftDownRight,
    ResizeEdge.topRight ||
    ResizeEdge.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
  };
}

/// Обрамляет весь Navigator, включая диалоги: системной панели больше нет,
/// поэтому управление окном должно оставаться доступным на любой странице.
class AppWindowFrame extends StatefulWidget {
  const AppWindowFrame({super.key, required this.child});

  final Widget child;

  @override
  State<AppWindowFrame> createState() => _AppWindowFrameState();
}

class _AppWindowFrameState extends State<AppWindowFrame> with WindowListener {
  bool _maximized = false;
  bool _fullScreen = false;
  bool _focused = true;
  int _revision = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_readState());
  }

  Future<void> _readState() async {
    final revision = _revision;
    try {
      final values = await Future.wait([
        windowManager.isMaximized(),
        windowManager.isFullScreen(),
        windowManager.isFocused(),
      ]);
      if (!mounted || revision != _revision) return;
      setState(() {
        _maximized = values[0];
        _fullScreen = values[1];
        _focused = values[2];
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
      if (mounted && _error != null) setState(() => _error = null);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _toggleSize() => _perform(() async {
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
    } else if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _readState();
  });

  void _changed(VoidCallback update) {
    _revision++;
    if (mounted) setState(update);
  }

  @override
  void onWindowMaximize() => _changed(() => _maximized = true);
  @override
  void onWindowUnmaximize() => _changed(() => _maximized = false);
  @override
  void onWindowEnterFullScreen() => _changed(() => _fullScreen = true);
  @override
  void onWindowLeaveFullScreen() => _changed(() => _fullScreen = false);
  @override
  void onWindowFocus() => _changed(() => _focused = true);
  @override
  void onWindowBlur() => _changed(() => _focused = false);

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final expanded = _maximized || _fullScreen;
    // На Windows форму задаёт DWM. Прозрачный слой помешал бы его
    // скруглению и мог бы оставить чёрные углы на Windows 10.
    final radius = !expanded && !Platform.isWindows ? 12.0 : 0.0;
    final colors = context.colors;
    final foreground = _focused ? colors.textPrimary : colors.textSecondary;

    // Развёрнутому окну край тянуть незачем, а macOS меняет размер сама:
    // startResizing там не поддерживается.
    final resizable = !expanded && !Platform.isMacOS;

    return ClipRRect(
      key: const ValueKey('window-clip'),
      borderRadius: BorderRadius.circular(radius),
      // Панель находится выше Navigator и нуждается в своём Overlay
      // для подсказок. Он также обрезается по внешней форме окна.
      child: Overlay.wrap(
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  Material(
                    color: colors.surface,
                    child: SizedBox(
                      height: WindowChrome.barHeight,
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              key: const ValueKey('window-drag-region'),
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (_) =>
                                  _perform(windowManager.startDragging),
                              onDoubleTap: _toggleSize,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    const AppMark(size: 24),
                                    const SizedBox(width: 9),
                                    Text(
                                      'Evaporate',
                                      style: TextStyle(
                                        color: foreground,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_error != null)
                                      Tooltip(
                                        message: _error!,
                                        child: Icon(
                                          Icons.error_outline,
                                          color: colors.danger,
                                          size: 16,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Отступ ровно на толщину полосы у края: под
                          // полосой кнопка не просто не нажимается, а
                          // получает нажатие потом, когда системный цикл
                          // изменения размера уже закончился.
                          Padding(
                            padding: EdgeInsets.only(
                              top: resizable ? WindowChrome.edge : 0,
                              right: resizable ? WindowChrome.edge : 0,
                            ),
                            child: Row(
                              children: [
                                _WindowButton(
                                  label: l.minimizeWindow,
                                  icon: Icons.remove,
                                  onPressed: () =>
                                      _perform(windowManager.minimize),
                                ),
                                _WindowButton(
                                  label: expanded
                                      ? l.restoreWindow
                                      : l.maximizeWindow,
                                  icon: expanded
                                      ? Icons.filter_none
                                      : Icons.crop_square,
                                  onPressed: _toggleSize,
                                ),
                                _WindowButton(
                                  label: l.closeWindow,
                                  icon: Icons.close,
                                  destructive: true,
                                  onPressed: () =>
                                      _perform(windowManager.close),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: colors.outline),
                  Expanded(child: widget.child),
                ],
              ),
              // Невидимые узкие полосы возвращают изменение размера после
              // удаления рамки ОС. Их размеры и правило «не залезать на
              // кнопки» живут в WindowChrome, где их и проверяет тест.
              if (resizable)
                for (final zone in WindowChrome.resizeZones(
                  constraints.biggest,
                ))
                  _resize(zone.edge, zone.rect),
            ],
          ),
        ),
      ),
    );
  }

  /// Полоса у края окна.
  ///
  /// Слушаем нажатие, а не жест перетаскивания, и вот почему: система по
  /// нажатию забирает мышь себе и ведёт изменение размера сама, а Flutter
  /// отпускания уже не видит. Жест так и остался бы незавершённым, да и
  /// начинался бы он только после того, как палец уйдёт от точки нажатия на
  /// два десятка точек, — то есть окно дёргалось бы скачком.
  Widget _resize(ResizeEdge edge, Rect rect) => Positioned.fromRect(
    rect: rect,
    child: MouseRegion(
      cursor: WindowChrome.cursorFor(edge),
      child: Listener(
        key: ValueKey('window-resize-${edge.name}'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (event.buttons != kPrimaryButton) return;
          unawaited(_perform(() => windowManager.startResizing(edge)));
        },
      ),
    ),
  );
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: SizedBox(
      width: 48,
      height: 42,
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                destructive &&
                    (states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.pressed))
                ? AppColors.windowCloseForeground
                : context.colors.textSecondary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                destructive &&
                    (states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.pressed))
                ? AppColors.windowCloseBackground
                : AppColors.transparent,
          ),
        ),
        child: Icon(icon, size: 17, semanticLabel: label),
      ),
    ),
  );
}

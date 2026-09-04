import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'app_mark.dart';

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

    return ClipRRect(
      key: const ValueKey('window-clip'),
      borderRadius: BorderRadius.circular(radius),
      // Панель находится выше Navigator и нуждается в своём Overlay
      // для подсказок. Он также обрезается по внешней форме окна.
      child: Overlay.wrap(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                Material(
                  color: colors.surface,
                  child: SizedBox(
                    height: 42,
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
                        _WindowButton(
                          label: l.minimizeWindow,
                          icon: Icons.remove,
                          onPressed: () => _perform(windowManager.minimize),
                        ),
                        _WindowButton(
                          label: expanded ? l.restoreWindow : l.maximizeWindow,
                          icon: expanded
                              ? Icons.filter_none
                              : Icons.crop_square,
                          onPressed: _toggleSize,
                        ),
                        _WindowButton(
                          label: l.closeWindow,
                          icon: Icons.close,
                          destructive: true,
                          onPressed: () => _perform(windowManager.close),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, thickness: 1, color: colors.outline),
                Expanded(child: widget.child),
              ],
            ),
            // Невидимые узкие зоны возвращают изменение размера после
            // удаления рамки ОС. macOS сохраняет нативный resize NSWindow:
            // window_manager.startResizing там не поддерживается.
            // В maximized/fullscreen зоны не перехватывают UI.
            if (!expanded && !Platform.isMacOS) ...[
              _resize(
                ResizeEdge.top,
                top: 0,
                left: 8,
                right: 8,
                height: 4,
                cursor: SystemMouseCursors.resizeUpDown,
              ),
              _resize(
                ResizeEdge.bottom,
                bottom: 0,
                left: 8,
                right: 8,
                height: 4,
                cursor: SystemMouseCursors.resizeUpDown,
              ),
              _resize(
                ResizeEdge.left,
                left: 0,
                top: 8,
                bottom: 8,
                width: 4,
                cursor: SystemMouseCursors.resizeLeftRight,
              ),
              _resize(
                ResizeEdge.right,
                right: 0,
                top: 8,
                bottom: 8,
                width: 4,
                cursor: SystemMouseCursors.resizeLeftRight,
              ),
              _resize(
                ResizeEdge.topLeft,
                top: 0,
                left: 0,
                width: 8,
                height: 8,
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
              ),
              _resize(
                ResizeEdge.topRight,
                top: 0,
                right: 0,
                width: 8,
                height: 8,
                cursor: SystemMouseCursors.resizeUpRightDownLeft,
              ),
              _resize(
                ResizeEdge.bottomLeft,
                bottom: 0,
                left: 0,
                width: 8,
                height: 8,
                cursor: SystemMouseCursors.resizeUpRightDownLeft,
              ),
              _resize(
                ResizeEdge.bottomRight,
                bottom: 0,
                right: 0,
                width: 8,
                height: 8,
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resize(
    ResizeEdge edge, {
    double? top,
    double? bottom,
    double? left,
    double? right,
    double? width,
    double? height,
    required MouseCursor cursor,
  }) => Positioned(
    top: top,
    bottom: bottom,
    left: left,
    right: right,
    width: width,
    height: height,
    child: MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        key: ValueKey('window-resize-${edge.name}'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _perform(() => windowManager.startResizing(edge)),
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

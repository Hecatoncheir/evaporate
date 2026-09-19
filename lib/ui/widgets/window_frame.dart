import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../feedback/snack.dart';
import 'window_action.dart';
import 'window_chrome.dart';
import 'window_control.dart';
import 'window_resize_zone.dart';

/// Обрамляет весь Navigator, включая диалоги: рамки ОС нет, и скруглённые
/// углы с полосами для изменения размера рисуем мы сами.
///
/// Своей полосы заголовка у рамки нет — перетаскивание и клавиши окна живут
/// в верхней рейке приложения, чтобы знак и название не стояли на экране
/// дважды. Цена решения: пока открыт модальный диалог, они под его
/// барьером.
class AppWindowFrame extends StatefulWidget {
  const AppWindowFrame({super.key, required this.child});

  final Widget child;

  @override
  State<AppWindowFrame> createState() => _AppWindowFrameState();
}

class _AppWindowFrameState extends State<AppWindowFrame> with WindowListener {
  bool _maximized = false;
  bool _fullScreen = false;
  int _revision = 0;

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
      ]);
      if (!mounted || revision != _revision) return;
      setState(() {
        _maximized = values[0];
        _fullScreen = values[1];
      });
    } on Object catch (error) {
      if (mounted) showError(context, error);
    }
  }

  /// Разворачивает окно или возвращает прежний размер.
  ///
  /// Полноэкранный режим — тоже «развёрнуто», и выходим сначала из него:
  /// иначе клавиша из полного экрана делала бы окно ещё и развёрнутым.
  ///
  /// В конце состояние перечитывается, а не ждётся событием: на части
  /// систем событие приходит с задержкой, и клавиша до него показывала бы
  /// несбывшееся.
  Future<void> _toggleSize() => runWindowAction(context, () async {
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
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expanded = _maximized || _fullScreen;
    // Углы режем сами, на всех системах одинаково: фон окна прозрачный,
    // поэтому за вырезанным углом виден рабочий стол, а не подложка окна.
    // Развёрнутому окну углы не нужны: там их резать не от чего.
    final radius = expanded ? 0.0 : WindowChrome.cornerRadius;

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
              WindowControl(
                expanded: expanded,
                toggleSize: _toggleSize,
                child: widget.child,
              ),
              // Невидимые узкие полосы возвращают изменение размера после
              // удаления рамки ОС. Их размеры и правило «не доставать до
              // рейки» живут в WindowChrome, где их и проверяет тест.
              if (resizable)
                for (final zone in WindowChrome.resizeZones(
                  constraints.biggest,
                ))
                  WindowResizeZone(edge: zone.edge, rect: zone.rect),
            ],
          ),
        ),
      ),
    );
  }
}

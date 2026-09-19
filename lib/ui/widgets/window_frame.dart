import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../feedback/snack.dart';

/// Размеры обрамления, вынесенные из виджета: их сверяет тест.
///
/// Полосы, за которые тянут края окна, лежат поверх всего остального — иначе
/// до них не дотянуться. Значит они могут накрыть и то, что под ними, а
/// орган управления под невидимой полосой — это уже не просто мёртвая точка:
/// нажатие уходит в системный цикл изменения размера, Flutter отпускания
/// мыши не видит, и отложенное нажатие достаётся тому, что лежит под
/// полосой.
///
/// Отсюда правило: полоса тонкая (в [edge] точки), уголок берётся уголком, а
/// не квадратом, и верхняя рейка приложения отступает от края окна дальше,
/// чем [edge]. За отступ отвечает оболочка, и сходятся эти два числа в
/// тесте.
class WindowChrome {
  const WindowChrome._();

  /// Толщина полосы у края окна.
  static const edge = 4.0;

  /// Скругление углов окна — одно на все системы: рамку рисуем мы, и
  /// выглядеть она должна одинаково.
  ///
  /// Заметно круглее системного, но не настолько, чтобы спорить с тенью:
  /// тень на Windows рисует DWM по своей форме, со скруглением примерно в
  /// восемь точек, и задать ей радиус нечем. Чем глубже рез, тем заметнее
  /// она выглядывает из-за угла.
  static const cornerRadius = 16.0;

  /// Длина уголка вдоль каждой стороны.
  static const corner = 8.0;

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

/// Что верхней рейке нужно знать об окне: развёрнуто ли оно и как это
/// изменить.
///
/// Раздаётся сверху, от рамки, а не спрашивается у системы второй раз: два
/// независимых слушателя одного события — два места, где состояние может
/// разойтись, и разойтись им ничего не мешает.
///
/// Отсутствие этого виджета означает, что своей рамки нет вовсе, — тогда
/// рейке и нечего показывать: окном распоряжается система.
class WindowControl extends InheritedWidget {
  const WindowControl({
    super.key,
    required this.expanded,
    required this.toggleSize,
    required super.child,
  });

  /// Развёрнуто на весь экран или растянуто во весь рабочий стол.
  final bool expanded;

  final Future<void> Function() toggleSize;

  static WindowControl? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WindowControl>();

  @override
  bool updateShouldNotify(WindowControl oldWidget) =>
      oldWidget.expanded != expanded;
}

/// Выполняет действие над окном и говорит, если система откажет.
///
/// Гасить отказ нельзя: не свернувшееся по нажатию окно выглядит зависшим,
/// а объяснить, что случилось, кроме нас некому.
Future<void> runWindowAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on Object catch (error) {
    if (context.mounted) showError(context, error);
  }
}

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
          unawaited(
            runWindowAction(context, () => windowManager.startResizing(edge)),
          );
        },
      ),
    ),
  );
}

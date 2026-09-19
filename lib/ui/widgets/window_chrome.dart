import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

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

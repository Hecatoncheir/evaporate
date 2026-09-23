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

  /// Полосы и уголки для окна размера [size].
  static List<({ResizeEdge edge, Rect rect})> resizeZones(Size size) => [
    ..._sides(size),
    ..._corners(size),
  ];

  /// Полосы вдоль сторон — между уголками, а не во всю длину: иначе они
  /// накрыли бы уголок, и тянуть за угол получалось бы только мимо него.
  static List<({ResizeEdge edge, Rect rect})> _sides(Size size) {
    final along = size.width - corner * 2;
    final down = size.height - corner * 2;
    return [
      (
        edge: ResizeEdge.top,
        rect: Rect.fromLTWH(corner, 0, along, WindowChrome.edge),
      ),
      (
        edge: ResizeEdge.bottom,
        rect: Rect.fromLTWH(
          corner,
          size.height - WindowChrome.edge,
          along,
          WindowChrome.edge,
        ),
      ),
      (
        edge: ResizeEdge.left,
        rect: Rect.fromLTWH(0, corner, WindowChrome.edge, down),
      ),
      (
        edge: ResizeEdge.right,
        rect: Rect.fromLTWH(
          size.width - WindowChrome.edge,
          corner,
          WindowChrome.edge,
          down,
        ),
      ),
    ];
  }

  /// Уголок — две полосы, сходящиеся под прямым углом: квадрат восемь на
  /// восемь залез бы на кнопку, а полоса в четыре точки под кнопками уже
  /// не проходит.
  ///
  /// Все четыре устроены одинаково с точностью до того, у какого края
  /// стоят, — поэтому таблицей, а не двенадцатью выписанными
  /// прямоугольниками, в которых ошибка на одно число не видна глазом.
  static Iterable<({ResizeEdge edge, Rect rect})> _corners(Size size) sync* {
    const thickness = WindowChrome.edge;
    const corners = [
      (edge: ResizeEdge.topLeft, atLeft: true, atTop: true),
      (edge: ResizeEdge.topRight, atLeft: false, atTop: true),
      (edge: ResizeEdge.bottomLeft, atLeft: true, atTop: false),
      (edge: ResizeEdge.bottomRight, atLeft: false, atTop: false),
    ];

    for (final at in corners) {
      // Вдоль верхней или нижней стороны — и вдоль левой или правой.
      yield (
        edge: at.edge,
        rect: Rect.fromLTWH(
          at.atLeft ? 0 : size.width - corner,
          at.atTop ? 0 : size.height - thickness,
          corner,
          thickness,
        ),
      );
      yield (
        edge: at.edge,
        rect: Rect.fromLTWH(
          at.atLeft ? 0 : size.width - thickness,
          at.atTop ? 0 : size.height - corner,
          thickness,
          corner,
        ),
      );
    }
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

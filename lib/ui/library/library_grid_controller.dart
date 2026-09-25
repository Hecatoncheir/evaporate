import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// То, что сетка обложек помнит между перестроениями: ключи плиток, их узлы
/// фокуса, прокрутка, наведение и последний замер раскладки.
///
/// Живёт у страницы, а не у сетки: сетка пересобирается на каждый поиск и
/// смену полки, а ключи и фокусы должны пережить это — иначе фокус после
/// «назад» терял бы плитку, с которой ушли. Страница же по замеру мотает
/// себя, догоняя ещё не построенную плитку.
class LibraryGridController extends ChangeNotifier {
  /// Прокрутка всей страницы, а не одной сетки: подпись, крупный кадр и
  /// полки уходят вверх вместе с обложками.
  final scroll = ScrollController();

  /// Ключ сливера сетки: по нему видно, где сетка начинается на странице.
  final gridKey = GlobalKey(debugLabel: 'library-grid');

  final _tileKeys = <String, GlobalKey>{};
  final _focusNodes = <String, FocusNode>{};

  /// Игра под курсором; `null` — курсора в сетке нет.
  String? get hoveredId => _hoveredId;
  String? _hoveredId;

  /// Сколько столбцов вышло и какой у ряда шаг — из последнего замера.
  int columns = 1;
  double rowStride = 320;

  GlobalKey tileKey(String gameId) =>
      _tileKeys.putIfAbsent(gameId, () => GlobalKey(debugLabel: gameId));

  FocusNode focusNode(String gameId) => _focusNodes.putIfAbsent(
    gameId,
    () => FocusNode(debugLabel: 'game:$gameId'),
  );

  /// Плитка, под которой стоит рамка выбранного: под курсором, а если
  /// курсора нет — под выбранной игрой.
  GlobalKey? targetKey(String? selectedId) =>
      _tileKeys[_hoveredId ?? selectedId];

  /// Построена ли плитка прямо сейчас: у ленивой сетки её может и не быть.
  bool isBuilt(String gameId) => _focusNodes[gameId]?.context != null;

  void requestFocus(String gameId) => _focusNodes[gameId]?.requestFocus();

  void hover(String gameId, {required bool hovered}) {
    final next = hovered ? gameId : (_hoveredId == gameId ? null : _hoveredId);
    if (next == _hoveredId) return;
    _hoveredId = next;
    notifyListeners();
  }

  /// Освобождает то, что осталось от игр, которых в библиотеке больше нет.
  void forgetGone(Set<String> aliveIds) {
    _tileKeys.removeWhere((id, _) => !aliveIds.contains(id));
    for (final id in _focusNodes.keys.toList()) {
      if (!aliveIds.contains(id)) _focusNodes.remove(id)!.dispose();
    }
    if (_hoveredId != null && !aliveIds.contains(_hoveredId)) {
      _hoveredId = null;
    }
  }

  /// Мотает страницу так, чтобы ряд плитки встал к верхнему краю видимого.
  ///
  /// Ряд отмеряется от начала сетки, а не страницы: над сеткой подпись,
  /// крупный кадр и полки, и счёт от нуля промахивался на их высоту. Где
  /// сетка начинается и где кончается видимое под полосой каркаса, знает
  /// окно прокрутки — его и спрашиваем, как спрашивает фокус.
  void scrollTo(int index) {
    final grid = gridKey.currentContext?.findRenderObject();
    if (!scroll.hasClients || grid is! RenderSliver || grid.geometry == null) {
      return;
    }
    final row = Rect.fromLTWH(
      0,
      index ~/ columns * rowStride,
      grid.constraints.crossAxisExtent,
      rowStride,
    );
    final target = RenderAbstractViewport.of(grid)
        .getOffsetToReveal(grid, 0, rect: row)
        .offset;
    scroll.jumpTo(target.clamp(0.0, scroll.position.maxScrollExtent));
  }

  @override
  void dispose() {
    scroll.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }
}

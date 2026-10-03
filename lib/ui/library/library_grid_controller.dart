import 'package:flutter/material.dart';

/// Ресурсы полок, принадлежащие странице: ключи обложек, узлы фокуса,
/// общая прокрутка и наведение. Переживают поиск и возврат со страницы игры.
class LibraryGridController extends ChangeNotifier {
  /// Прокрутка всей страницы, а не одной сетки: подпись, крупный кадр и
  /// полки уходят вверх вместе с обложками.
  final scroll = ScrollController();

  final _tileKeys = <String, GlobalKey>{};
  final _focusNodes = <String, FocusNode>{};

  /// Игра под курсором; `null` — курсора в сетке нет.
  String? get hoveredId => _hoveredId;
  String? _hoveredId;

  /// Порядок найденных игр для перехода к карточке по номеру.
  List<String> shelfIds = const [];

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

  /// Построена ли карточка прямо сейчас: фильтр мог убрать её из полки.
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

  /// Доводит карточку до видимого по горизонтали и под полосами каркаса.
  void scrollTo(int index) {
    if (index < 0 || index >= shelfIds.length) return;
    _focusNodes[shelfIds[index]]?.context?.findRenderObject()?.showOnScreen();
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

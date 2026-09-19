import 'package:flutter/material.dart';

/// То, что сетка обложек помнит между перестроениями: ключи плиток, их узлы
/// фокуса, прокрутка, наведение и последний замер раскладки.
///
/// Живёт у страницы, а не у сетки: сетка пересобирается на каждый поиск и
/// смену полки, а ключи и фокусы должны пережить это — иначе фокус после
/// «назад» терял бы плитку, с которой ушли. Страница же по замеру мотает
/// список, догоняя ещё не построенную плитку.
class LibraryGridController extends ChangeNotifier {
  final scroll = ScrollController();
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

  /// Мотает список к плитке по её месту в сетке.
  void scrollTo(int index) {
    if (!scroll.hasClients) return;
    scroll.jumpTo(
      (index ~/ columns * rowStride).clamp(
        0.0,
        scroll.position.maxScrollExtent,
      ),
    );
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

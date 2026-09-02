/// Единый словарь действий навигации.
///
/// И клавиатура, и геймпад сводятся к этому набору: дальше по приложению
/// идёт уже [NavAction], а не «стрелка вверх» или «кнопка 3».
enum NavAction {
  up,
  down,
  left,
  right,

  /// Активировать элемент под фокусом (A / Enter).
  confirm,

  /// Назад: закрыть диалог, снять фокус с поля (B / Escape).
  back,

  /// Следующий/предыдущий раздел (RB/LB, Ctrl+Tab).
  nextSection,
  prevSection,

  /// Главное действие карточки игры: играть или качать (X).
  primaryAction,

  /// Перейти в поиск (Y, «/»).
  search,

  /// Прокрутка содержимого правым стиком.
  scrollUp,
  scrollDown,
}

extension NavActionInfo on NavAction {
  bool get isDirectional =>
      this == NavAction.up ||
      this == NavAction.down ||
      this == NavAction.left ||
      this == NavAction.right;

  bool get isScroll =>
      this == NavAction.scrollUp || this == NavAction.scrollDown;

  /// Действия, которые имеет смысл повторять при удержании.
  bool get repeats => isDirectional || isScroll;

  /// Для журналов и отладки. Пользователю действия показывают словами через
  /// `navActionLabel` в слое интерфейса: здесь языка взять неоткуда.
  String get label => switch (this) {
    NavAction.up => 'Вверх',
    NavAction.down => 'Вниз',
    NavAction.left => 'Влево',
    NavAction.right => 'Вправо',
    NavAction.confirm => 'Выбрать',
    NavAction.back => 'Назад',
    NavAction.nextSection => 'Следующий раздел',
    NavAction.prevSection => 'Предыдущий раздел',
    NavAction.primaryAction => 'Играть / Скачать',
    NavAction.search => 'Поиск',
    NavAction.scrollUp => 'Прокрутка вверх',
    NavAction.scrollDown => 'Прокрутка вниз',
  };
}

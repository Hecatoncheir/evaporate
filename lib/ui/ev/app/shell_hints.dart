import '../../../input/gamepad_binding.dart';
import '../../../input/nav_action.dart';
import '../../../l10n/app_localizations.dart';
import '../../labels.dart';

/// Подсказки нижней строки: клавиша и что она делает.
///
/// С подключённым геймпадом — его кнопки из раскладки в настройках, иначе
/// клавиши. Раскладку человек может поменять, поэтому кнопки берутся из
/// неё, а не пишутся здесь: подсказка «A — выбрать» при переставленных
/// кнопках врала бы.
List<(String, String)> shellHints(
  L l,
  GamepadBinding binding, {
  required bool gamepad,
}) => gamepad ? _gamepadHints(l, binding) : _keyboardHints(l);

List<(String, String)> _keyboardHints(L l) => [
  ('↑↓←→', l.hintNavigate),
  ('Enter', l.hintSelect),
  ('Esc', l.hintBack),
  ('Ctrl+Tab', l.hintSections),
  ('/', l.hintSearch),
];

/// Что показываем с геймпада и в каком порядке. Направления идут с
/// крестовины и левого стика — одной подсказкой впереди.
const _shownActions = [
  NavAction.confirm,
  NavAction.back,
  NavAction.primaryAction,
  NavAction.search,
  NavAction.nextSection,
];

List<(String, String)> _gamepadHints(L l, GamepadBinding binding) => [
  ('D-pad', l.hintNavigate),
  for (final action in _shownActions)
    if (binding.buttonsFor(action) case [final button, ...])
      (button.label, _shortLabel(l, action)),
];

String _shortLabel(L l, NavAction action) => switch (action) {
  NavAction.confirm => l.hintSelect,
  NavAction.back => l.hintBack,
  NavAction.primaryAction => l.hintPlay,
  NavAction.search => l.hintSearch,
  NavAction.nextSection => l.hintSections,
  _ => navActionLabel(l, action),
};

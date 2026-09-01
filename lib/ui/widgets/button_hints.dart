import 'package:flutter/material.dart';

import '../../input/gamepad_binding.dart';
import '../../input/nav_action.dart';
import '../theme.dart';

/// Подсказки управления в нижней строке — как на консольных экранах.
///
/// Когда геймпад подключён, показываются его кнопки; иначе — клавиши.
class ButtonHints extends StatelessWidget {
  const ButtonHints({
    super.key,
    required this.binding,
    required this.gamepadConnected,
  });

  final GamepadBinding binding;
  final bool gamepadConnected;

  static const _keyboardHints = <(String, NavAction)>[
    ('↑↓←→', NavAction.up),
    ('Enter', NavAction.confirm),
    ('Esc', NavAction.back),
    ('Ctrl+Tab', NavAction.nextSection),
    ('/', NavAction.search),
  ];

  static const _shownActions = <NavAction>[
    NavAction.confirm,
    NavAction.back,
    NavAction.primaryAction,
    NavAction.search,
    NavAction.nextSection,
  ];

  @override
  Widget build(BuildContext context) {
    final hints = gamepadConnected ? _gamepadHints() : _keyboardLabels();
    if (hints.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final hint in hints) ...[
          _HintChip(glyph: hint.$1, label: hint.$2),
          const SizedBox(width: 10),
        ],
      ],
    );
  }

  List<(String, String)> _gamepadHints() {
    final result = <(String, String)>[];
    for (final action in _shownActions) {
      final buttons = binding.buttonsFor(action);
      if (buttons.isEmpty) continue;
      result.add((buttons.first.label, _shortLabel(action)));
    }
    // Направления идут с D-pad и левого стика — показываем одной подсказкой.
    result.insert(0, ('D-pad', 'Навигация'));
    return result;
  }

  List<(String, String)> _keyboardLabels() => [
    for (final (glyph, action) in _keyboardHints)
      (glyph, action == NavAction.up ? 'Навигация' : _shortLabel(action)),
  ];

  static String _shortLabel(NavAction action) => switch (action) {
    NavAction.confirm => 'Выбрать',
    NavAction.back => 'Назад',
    NavAction.primaryAction => 'Играть',
    NavAction.search => 'Поиск',
    NavAction.nextSection => 'Разделы',
    _ => action.label,
  };
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.glyph, required this.label});

  final String glyph;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: EvaporateTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: EvaporateTheme.outline),
          ),
          child: Text(
            glyph,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: EvaporateTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: EvaporateTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

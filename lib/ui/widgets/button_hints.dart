import 'package:flutter/material.dart';

import '../../input/gamepad_binding.dart';
import '../../input/nav_action.dart';
import '../theme.dart';
import '../../l10n/app_localizations.dart';

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
    final l = L.of(context);
    final hints = gamepadConnected ? _gamepadHints(l) : _keyboardLabels(l);
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

  List<(String, String)> _gamepadHints(L l) {
    final result = <(String, String)>[];
    for (final action in _shownActions) {
      final buttons = binding.buttonsFor(action);
      if (buttons.isEmpty) continue;
      result.add((buttons.first.label, _shortLabel(l, action)));
    }
    // Направления идут с D-pad и левого стика — показываем одной подсказкой.
    result.insert(0, ('D-pad', l.hintNavigate));
    return result;
  }

  List<(String, String)> _keyboardLabels(L l) => [
    for (final (glyph, action) in _keyboardHints)
      (glyph, action == NavAction.up ? l.hintNavigate : _shortLabel(l, action)),
  ];

  static String _shortLabel(L l, NavAction action) => switch (action) {
    NavAction.confirm => l.hintSelect,
    NavAction.back => l.hintBack,
    NavAction.primaryAction => l.hintPlay,
    NavAction.search => l.hintSearch,
    NavAction.nextSection => l.hintSections,
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
            color: context.colors.surfaceHigh,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: context.colors.outline),
          ),
          child: Text(
            glyph,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

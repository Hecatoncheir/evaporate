import 'package:flutter/material.dart';

import '../../theme.dart';

/// Последняя ошибка игры под рядом действий: запуск не удался, загрузка
/// сорвалась. Текст — как его вернул источник, цвет — цвет ошибки.
class GameErrorNote extends StatelessWidget {
  const GameErrorNote({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final danger = context.colors.danger;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 16, color: danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: context.text.warning.copyWith(color: danger),
          ),
        ),
      ],
    );
  }
}

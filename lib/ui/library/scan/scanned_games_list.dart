import 'package:flutter/material.dart';

import '../../../services/launch/library_scanner.dart';
import '../../theme.dart';

/// Найденные игры с галочками: что из этого заводить.
///
/// Высота ограничена: список бывает длинным, а окно не должно вырастать
/// во весь экран и уносить клавиши за его край.
class ScannedGamesList extends StatelessWidget {
  const ScannedGamesList({
    super.key,
    required this.games,
    required this.isSelected,
    required this.onToggle,
  });

  final List<ScannedGame> games;

  /// Отмечена ли игра сейчас.
  final bool Function(ScannedGame game) isSelected;

  /// Сняли или поставили галочку.
  final void Function(ScannedGame game, {required bool selected}) onToggle;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          return CheckboxListTile(
            value: isSelected(game),
            onChanged: (checked) => onToggle(game, selected: checked ?? false),
            contentPadding: EdgeInsets.zero,
            title: Text(game.title, style: context.text.body),
            subtitle: Text(
              game.executablePath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.pathSmall,
            ),
          );
        },
      ),
    );
  }
}

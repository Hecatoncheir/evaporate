import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../theme.dart';
import '../../widgets/launcher_action_button.dart';

/// Игра установлена: «Играть», а если исполняемый файл не выбран —
/// пояснение рядом с погашенной клавишей.
///
/// В ряду действий стоит гибким: пояснение переносится, а не выталкивает
/// клавиши Steam за край. Растянутым оно отобрало бы у них половину места
/// под пустой текст.
class PlayActions extends StatelessWidget {
  const PlayActions({
    super.key,
    required this.game,
    required this.label,
    required this.onPressed,
  });

  final Game game;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LauncherActionButton(
          onPressed: onPressed,
          icon: Icons.play_arrow_rounded,
          label: label,
          tone: LauncherTone.launch,
        ),
        if (!game.canLaunch) ...[
          const SizedBox(width: EvaporateSpacing.cluster),
          Flexible(
            child: Text(
              L.of(context).pickExecutableNote,
              style: context.text.note,
            ),
          ),
        ],
      ],
    );
  }
}

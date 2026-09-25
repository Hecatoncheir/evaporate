import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../theme.dart';
import '../../widgets/launcher_action_button.dart';
import '../primary_action.dart';

/// Главная клавиша и переход на страницу игры.
class FeaturedActions extends StatelessWidget {
  const FeaturedActions({
    super.key,
    required this.game,
    required this.onOpen,
    required this.onPrimary,
  });

  final Game game;
  final VoidCallback onOpen;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    // Что делает клавиша, решает общий `primary_action.dart`: то же решение
    // принимают кнопка X на геймпаде и карточка на странице игры. Здесь
    // прежде стоял свой `switch`, и значок в нём был один на все состояния
    // — «Пауза» подписывала клавишу с треугольником «играть».
    final action = primaryActionFor(game);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LauncherActionButton(
          onPressed: canDoPrimaryAction(game) ? onPrimary : null,
          icon: primaryActionIcon(action),
          label: primaryActionLabel(L.of(context), action),
          tone: primaryActionTone(action),
        ),
        const SizedBox(width: EvaporateSpacing.cluster),
        OutlinedButton(
          onPressed: onOpen,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.coverText,
            side: BorderSide(
              color: AppColors.coverText.withValues(alpha: 0.34),
            ),
            minimumSize: const Size(
              EvaporateLayout.controlMinWidth,
              EvaporateLayout.controlHeight,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
            ),
          ),
          child: Text(L.of(context).openGame),
        ),
      ],
    );
  }
}

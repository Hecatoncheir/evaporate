import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/glass_surface.dart';

/// Возврат со страницы игры в библиотеку.
///
/// Подложка обнимает клавишу, а не тянется во всю ширину: за возврат
/// отвечает одно слово в углу, а полоса на весь экран выглядела заголовком
/// раздела и обещала больше, чем несёт.
class BackToLibraryButton extends StatelessWidget {
  const BackToLibraryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GlassSurface(
        radius: EvaporateTheme.radiusSelection,
        shadow: false,
        padding: const EdgeInsets.symmetric(
          horizontal: EvaporateSpacing.tight,
          vertical: EvaporateSpacing.line,
        ),
        child: TextButton.icon(
          onPressed: () =>
              context.read<NavigationBloc>().add(const GameOpened(null)),
          style: TextButton.styleFrom(
            // Тем же радиусом, что подложка: иначе фон, встающий под
            // клавишей при наведении и выборе, рисует внутри мягкого угла
            // свой острый.
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                EvaporateTheme.radiusSelection,
              ),
            ),
          ),
          icon: const Icon(Icons.arrow_back, size: EvaporateIconSize.panel),
          label: Text(L.of(context).backToLibrary),
        ),
      ),
    );
  }
}

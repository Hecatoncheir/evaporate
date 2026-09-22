import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/section_card.dart';
import 'about_body.dart';

/// Версия приложения и проверка обновлений.
///
/// Блок обновлений берётся из приложения, а не заводится здесь: он живёт
/// всё время работы (`AppServices`), и найденное стартовой проверкой видно
/// в карточке сразу. Прежде карточка заводила свой блок, была пуста до
/// нажатия, а найденное на старте уходило только в уведомление — и при
/// выключенных уведомлениях терялось целиком.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context) => SectionCard(
    title: L.of(context).about,
    icon: Icons.info_outline,
    child: const AboutBody(),
  );
}

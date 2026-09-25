import 'package:flutter/material.dart';

import '../theme.dart';

/// Заголовок карточки раздела: значок, имя и то, что справа, — с воздухом
/// до содержимого.
///
/// Своим виджетом, потому что он нужен двоим: карточке-коробке
/// (`SectionCard`) и хронологии снимков, которая собрана сливером и в
/// карточку-коробку не помещается.
///
/// Переносом, а не строкой: в узкой карточке клавиши справа уходят под
/// имя, а не за край. Строкой они получали бесконечную ширину, и их
/// собственный перенос не срабатывал никогда.
class SectionCardHeader extends StatelessWidget {
  const SectionCardHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: EvaporateSpacing.block),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: EvaporateSpacing.gap,
      runSpacing: EvaporateSpacing.gap,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: EvaporateIconSize.panel,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: EvaporateSpacing.gap),
            ],
            Flexible(child: Text(title, style: context.text.subtitle)),
          ],
        ),
        ?trailing,
      ],
    ),
  );
}

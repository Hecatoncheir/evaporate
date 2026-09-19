import 'package:flutter/material.dart';

import '../theme.dart';

/// Подпись раздела: короткая метка на корпусе и, если нужно, орган
/// управления справа.
///
/// Названия раздела в ней нет намеренно. Оно уже стоит подсвеченным в
/// обойме сверху, и три имени одного раздела — клавиша в обойме, метка и
/// заголовок кеглем 34 — отнимали у содержимого около сотни точек высоты на
/// каждом экране. В библиотеке, где под заголовком стоят ещё крупный кадр и
/// полки, из-за этого в окне 1280×900 не оставалось места ни одному
/// полному ряду обложек.
///
/// Метка остаётся: она говорит, чем раздел занят, а не как называется.
///
/// Диктору при этом уходит обычное название раздела ([semanticsLabel]), а
/// не метка: «[ 01 / КОЛЛЕКЦИЯ ]» он прочёл бы вместе со скобками и
/// косой чертой. Заголовком (`header`) — чтобы по разделам можно было
/// перемещаться так же, как раньше по крупным надписям.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.label,
    required this.semanticsLabel,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      EvaporateLayout.gutter,
      20,
      EvaporateLayout.gutter,
      10,
    ),
  });

  /// Метка на корпусе — та самая, в скобках.
  final String label;

  /// Название раздела для экранного диктора.
  final String semanticsLabel;

  /// Орган управления в той же строке, у правого края.
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            label: semanticsLabel,
            child: ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.eyebrow.copyWith(
                  color: context.colors.primary,
                ),
              ),
            ),
          ),
        ),
        if (trailing case final trailing?) ...[
          const SizedBox(width: 16),
          trailing,
        ],
      ],
    ),
  );
}

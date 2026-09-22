import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_mark.dart';

/// Знак и название приложения в левом краю рейки.
class TopBarBrand extends StatelessWidget {
  const TopBarBrand({super.key, required this.compact});

  /// В узком окне остаётся один знак: место нужно обойме разделов.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Знак в собственной оправе с волосяным кантом: на чернильном фоне
        // без канта он выглядит вырезанным из другой картинки.
        Container(
          padding: const EdgeInsets.all(EvaporateLayout.wellInset),
          decoration: BoxDecoration(
            border: Border.all(
              color: colors.primary.withValues(alpha: EvaporateAlpha.rim),
            ),
            borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
          ),
          child: const AppMark(size: 30),
        ),
        if (!compact) ...[
          const SizedBox(width: EvaporateSpacing.cluster),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'EVAPORATE',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontFamily: EvaporateTheme.monoFontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: EvaporateSpacing.line),
              // Короткий золотой штрих под словом — подпись на корпусе,
              // а не украшение: он же задаёт фирменный цвет всей рейке.
              Container(width: 26, height: 2, color: colors.primary),
            ],
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme.dart';

/// Название игры на крупном кадре — в полный рост и в полосе.
///
/// Кегль здесь числом, а не ролью: это надпись поверх картинки, её облик —
/// часть кадра. Тень нужна той же картинке: светлая обложка иначе съела
/// бы белые буквы.
class FeaturedTitle extends StatelessWidget {
  const FeaturedTitle(this.title, {super.key, this.compact = false});

  final String title;

  /// Полоса: одна строка и кегль мельче.
  final bool compact;

  @override
  Widget build(BuildContext context) => Text(
    title.toUpperCase(),
    maxLines: compact ? 1 : 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: AppColors.coverText,
      fontFamily: EvaporateTheme.displayFontFamily,
      // Крупнее не влезает: под названием в полный рост стоят строка
      // плашек и ряд клавиш.
      fontSize: compact ? 22 : 32,
      height: 1.04,
      fontWeight: FontWeight.w800,
      // Разряд положительный: у широкого шрифта прижатые заглавные
      // слипаются.
      letterSpacing: 0.6,
      shadows: [
        Shadow(blurRadius: compact ? 14 : 18, color: AppColors.coverTextShadow),
      ],
    ),
  );
}

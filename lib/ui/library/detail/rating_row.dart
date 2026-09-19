import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game_rating.dart';
import '../../theme.dart';
import '../../widgets/toned_chip.dart';

/// Как игру оценили: подпись Steam, доля положительных, оба счётчика
/// обзоров и оценка прессы.
///
/// Подпись приходит от Steam словами и показывается как есть. Числа рядом
/// набраны моношириной с табличными цифрами — они соседствуют в строке, и
/// пропорциональные цифры расставили бы их вразнобой.
///
/// `Wrap`, а не `Row`: «Крайне положительные» с четырьмя числами не
/// помещаются в узкое окно, а обрезанная оценка хуже перенесённой.
class RatingRow extends StatelessWidget {
  const RatingRow({super.key, required this.rating});

  final GameRating rating;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l = L.of(context);
    final summary = rating.summary;
    // Цвет берётся от ступени Steam, а не от доли: у Steam граница между
    // «смешанными» и «в основном положительными» зависит ещё и от числа
    // обзоров, и своя граница по проценту красила бы вопреки подписи.
    final verdict = switch (rating.score) {
      final int score when score >= 6 => colors.accent,
      5 => colors.warning,
      final int score when score >= 1 => colors.danger,
      _ => colors.textSecondary,
    };

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (summary != null && summary.isNotEmpty)
          Text(
            summary,
            style: context.text.note.copyWith(
              fontWeight: FontWeight.w600,
              color: verdict,
            ),
          ),
        if (rating.total > 0) ...[
          Tooltip(
            message: l.reviewsShare(rating.positiveShare),
            child: Text(
              '${rating.positiveShare}%',
              style: context.text.figure.copyWith(color: verdict),
            ),
          ),
          _Count(
            icon: Icons.thumb_up_outlined,
            value: rating.positive,
            label: l.reviewsPositiveCount(formatCount(rating.positive)),
          ),
          _Count(
            icon: Icons.thumb_down_outlined,
            value: rating.negative,
            label: l.reviewsNegativeCount(formatCount(rating.negative)),
          ),
        ],
        if (rating.metacritic != null) _Metacritic(score: rating.metacritic!),
      ],
    );
  }
}

/// Счётчик обзоров: значок и число.
///
/// Диктору уходит цельная фраза, а значок с числом из объявления убраны:
/// «палец вверх, пятьдесят четыре тысячи» не складывается в смысл.
class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.textSecondary;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              formatCount(value),
              style: context.text.figure.copyWith(
                fontWeight: FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Оценка прессы. Отдельной плашкой: она о другом — не о том, что думают
/// игроки, а о том, что написали рецензенты, и слиться с долей обзоров ей
/// нельзя.
class _Metacritic extends StatelessWidget {
  const _Metacritic({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Цвета — самого Metacritic, и они часть его оценки: зелёное, жёлтое и
    // красное там означают ровно то же, что у нас accent, warning и danger.
    final color = score >= 75
        ? colors.accent
        : (score >= 50 ? colors.warning : colors.danger);

    return Tooltip(
      message: L.of(context).metacriticScore(score),
      child: TonedChip(
        text: 'Metacritic $score',
        color: color,
        style: context.text.chip,
      ),
    );
  }
}

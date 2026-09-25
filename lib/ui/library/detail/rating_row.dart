import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/game_rating.dart';
import '../../labels.dart';
import '../../theme.dart';
import 'metacritic_badge.dart';
import 'review_count.dart';

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
      spacing: EvaporateSpacing.field,
      runSpacing: EvaporateSpacing.tight,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (summary != null && summary.isNotEmpty)
          Text(
            summary,
            style: context.text.captionStrong.copyWith(color: verdict),
          ),
        if (rating.total > 0) ...[
          Tooltip(
            message: l.reviewsShare(rating.positiveShare),
            child: Text(
              '${rating.positiveShare}%',
              style: context.text.figure.copyWith(color: verdict),
            ),
          ),
          ReviewCount(
            icon: Icons.thumb_up_outlined,
            value: rating.positive,
            label: l.reviewsPositiveCount(
              countLabel(L.of(context), rating.positive),
            ),
          ),
          ReviewCount(
            icon: Icons.thumb_down_outlined,
            value: rating.negative,
            label: l.reviewsNegativeCount(
              countLabel(L.of(context), rating.negative),
            ),
          ),
        ],
        if (rating.metacritic != null)
          MetacriticBadge(score: rating.metacritic!),
      ],
    );
  }
}

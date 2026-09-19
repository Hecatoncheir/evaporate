import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/bulk_report.dart';
import '../theme.dart';

/// Одна группа отчёта о переносе: исход с числом игр и сами игры под ним.
class BulkOutcomeGroup extends StatelessWidget {
  const BulkOutcomeGroup({
    super.key,
    required this.report,
    required this.outcome,
  });

  final BulkReport report;
  final BulkOutcome outcome;

  /// Константой быть не может: подписи зависят от языка.
  static String _title(L l, BulkOutcome outcome) => switch (outcome) {
    BulkOutcome.applied => l.outcomeApplied,
    BulkOutcome.conflicted => l.outcomeConflicted,
    BulkOutcome.unmatched => l.outcomeUnmatched,
    BulkOutcome.skipped => l.outcomeSkipped,
    BulkOutcome.failed => l.outcomeFailed,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(
            '${_title(L.of(context), outcome)} — ${report.count(outcome)}',
            style: context.text.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: switch (outcome) {
                BulkOutcome.applied => colors.accent,
                BulkOutcome.skipped => colors.textSecondary,
                _ => colors.warning,
              },
            ),
          ),
        ),
        for (final entry in report.withOutcome(outcome))
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 1),
            child: Text(
              entry.detail == null
                  ? entry.title
                  : '${entry.title} — ${entry.detail}',
              style: context.text.captionMuted,
            ),
          ),
      ],
    );
  }
}

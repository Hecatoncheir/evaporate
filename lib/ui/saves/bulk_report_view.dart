import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/bulk_report.dart';
import '../theme.dart';
import 'bulk_outcome_group.dart';

/// Подробности последней массовой операции.
///
/// Одной строкой «с ошибкой: 3» пользоваться нельзя: непонятно, какие игры и
/// почему. Для операции над всей библиотекой это важно — там легко не
/// заметить, что часть сохранений не перенеслась.
class BulkReportView extends StatelessWidget {
  const BulkReportView({super.key, required this.report});

  final BulkReport report;

  /// Сначала то, из-за чего стоит беспокоиться.
  static const _order = [
    BulkOutcome.failed,
    BulkOutcome.conflicted,
    BulkOutcome.unmatched,
    BulkOutcome.applied,
    BulkOutcome.skipped,
  ];

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (final outcome in _order)
        if (report.count(outcome) > 0) outcome,
    ];
    if (groups.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: EvaporateSpacing.block),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: EvaporateSpacing.gap),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        // Раскрыт сразу, если есть о чём беспокоиться: спрятанное
        // предупреждение — почти то же самое, что его отсутствие.
        initiallyExpanded: report.hasProblems,
        title: Text(
          report.isExport
              ? L.of(context).reportExported
              : L.of(context).reportImported,
          style: context.text.bodyStrong,
        ),
        children: [
          for (final outcome in groups)
            BulkOutcomeGroup(report: report, outcome: outcome),
        ],
      ),
    );
  }
}

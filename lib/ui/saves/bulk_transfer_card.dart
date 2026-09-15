import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/saves/saves_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/bulk_report.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Подробности последней массовой операции.
///
/// Одной строкой «с ошибкой: 3» пользоваться нельзя: непонятно, какие игры и
/// почему. Для операции над всей библиотекой это важно — там легко не
/// заметить, что часть сохранений не перенеслась.
class _BulkReportView extends StatelessWidget {
  const _BulkReportView({required this.report});

  final BulkReport report;

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
    // Сначала то, из-за чего стоит беспокоиться.
    const order = [
      BulkOutcome.failed,
      BulkOutcome.conflicted,
      BulkOutcome.unmatched,
      BulkOutcome.applied,
      BulkOutcome.skipped,
    ];

    final groups = [
      for (final outcome in order)
        if (report.count(outcome) > 0) outcome,
    ];
    if (groups.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        // Раскрыт сразу, если есть о чём беспокоиться: спрятанное
        // предупреждение — почти то же самое, что его отсутствие.
        initiallyExpanded: report.hasProblems,
        title: Text(
          report.isExport
              ? L.of(context).reportExported
              : L.of(context).reportImported,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        children: [
          for (final outcome in groups) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Text(
                  '${_title(L.of(context), outcome)} — ${report.count(outcome)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: outcome == BulkOutcome.applied
                        ? context.colors.accent
                        : outcome == BulkOutcome.skipped
                        ? context.colors.textSecondary
                        : context.colors.warning,
                  ),
                ),
              ),
            ),
            for (final entry in report.withOutcome(outcome))
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, top: 1),
                  child: Text(
                    entry.detail == null
                        ? entry.title
                        : '${entry.title} — ${entry.detail}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Перенос всей библиотеки разом: снять сохранения всех игр в одну папку
/// и разложить их обратно на другом устройстве.
class BulkTransferCard extends StatelessWidget {
  const BulkTransferCard({super.key});

  @override
  Widget build(BuildContext context) {
    final busy = context.select<SavesBloc, bool>(
      (bloc) => bloc.state.isBusy(SavesBloc.bulkKey),
    );
    final report = context.select<SavesBloc, BulkReport?>(
      (bloc) => bloc.state.bulkReport,
    );

    return SectionCard(
      title: L.of(context).bulkTransfer,
      icon: Icons.swap_horiz,
      // Сколько игр с путями — теперь в показаниях сверху, и повторять это
      // число в углу карточки незачем.
      trailing: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.of(context).bulkTransferNote,
            style: TextStyle(
              fontSize: 13,
              color: context.colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : () => _export(context),
                icon: const Icon(Icons.upload_outlined, size: 16),
                label: Text(L.of(context).exportAll),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _import(context),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: Text(L.of(context).importAll),
              ),
            ],
          ),
          if (report != null && !report.isEmpty)
            _BulkReportView(report: report),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final saves = context.read<SavesBloc>();
    final dir = await getDirectoryPath(confirmButtonText: L.of(context).export);
    if (dir == null) return;
    saves.add(BulkExportRequested(dir));
  }

  /// Спрашивает, как поступить с играми, где здешние сохранения новее.
  ///
  /// Возвращает `null`, если загрузку отменили. Разделение на два действия
  /// вместо галочки намеренное: это выбор, а не настройка, и человек должен
  /// сделать его осознанно в тот момент, когда он что-то значит.
  Future<bool?> _askAboutNewer(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L.of(context).importAllQuestion),
        content: Text(L.of(context).importAllNote),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(L.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(L.of(context).importOverwriteNewer),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(L.of(context).importSkipNewer),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final saves = context.read<SavesBloc>();
    final dir = await getDirectoryPath(confirmButtonText: L.of(context).import);
    if (dir == null || !context.mounted) return;

    final overwrite = await _askAboutNewer(context);
    if (overwrite == null) return;
    saves.add(BulkImportRequested(dir, overwriteNewer: overwrite));
  }
}

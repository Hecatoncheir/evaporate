import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/saves/saves_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/bulk_report.dart';
import '../theme.dart';
import '../widgets/section_card.dart';
import 'bulk_report_view.dart';
import 'import_newer_dialog.dart';

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
          Text(L.of(context).bulkTransferNote, style: context.text.paragraph),
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
          if (report != null && !report.isEmpty) BulkReportView(report: report),
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

  Future<void> _import(BuildContext context) async {
    final saves = context.read<SavesBloc>();
    final dir = await getDirectoryPath(confirmButtonText: L.of(context).import);
    if (dir == null || !context.mounted) return;

    final overwrite = await showDialog<bool>(
      context: context,
      builder: (_) => const ImportNewerDialog(),
    );
    if (overwrite == null) return;
    saves.add(BulkImportRequested(dir, overwriteNewer: overwrite));
  }
}

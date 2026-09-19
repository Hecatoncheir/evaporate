import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/download_task.dart';
import '../../downloads/download_activity.dart';
import '../../labels.dart';
import '../../theme.dart';

/// Строка под графиком: сколько осталось и с кем обмениваемся.
///
/// Полосу и проценты рисует сам [DownloadActivity] — здесь только то, чего
/// у него нет. Две полосы подряд означали бы, что одна из них лишняя, и
/// человек честно пытался бы понять, чем они различаются.
class DownloadSummary extends StatelessWidget {
  const DownloadSummary({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: context.text.note,
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          if (task.isMetadata)
            Text(L.of(context).fetchingTorrentMetadata)
          else ...[
            if (task.etaSeconds > 0)
              Text(
                L
                    .of(context)
                    .etaLeft(formatEtaLabel(L.of(context), task.etaSeconds)),
              ),
            Text(L.of(context).peersCount(task.connections)),
            if (task.seeders > 0) Text(L.of(context).seedsCount(task.seeders)),
          ],
        ],
      ),
    );
  }
}

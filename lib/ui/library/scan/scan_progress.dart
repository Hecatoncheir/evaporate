import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/app_localizations.dart';
import '../../../services/launch/scan_session.dart';
import '../../theme.dart';

/// Что происходит прямо сейчас.
///
/// Обход дисков идёт секундами: окно с одной вертушкой ничем не отличается
/// от зависшего, а название осматриваемой папки показывает, что работа идёт
/// и сколько её осталось на глаз.
class ScanProgress extends StatelessWidget {
  const ScanProgress({super.key, required this.session});

  final ScanSession session;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final directory = session.directory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (session.isRunning) ...[
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                // Сколько всего папок, заранее неизвестно: считать их —
                // тот же обход, только дважды.
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: EvaporateSpacing.cluster),
              Expanded(
                child: Text(
                  directory == null
                      ? l.scanFoundCount(session.found.length)
                      : l.scanLooking(p.basename(directory)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.note,
                ),
              ),
            ],
          ),
        ] else if (!session.isComplete && session.found.isNotEmpty)
          Text(l.scanStopped, style: context.text.paragraph)
        else
          Text(
            l.scanFoundCount(session.found.length),
            style: context.text.note,
          ),
      ],
    );
  }
}

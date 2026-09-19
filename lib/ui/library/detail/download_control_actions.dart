import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../../downloads/cancel_dialog.dart';

/// Загрузка идёт или стоит на паузе: пауза или продолжение и отмена.
class DownloadControlActions extends StatelessWidget {
  const DownloadControlActions({
    super.key,
    required this.game,
    required this.task,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final Game game;
  final DownloadTask? task;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => _cancel(context),
          icon: const Icon(Icons.close, size: 17),
          label: Text(L.of(context).cancelDownload),
        ),
      ],
    );
  }

  /// Тот же вопрос, что на экране загрузок: действие одно и то же, и
  /// спрашивать о нём по-разному в двух местах незачем.
  Future<void> _cancel(BuildContext context) {
    final l = L.of(context);
    return cancelDownload(
      context,
      game: game,
      task: task,
      title: l.cancelDownloadQuestion,
      message: l.cancelDownloadNote,
      confirmLabel: l.cancelDownloadConfirm,
      confirmIcon: Icons.remove_circle_outline,
    );
  }
}

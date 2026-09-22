import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'drop_frame.dart';

/// Подсказка поверх сетки, пока над окном что-то держат.
///
/// Молчаливый приёмник — худший из возможных: пользователь не знает ни что
/// сюда можно, ни что случится, и проверяет это на своей библиотеке.
class DropOverlay extends StatelessWidget {
  const DropOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return IgnorePointer(
      child: Container(
        color: context.colors.background.withValues(alpha: EvaporateAlpha.veil),
        padding: const EdgeInsets.all(EvaporateSpacing.wide),
        child: DropFrame(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.download_for_offline_outlined,
                size: EvaporateIconSize.hero,
                color: context.colors.accent,
              ),
              const SizedBox(height: EvaporateSpacing.block),
              Text(
                l.dropRelease,
                style: context.text.title.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: EvaporateSpacing.tight),
              Text(
                '${l.dropHintFolder} • ${l.dropHintTorrent}',
                textAlign: TextAlign.center,
                style: context.text.bodyMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

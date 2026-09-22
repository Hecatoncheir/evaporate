import 'package:flutter/material.dart';

import '../../../../bloc/restore_preview/restore_preview_bloc.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../labels.dart';
import '../../../theme.dart';

/// Когда здешние сохранения менялись в последний раз.
///
/// Массовый перенос такие расхождения ловит сам, а здесь до сих пор
/// молчали — притом что восстановить одну игру просят чаще, чем переехать
/// всей библиотекой.
class LocalFreshnessNote extends StatelessWidget {
  const LocalFreshnessNote({super.key, required this.preview});

  final RestorePreview preview;

  @override
  Widget build(BuildContext context) {
    // «Не знаем» и «сохранений не было» — разные вещи: на неудавшемся
    // чтении молчим, а не заявляем, что сейвы никогда не трогали.
    if (!preview.known) return const SizedBox.shrink();

    final l = L.of(context);
    final changedAt = preview.changedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text(
          changedAt == null
              ? l.localNeverChanged
              : l.localChangedAt(dateTimeLabel(L.of(context), changedAt)),
          style: context.text.note.copyWith(
            color: preview.newer
                ? context.colors.warning
                : context.colors.textSecondary,
          ),
        ),
        if (preview.newer) ...[
          const SizedBox(height: 4),
          Text(
            l.localNewerWarning,
            style: context.text.warning.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

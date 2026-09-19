import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../bloc/save_freshness_cubit.dart';
import '../../../../bloc/saves/saves_bloc.dart';
import '../../../../core/format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../theme.dart';

/// Когда здешние сохранения менялись в последний раз.
///
/// Массовый перенос такие расхождения ловит сам, а здесь до сих пор
/// молчали — притом что восстановить одну игру просят чаще, чем переехать
/// всей библиотекой.
class LocalFreshnessNote extends StatelessWidget {
  const LocalFreshnessNote({super.key, required this.snapshotAt});

  /// Когда снят снимок: с ним и сравниваем здешние сохранения.
  final DateTime snapshotAt;

  /// Здешние сохранения новее снимка настолько, что восстановление — это
  /// откат прогресса.
  ///
  /// Допуск тот же, что и у массового переноса: часы разных устройств
  /// расходятся, а время изменения файла хранится с разной точностью на
  /// разных файловых системах.
  bool _isNewer(DateTime? local) =>
      local != null &&
      local.isAfter(snapshotAt.add(SavesBloc.conflictTolerance));

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SaveFreshnessCubit, SaveFreshness>(
      builder: (context, freshness) {
        // «Не знаем» и «сохранений не было» — разные вещи: на неудавшемся
        // чтении молчим, а не заявляем, что сейвы никогда не трогали.
        if (!freshness.known) return const SizedBox.shrink();

        final l = L.of(context);
        final newer = _isNewer(freshness.changedAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              freshness.changedAt == null
                  ? l.localNeverChanged
                  : l.localChangedAt(formatDateTime(freshness.changedAt!)),
              style: context.text.note.copyWith(
                color: newer
                    ? context.colors.warning
                    : context.colors.textSecondary,
              ),
            ),
            if (newer) ...[
              const SizedBox(height: 4),
              Text(
                l.localNewerWarning,
                style: context.text.warning.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

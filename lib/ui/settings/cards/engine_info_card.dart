import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/download/download_engine.dart';
import '../../labels.dart';
import '../../theme.dart';
import '../../widgets/info_row.dart';
import '../../widgets/section_card.dart';
import '../setting_note.dart';

/// Справка о движке загрузок.
///
/// Без клавиши перезапуска: она осталась одна, на самих загрузках, где
/// движок и живёт.
class EngineInfoCard extends StatelessWidget {
  const EngineInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Только состояние движка, а не весь блок: скорости в нём меняются раз
    // в секунду, а страница настроек живёт в IndexedStack и строится даже
    // тогда, когда открыта библиотека. Подписка на всё перерисовывала бы
    // её ежесекундно всю загрузку напролёт.
    final engine = context.select<DownloadsBloc, EngineStatus>(
      (bloc) => bloc.state.engine,
    );
    return SectionCard(
      title: l.downloadEngine,
      icon: Icons.settings_ethernet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(
            label: l.engineState,
            value: engine.message ?? engineStateLabel(l, engine.state),
            valueColor: engine.isReady
                ? context.colors.accent
                : context.colors.warning,
          ),
          InfoRow(label: l.engineImplementation, value: l.engineBuiltIn),
          const SizedBox(height: EvaporateSpacing.gap),
          SettingNote(l.engineNote),
        ],
      ),
    );
  }
}

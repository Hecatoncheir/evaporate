import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/speed_limits.dart';
import '../speed_field.dart';

/// Ограничения скорости: приём, отдача, доля раздачи и приём во время игры.
///
/// Пределы скорости торрент-библиотека пока не соблюдает (см.
/// `DtorrentEngine.applyLimits`), и об этом сказано прямо над полями: поле,
/// которое молча ничего не делает, хуже отсутствующего. Сами значения
/// хранятся — заработают без перенастройки, когда библиотеку починят.
/// Рейтинг раздачи считаем сами, он действует.
class SpeedLimitsSettings extends StatelessWidget {
  const SpeedLimitsSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<SettingsBloc>();
    final settings = store.state;
    final limits = settings.limits;
    void limit(SpeedLimits next) =>
        store.add(SettingsPatched((current) => current.copyWith(limits: next)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpeedField(
          label: l.limitDownload,
          value: limits.download,
          onChanged: (value) => limit(limits.copyWith(download: value)),
        ),
        SpeedField(
          label: l.limitUpload,
          value: limits.upload,
          hint: l.limitUploadNote,
          onChanged: (value) => limit(limits.copyWith(upload: value)),
        ),
        SpeedField(
          label: l.seedRatio,
          value: limits.seedRatio,
          unit: l.seedRatioUnit,
          hint: l.seedRatioNote,
          onChanged: (value) => limit(limits.copyWith(seedRatio: value)),
        ),
        SpeedField(
          label: l.limitWhilePlaying,
          value: limits.whilePlaying,
          hint: l.limitPlayingNote,
          onChanged: (value) => limit(limits.copyWith(whilePlaying: value)),
        ),
      ],
    );
  }
}

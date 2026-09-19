import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../input/gamepad_service.dart';
import '../../l10n/app_localizations.dart';
import '../../services/download/download_engine.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/button_hints.dart';
import '../widgets/pulse_dot.dart';

/// Нижняя строка: подсказки управления и показания движка.
///
/// Копирайт и ссылки на репозиторий отсюда убраны — это мебель сайта, а не
/// приложения: сорок точек высоты у них были заняты навсегда, а нажимали их
/// один раз в жизни. Ссылка на исходный код переехала в «О программе», где
/// и остальное про сборку.
///
/// Осталось то, что меняется: чем управлять прямо сейчас и едет ли обмен.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsBloc>().state;
    final gamepad = context.read<GamepadService>();
    return Container(
      height: EvaporateLayout.footerHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: context.colors.railBackground.withValues(alpha: 0.84),
        border: Border(
          top: BorderSide(
            color: context.colors.outline.withValues(alpha: 0.28),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ValueListenableBuilder<GamepadStatus>(
                valueListenable: gamepad.status,
                builder: (context, status, _) => ButtonHints(
                  binding: settings.gamepad,
                  gamepadConnected:
                      settings.gamepad.enabled && status.hasDevice,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const EngineReadout(),
        ],
      ),
    );
  }
}

/// Показания прибора в нижней строке: состояние движка и скорость обмена.
///
/// Стоят здесь, а не на экране загрузок: человек уходит из загрузок в
/// библиотеку и всё равно хочет знать, едет ли раздача. Числа — моношириной
/// с табличными цифрами, иначе строка дёргается на каждом обновлении.
class EngineReadout extends StatelessWidget {
  const EngineReadout({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final downloads = context.watch<DownloadsBloc>().state;
    final status = downloads.engine;
    final stats = downloads.stats;
    final l = L.of(context);

    final color = switch (status.state) {
      EngineState.ready => colors.accent,
      EngineState.starting => colors.warning,
      EngineState.failed => colors.danger,
      EngineState.stopped => colors.textSecondary,
    };
    // Разрядка уже, чем у метки: в строке состояния тесно. Цифры
    // табличные — показания меняются на глазах.
    final style = context.text.label.copyWith(
      letterSpacing: 0.7,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Мигает, только пока движок поднимается или сломан: ровно горящий
        // светодиод рядом со словом «готов» ничего не добавляет.
        PulseDot(
          color: color,
          size: 6,
          alive:
              status.state == EngineState.starting ||
              status.state == EngineState.failed,
        ),
        const SizedBox(width: 2),
        Text(
          engineStateLabel(l, status.state).toUpperCase(),
          style: style.copyWith(color: color),
        ),
        if (stats.activeCount > 0) ...[
          const SizedBox(width: 14),
          Icon(Icons.arrow_downward_rounded, size: 11, color: colors.primary),
          const SizedBox(width: 2),
          Text(speedLabel(l, stats.downloadSpeed), style: style),
          const SizedBox(width: 10),
          Icon(Icons.arrow_upward_rounded, size: 11, color: colors.accent),
          const SizedBox(width: 2),
          Text(speedLabel(l, stats.uploadSpeed), style: style),
        ],
      ],
    );
  }
}

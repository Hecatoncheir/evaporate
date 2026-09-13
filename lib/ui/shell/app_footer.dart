import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../input/gamepad_service.dart';
import '../../services/download/download_engine.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/button_hints.dart';
import '../widgets/pulse_dot.dart';
import '../../l10n/app_localizations.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsBloc>().state;
    final gamepad = context.read<GamepadService>();
    return Container(
      height: 40,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          return Row(
            children: [
              if (!compact)
                Text(
                  '© 2026 EVAPORATE',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontFamily: EvaporateTheme.monoFontFamily,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              if (!compact) const SizedBox(width: 24),
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
              if (!compact) ...[
                const EngineReadout(),
                const SizedBox(width: 16),
              ],
              const SizedBox(width: 2),
              FooterLink(
                label: 'GITHUB',
                onPressed: () => unawaited(
                  launchUrl(
                    Uri.parse('https://github.com/Hecatoncheir/evaporate'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 12,
                color: context.colors.outline.withValues(alpha: 0.5),
              ),
              FooterLink(
                label: 'RELEASES',
                onPressed: () => unawaited(
                  launchUrl(
                    Uri.parse(
                      'https://github.com/Hecatoncheir/evaporate/releases',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FooterLink extends StatelessWidget {
  const FooterLink({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: context.colors.textSecondary,
      minimumSize: const Size(64, 40),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(
        fontFamily: EvaporateTheme.monoFontFamily,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    ),
    child: Text(label),
  );
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
    final style = TextStyle(
      color: colors.textSecondary,
      fontFamily: EvaporateTheme.monoFontFamily,
      fontSize: 9,
      fontWeight: FontWeight.w700,
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

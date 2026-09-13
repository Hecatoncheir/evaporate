import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../input/gamepad_service.dart';
import '../theme.dart';
import '../widgets/button_hints.dart';

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
              const SizedBox(width: 18),
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

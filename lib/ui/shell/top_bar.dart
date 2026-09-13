import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../theme.dart';
import '../widgets/app_mark.dart';
import '../../l10n/app_localizations.dart';
import 'navigation.dart';

/// Верхняя рейка: бренд и действия стоят по краям, а разделы — ровно по
/// центру доступной ширины. В узком окне разделы переезжают вниз.
class ConceptTopBar extends StatelessWidget {
  const ConceptTopBar({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = context.watch<SettingsBloc>().state;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              // Знак в собственной оправе с волосяным кантом: на чернильном
              // фоне без канта он выглядит вырезанным из другой картинки.
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.42),
                  ),
                  borderRadius: BorderRadius.circular(
                    EvaporateTheme.radiusControl,
                  ),
                ),
                child: const AppMark(size: 30),
              ),
              if (!compact) ...[
                const SizedBox(width: 11),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'EVAPORATE',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontFamily: EvaporateTheme.monoFontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Короткий золотой штрих под словом — подпись на
                    // корпусе, а не украшение: он же задаёт фирменный цвет
                    // всей рейке.
                    Container(width: 26, height: 2, color: colors.primary),
                  ],
                ),
              ],
              if (compact) ...[
                // В узком окне разделы остаются в рейке, а не уезжают вниз:
                // обойма сама прячет подписи и сжимается по месту. Прежде
                // она переезжала под содержимое и налезала на подсказки
                // управления в нижней строке.
                const SizedBox(width: 10),
                const Expanded(child: Center(child: ConceptNavigation())),
                const SizedBox(width: 10),
              ] else
                const Spacer(),
              TopAction(
                tooltip: L.of(context).searchHint,
                icon: Icons.search_rounded,
                onPressed: () => context.read<NavigationBloc>().add(
                  const SearchFocusRequested(),
                ),
              ),
              const SizedBox(width: 7),
              TopAction(
                tooltip: dark
                    ? L.of(context).lightThemeAction
                    : L.of(context).darkThemeAction,
                icon: dark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                onPressed: () {
                  context.read<SettingsBloc>().add(
                    SettingsChanged(
                      settings.copyWith(
                        themeMode: dark ? ThemeMode.light : ThemeMode.dark,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 7),
              TopAction(
                key: const ValueKey('rail-quit'),
                tooltip: L.of(context).quitApp,
                hiddenLabel: L.of(context).quitApp,
                icon: Icons.power_settings_new_rounded,
                danger: true,
                onPressed: () => unawaited(windowManager.close()),
              ),
            ],
          ),
          if (!compact) const ConceptNavigation(),
        ],
      ),
    );
  }
}

/// Клавиша верхней рейки. Под курсором подсвечивается и чуть поднимается —
/// на строке из одинаковых квадратов это единственный способ показать, где
/// именно сейчас рука.
class TopAction extends StatefulWidget {
  const TopAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.hiddenLabel,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final String? hiddenLabel;

  /// Действие, которое закрывает приложение. Подсвечивается тревожным
  /// цветом только под курсором: постоянно красная кнопка выхода в углу
  /// читалась бы как поломка.
  final bool danger;

  @override
  State<TopAction> createState() => _TopActionState();
}

class _TopActionState extends State<TopAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = widget.danger ? colors.danger : colors.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: context.motion.fast,
        curve: EvaporateMotion.ease,
        transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
        child: IconButton(
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
          icon: Stack(
            alignment: Alignment.center,
            children: [
              Icon(widget.icon, size: 18),
              if (widget.hiddenLabel case final label?)
                SizedBox.shrink(child: ExcludeSemantics(child: Text(label))),
            ],
          ),
          style: IconButton.styleFrom(
            minimumSize: const Size(38, 38),
            backgroundColor: _hovered
                ? colors.surfaceHigh
                : colors.surface.withValues(alpha: 0.5),
            foregroundColor: _hovered ? accent : colors.textSecondary,
            side: BorderSide(
              color: _hovered ? accent.withValues(alpha: 0.6) : colors.outline,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../models/app_section.dart';
import '../../models/library_effect.dart';
import '../theme.dart';
import '../widgets/liquid/liquid_selection.dart';
import 'navigation_key.dart';
import 'window_drag_area.dart';

/// Обойма разделов: колонка слева во всю высоту окна — знак сверху, под
/// ним клавиши разделов и капля выбранного.
///
/// Колонкой, а не рядом в верхней панели: клавиш четыре, и в ряд они
/// делили ширину панели с поиском и клавишами окна, так что в узком окне
/// прятали подписи, а потом сжимались. Колонке ширины хватает всегда, а
/// имя открытого раздела стоит в крошке верхней рейки.
class NavigationRack extends StatelessWidget {
  const NavigationRack({
    super.key,
    required this.targets,
    required this.labels,
    required this.icons,
    required this.section,
    required this.queuedAt,
  });

  /// Ключи клавиш: за ними следует капля выбранного.
  final Map<AppSection, GlobalKey> targets;

  final Map<AppSection, String> labels;
  final Map<AppSection, IconData> icons;
  final AppSection section;

  /// Сколько задач в работе у раздела. Нет записи — метки нет.
  final Map<AppSection, int> queuedAt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final surface = HardwareSurfaceTheme.of(context);
    return Container(
      key: const ValueKey('navigation-rack'),
      width: EvaporateLayout.railWidth,
      padding: const EdgeInsets.symmetric(vertical: EvaporateSpacing.field),
      decoration: BoxDecoration(
        color: colors.railBackground,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
        boxShadow: [
          // Ночью обойма лежит в мягкой тени, днём — на коротком жёстком
          // торце: один и тот же приём выглядел бы на светлом грязью.
          BoxShadow(
            color: colors.shadow,
            blurRadius: surface.railShadowBlur,
            offset: Offset(0, surface.railShadowDrop),
          ),
        ],
      ),
      child: Column(
        children: [
          const _RailMark(),
          const SizedBox(height: EvaporateSpacing.panel),
          LiquidSelection(
            key: const ValueKey('rail-liquid'),
            targetKey: () => targets[section],
            color: colors.selection,
            radius: EvaporateTheme.radiusControl,
            enabled: context.select<SettingsBloc, bool>(
              (b) => b.state.appearance.shows(LibraryEffect.liquidSelection),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: EvaporateSpacing.line,
              children: [
                for (final value in AppSection.values)
                  NavigationKey(
                    key: ValueKey('rail-${value.name}'),
                    targetKey: targets[value]!,
                    section: value,
                    label: labels[value]!,
                    icon: icons[value]!,
                    selected: section == value,
                    queued: queuedAt[value] ?? 0,
                  ),
              ],
            ),
          ),
          // Пустое поле обоймы под клавишами тянет окно, как верхняя
          // рейка: взяться за окно у левого края — такое же ожидание.
          const Expanded(child: WindowDragArea()),
        ],
      ),
    );
  }
}

/// Знак приложения над разделами — та же картинка, что в системных
/// ресурсах, в собственной оправе: на чернильном фоне без канта он
/// выглядит вырезанным из другой картинки. Под знаком — подложка, которая
/// тянет окно: знак не орган управления.
class _RailMark extends StatelessWidget {
  const _RailMark();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      const Positioned.fill(child: WindowDragArea()),
      IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(EvaporateLayout.wellInset),
          decoration: BoxDecoration(
            border: Border.all(
              color: context.colors.primary.withValues(
                alpha: EvaporateAlpha.rim,
              ),
            ),
            borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(EvaporateTheme.radiusChip),
            child: Image.asset(
              'assets/branding/app_icon.png',
              width: EvaporateLayout.railMark,
              height: EvaporateLayout.railMark,
            ),
          ),
        ),
      ),
    ],
  );
}

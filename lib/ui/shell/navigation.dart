import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../theme.dart';
import '../widgets/liquid_selection.dart';
import '../../l10n/app_localizations.dart';

/// Разделы приложения: четыре клавиши в одной обойме и плашка выбранного,
/// которая переезжает между ними.
///
/// Клавиши **одной ширины**, хотя подписи разной длины. Так плашка едет
/// ровным шагом, ряд читается как один орган управления, а не как четыре
/// кнопки подряд, и при смене языка обойма не меняет размер.
///
/// Ширина считается от того, что дали, а не задана числом: обойма стоит в
/// верхней рейке при любом размере окна, и в узком месте сначала прячет
/// подписи, потом число задач, и лишь затем сжимает сами клавиши. Заданная
/// числом ширина переполняла рейку на считанные точки — ровно те, из-за
/// которых Flutter рисует полосатую ленту поверх интерфейса.
///
/// Подпись раздела диктору достаётся всегда, даже когда её не видно: без
/// неё узкое окно оставило бы человека с четырьмя безымянными значками.
class ConceptNavigation extends StatefulWidget {
  const ConceptNavigation({super.key});

  @override
  State<ConceptNavigation> createState() => _ConceptNavigationState();
}

class _ConceptNavigationState extends State<ConceptNavigation> {
  /// Клавиша во всю ширину — с подписью и запасом по краям.
  static const _fullWidth = 130.0;

  /// Ниже этого подпись уже не влезает целиком: «БИБЛИОТЕКА» плюс значок,
  /// просвет и поля занимают почти сто тридцать точек.
  static const _labelWidth = 124.0;

  /// А ниже этого не влезает и число задач рядом со значком.
  static const _badgeWidth = 58.0;

  /// Поле и кант самой обоймы: они тоже занимают место в рейке.
  static const _chrome = 8.0;

  /// Метка с числом задач стоит только у загрузок — это их клавиша.
  static const _downloadsSection = 1;

  final _targets = List.generate(4, (_) => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final section = context.select<NavigationBloc, int>(
      (bloc) => bloc.state.section,
    );
    final count = context.select<DownloadsBloc, int>(
      (bloc) => bloc.state.activeTasks.length,
    );
    final labels = [
      L.of(context).library,
      L.of(context).downloads,
      L.of(context).saves,
      L.of(context).settings,
    ];
    const icons = [
      Icons.grid_view_outlined,
      Icons.download_rounded,
      Icons.save_rounded,
      Icons.settings_rounded,
    ];
    return LayoutBuilder(
      builder: (context, box) =>
          _rack(context, box, labels, icons, section, count),
    );
  }

  /// Сама обойма: корпус, плашка выбранного и четыре клавиши в ряд.
  Widget _rack(
    BuildContext context,
    BoxConstraints box,
    List<String> labels,
    List<IconData> icons,
    int section,
    int count,
  ) {
    final colors = context.colors;
    final fit = _fit(box, labels.length);

    return Container(
      key: const ValueKey('concept-navigation'),
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.railBackground,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
        boxShadow: [
          // Ночью обойма лежит в мягкой тени, днём — на коротком жёстком
          // торце: один и тот же приём выглядел бы на светлом грязью.
          BoxShadow(
            color: colors.shadow,
            blurRadius: colors.isDark ? 22 : 8,
            offset: Offset(0, colors.isDark ? 10 : 2),
          ),
        ],
      ),
      child: LiquidSelection(
        key: const ValueKey('rail-liquid'),
        targetKey: () => _targets[section],
        color: colors.selection,
        radius: EvaporateTheme.radiusChip,
        enabled: context.select<SettingsBloc, bool>(
          (b) => b.state.libraryEffects && b.state.liquidSelectionEnabled,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < labels.length; index++)
              _button(
                context,
                index: index,
                label: labels[index],
                icon: icons[index],
                selected: section == index,
                queued: index == _downloadsSection ? count : 0,
                fit: fit,
              ),
          ],
        ),
      ),
    );
  }

  /// Сколько места досталось одной клавише.
  ///
  /// Делим ровно то, что дали, за вычетом собственных поля и канта обоймы:
  /// забыть про них — те самые восемь точек переполнения. Округлять вверх
  /// нельзя: переполнение на две точки выглядит так же плохо, как на
  /// двадцать.
  static _RackFit _fit(BoxConstraints box, int buttons) {
    final room = box.maxWidth.isFinite
        ? box.maxWidth - _chrome
        : buttons * _fullWidth;
    final per = room <= 0 ? 0.0 : room / buttons;
    return _RackFit(
      width: per < _fullWidth ? per : _fullWidth,
      showLabels: per >= _labelWidth,
      showBadge: per >= _badgeWidth,
    );
  }

  /// Одна клавиша обоймы: значок, подпись и, у загрузок, число задач.
  Widget _button(
    BuildContext context, {
    required int index,
    required String label,
    required IconData icon,
    required bool selected,
    required int queued,
    required _RackFit fit,
  }) {
    final colors = context.colors;
    return SizedBox(
      width: fit.width,
      child: TextButton(
        key: _targets[index],
        onPressed: () =>
            context.read<NavigationBloc>().add(SectionSelected(index)),
        // ignore: sort_child_properties_last
        child: Semantics(
          label: label,
          child: ExcludeSemantics(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LiquidSelectionInk(
                    normalColor: colors.textSecondary,
                    selectedColor: colors.onSelection,
                    child: Icon(icon, size: 16),
                  ),
                  if (fit.showLabels) ...[
                    const SizedBox(width: 8),
                    // Заглавными: короткая подпись на корпусе, а не слово
                    // в предложении. Диктору достаётся обычное слово —
                    // часть читалок разбирает капс по буквам, как
                    // сокращение.
                    Flexible(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ),
                    ),
                  ],
                  if (fit.showBadge && queued > 0) ...[
                    const SizedBox(width: 6),
                    _QueueBadge(count: queued, selected: selected),
                  ],
                ],
              ),
            ),
          ),
        ),
        style: _buttonStyle(colors, width: fit.width, selected: selected),
      ),
    );
  }

  static ButtonStyle _buttonStyle(
    EvaporatePalette colors, {
    required double width,
    required bool selected,
  }) => TextButton.styleFrom(
    minimumSize: Size(width, 42),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    foregroundColor: selected ? colors.onSelection : colors.textSecondary,
    backgroundColor: AppColors.transparent,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    alignment: Alignment.center,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(EvaporateTheme.radiusChip),
    ),
    textStyle: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
    ),
  );
}

/// Что помещается на клавише при нынешней ширине обоймы.
class _RackFit {
  const _RackFit({
    required this.width,
    required this.showLabels,
    required this.showBadge,
  });

  final double width;
  final bool showLabels;
  final bool showBadge;
}

/// Сколько задач в работе. На выбранной клавише метка выворачивается:
/// золотая метка на золотой плашке пропала бы.
class _QueueBadge extends StatelessWidget {
  const _QueueBadge({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: context.motion.fast,
      curve: EvaporateMotion.ease,
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: selected ? colors.onSelection : colors.primaryFill,
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusChip),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: selected ? colors.selection : colors.onPrimary,
          fontFamily: EvaporateTheme.monoFontFamily,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_section.dart';
import '../labels.dart';
import '../theme.dart';
import 'shell_glass.dart';
import 'top_bar_actions.dart';
import 'window_drag_area.dart';

/// Верхняя рейка: крошка «EVAPORATE / раздел» слева, поиск, смена
/// оформления и клавиши окна справа.
///
/// Своей полосы заголовка у окна нет, поэтому подложка рейки тянет окно.
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    // Кант — только на стыке с разделами: остальные края рейки — края
    // самой панели.
    return const ShellGlass(
      rim: {AxisDirection.down},
      child: SizedBox(
        height: EvaporateLayout.topBarHeight,
        // Слои во всю рейку: сжатый по себе ряд прижимался к её верху, а
        // не вставал посередине высоты.
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Подложка ниже всего остального: клавиши забирают нажатия себе,
            // а крошка и просветы между ними — тянут окно.
            WindowDragArea(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: EvaporateSpacing.card),
              child: Row(
                children: [
                  // Крошка — не орган управления: нажатие проходит сквозь неё
                  // к подложке. Иначе текст забирал бы его себе, и окно не
                  // тянулось бы за собственное имя — самое очевидное место,
                  // чтобы взяться.
                  IgnorePointer(child: _Crumb()),
                  Spacer(),
                  TopBarActions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «EVAPORATE / РАЗДЕЛ»: имя приложения и открытого раздела.
///
/// Имя раздела — отдельной надписью: оно на экране одно (метка на самой
/// странице — «[ 01 / КОЛЛЕКЦИЯ ]»), и искать его приходится целиком.
/// Диктору крошка не нужна: раздел он слышит заголовком страницы и
/// выбранной клавишей обоймы.
class _Crumb extends StatelessWidget {
  const _Crumb();

  @override
  Widget build(BuildContext context) {
    final section = context.select<NavigationBloc, AppSection>(
      (bloc) => bloc.state.section,
    );
    final colors = context.colors;
    final label = context.text.label;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: EvaporateSpacing.gap,
        children: [
          Text('EVAPORATE', style: label.copyWith(color: colors.textPrimary)),
          Text('/', style: label),
          Text(
            sectionLabel(L.of(context), section).toUpperCase(),
            style: label.copyWith(color: colors.primary),
          ),
        ],
      ),
    );
  }
}

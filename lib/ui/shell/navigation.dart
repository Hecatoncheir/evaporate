import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/navigation/navigation_bloc.dart';
import '../../l10n/app_localizations.dart';
import 'navigation_rack.dart';

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
  /// Метка с числом задач стоит только у загрузок — это их клавиша.
  static const _downloadsSection = 1;

  final _targets = List.generate(4, (_) => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final section = context.select<NavigationBloc, int>(
      (bloc) => bloc.state.section,
    );
    final count = context.select<DownloadsBloc, int>(
      (bloc) => bloc.state.inWork.length,
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
    return NavigationRack(
      targets: _targets,
      labels: labels,
      icons: icons,
      section: section,
      queuedAt: [
        for (var i = 0; i < labels.length; i++)
          i == _downloadsSection ? count : 0,
      ],
    );
  }
}

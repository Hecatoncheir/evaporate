import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/navigation/navigation_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_section.dart';
import '../labels.dart';
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
class RackNavigation extends StatefulWidget {
  const RackNavigation({super.key});

  @override
  State<RackNavigation> createState() => _RackNavigationState();
}

class _RackNavigationState extends State<RackNavigation> {
  final _targets = {
    for (final section in AppSection.values) section: GlobalKey(),
  };

  @override
  Widget build(BuildContext context) {
    final section = context.select<NavigationBloc, AppSection>(
      (bloc) => bloc.state.section,
    );
    final count = context.select<DownloadsBloc, int>(
      (bloc) => bloc.state.inWork.length,
    );
    final l = L.of(context);
    return NavigationRack(
      targets: _targets,
      section: section,
      labels: {
        for (final value in AppSection.values) value: sectionLabel(l, value),
      },
      icons: const {
        AppSection.library: Icons.grid_view_outlined,
        AppSection.downloads: Icons.download_rounded,
        AppSection.saves: Icons.save_rounded,
        AppSection.settings: Icons.settings_rounded,
      },
      // Метка с числом задач стоит только у загрузок — это их клавиша.
      queuedAt: {AppSection.downloads: count},
    );
  }
}

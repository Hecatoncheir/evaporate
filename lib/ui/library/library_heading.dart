import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_settings.dart';
import '../theme.dart';
import '../widgets/scale_control.dart';
import '../widgets/section_heading.dart';

/// Подпись библиотеки и крупность обложек.
///
/// Лозунг и абзац про «одну аккуратную библиотеку» отсюда убраны: человек,
/// открывший лончер в сотый раз, читал рекламу своего же приложения, а
/// стоила она вместе с заголовком около ста двадцати точек высоты — как раз
/// тех, из-за которых первый ряд обложек уходил под нижний край.
///
/// Крупность обложек живёт здесь, а не в настройках: это единственный
/// орган управления, который видно вместе с тем, на что он влияет, — его
/// крутят, глядя на сами обложки. Из настроек подпись берёт одну эту
/// крупность: смена папки игр или прокси её не перестраивает.
class ConceptLibraryHeading extends StatelessWidget {
  const ConceptLibraryHeading({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = context.select<SettingsBloc, double>(
      (bloc) => bloc.state.appearance.libraryScale,
    );
    return SectionHeading(
      label: L.of(context).conceptLibraryLabel,
      semanticsLabel: L.of(context).library,
      padding: EvaporateLayout.inset(
        top: EvaporateSpacing.card,
        bottom: EvaporateSpacing.gap,
      ),
      trailing: ScaleControl(
        key: const ValueKey('library-scale'),
        label: L.of(context).coverScale,
        value: scale,
        min: Appearance.minLibraryScale,
        max: Appearance.maxLibraryScale,
        step: 0.25,
        onChanged: (value) => context.read<SettingsBloc>().add(
          SettingsPatched(
            (current) =>
                current.withAppearance((a) => a.copyWith(libraryScale: value)),
          ),
        ),
      ),
    );
  }
}

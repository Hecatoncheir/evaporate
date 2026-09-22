import 'package:flutter/material.dart';

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
/// орган управления, который видно вместе с тем, на что он влияет.
class ConceptLibraryHeading extends StatelessWidget {
  const ConceptLibraryHeading({
    super.key,
    required this.scale,
    required this.onScale,
  });

  final double scale;
  final ValueChanged<double> onScale;

  @override
  Widget build(BuildContext context) => SectionHeading(
    label: L.of(context).conceptLibraryLabel,
    semanticsLabel: L.of(context).library,
    padding: EvaporateLayout.inset(top: 18, bottom: 8),
    trailing: ScaleControl(
      key: const ValueKey('library-scale'),
      label: L.of(context).coverScale,
      value: scale,
      min: Appearance.minLibraryScale,
      max: Appearance.maxLibraryScale,
      step: 0.25,
      onChanged: onScale,
    ),
  );
}

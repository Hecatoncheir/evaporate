import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../widgets/scale_control.dart';
import '../theme.dart';

import '../../l10n/app_localizations.dart';

class ConceptLibraryHeading extends StatelessWidget {
  const ConceptLibraryHeading({
    super.key,
    required this.compact,
    required this.scale,
    required this.onScale,
  });

  final bool compact;
  final double scale;
  final ValueChanged<double> onScale;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(28, compact ? 18 : 24, 28, compact ? 4 : 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L.of(context).conceptLibraryLabel,
                style: TextStyle(
                  color: context.colors.primary,
                  fontFamily: EvaporateTheme.monoFontFamily,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                compact
                    ? L.of(context).conceptLibraryHeadlineCompact
                    : L.of(context).conceptLibraryHeadline,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                // Широкому шрифту нужен не минус, а почти ноль: с плотным
                // разрядом заглавные слипаются, а строка перестаёт влезать.
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontFamily: EvaporateTheme.displayFontFamily,
                  fontSize: compact ? 22 : 32,
                  height: 1.04,
                  fontWeight: FontWeight.w800,
                  letterSpacing: compact ? -0.2 : -0.4,
                ),
              ),
            ],
          ),
        ),
        if (compact) ...[
          const SizedBox(width: 16),
          ScaleControl(
            key: const ValueKey('library-scale'),
            label: L.of(context).coverScale,
            value: scale,
            min: AppSettings.minLibraryScale,
            max: AppSettings.maxLibraryScale,
            step: 0.25,
            onChanged: onScale,
          ),
        ],
        if (!compact) ...[
          const SizedBox(width: 32),
          Container(
            width: 310,
            padding: const EdgeInsets.only(left: 22),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: context.colors.outline.withValues(alpha: 0.48),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L.of(context).conceptLibraryDescription,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                ScaleControl(
                  key: const ValueKey('library-scale'),
                  label: L.of(context).coverScale,
                  value: scale,
                  min: AppSettings.minLibraryScale,
                  max: AppSettings.maxLibraryScale,
                  step: 0.25,
                  onChanged: onScale,
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

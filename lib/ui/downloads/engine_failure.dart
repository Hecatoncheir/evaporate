import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// Отказ движка загрузок во всю ширину под показаниями: причина, если
/// движок её назвал, иначе — что он остановлен.
class EngineFailure extends StatelessWidget {
  const EngineFailure({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.danger.withValues(alpha: EvaporateAlpha.subtle),
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
        border: Border.all(
          color: context.colors.danger.withValues(alpha: EvaporateAlpha.rim),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: context.colors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message ?? L.of(context).engineStopped,
              style: context.text.body.copyWith(color: context.colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

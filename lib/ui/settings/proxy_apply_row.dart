import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/proxy_settings.dart';
import '../theme.dart';

/// Клавиша «Применить» и собранный адрес рядом с ней.
///
/// Адрес — набранный, а не сохранённый: человек сверяет то, что применит.
class ProxyApplyRow extends StatelessWidget {
  const ProxyApplyRow({
    super.key,
    required this.draft,
    required this.canApply,
    required this.onApply,
  });

  final ProxySettings draft;
  final bool canApply;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      children: [
        FilledButton(
          onPressed: canApply ? onApply : null,
          child: Text(l.proxyApply),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            draft.isUsable ? draft.uri : l.proxyNoAddress,
            style: context.text.path,
          ),
        ),
      ],
    );
  }
}

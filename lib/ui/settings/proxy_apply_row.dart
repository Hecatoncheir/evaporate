import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/proxy_settings.dart';
import '../theme.dart';

/// Клавиша «Применить» и собранный адрес рядом с ней.
class ProxyApplyRow extends StatelessWidget {
  const ProxyApplyRow({super.key, required this.proxy, required this.onApply});

  final ProxySettings proxy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      children: [
        FilledButton(
          onPressed: proxy.enabled ? onApply : null,
          child: Text(l.proxyApply),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            proxy.isUsable ? proxy.uri : l.proxyNoAddress,
            style: context.text.path,
          ),
        ),
      ],
    );
  }
}

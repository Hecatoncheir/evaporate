import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/proxy_settings.dart';
import '../theme.dart';

/// SOCKS5 или HTTP. Погашен, пока прокси выключен.
class ProxyKindPicker extends StatelessWidget {
  const ProxyKindPicker({
    super.key,
    required this.proxy,
    required this.onChanged,
  });

  final ProxySettings proxy;
  final ValueChanged<ProxySettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: EvaporateLayout.settingLabelWidth,
          child: Text(L.of(context).proxyKind, style: context.text.body),
        ),
        SegmentedButton<ProxyKind>(
          segments: const [
            ButtonSegment(value: ProxyKind.socks5, label: Text('SOCKS5')),
            ButtonSegment(value: ProxyKind.http, label: Text('HTTP')),
          ],
          selected: {proxy.kind},
          onSelectionChanged: proxy.enabled
              ? (value) => onChanged(proxy.copyWith(kind: value.first))
              : null,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/proxy_settings.dart';
import '../widgets/inline_warning.dart';
import 'setting_note.dart';
import 'setting_switch.dart';

/// Что о прокси стоит знать: Steam мимо него, чего не умеет HTTP и где
/// лежит пароль.
class ProxyNotes extends StatelessWidget {
  const ProxyNotes({super.key, required this.proxy, required this.onChanged});

  final ProxySettings proxy;
  final ValueChanged<ProxySettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        SettingSwitch(
          value: proxy.useForSteam,
          onChanged: proxy.enabled
              ? (value) => onChanged(proxy.copyWith(useForSteam: value))
              : null,
          title: l.proxyForSteam,
          note: l.proxyForSteamNote,
        ),
        const SizedBox(height: 6),
        // HTTP-прокси не умеет обмен с пирами — про это предупреждают,
        // а не молчат: иначе загрузка через него просто не поедет.
        if (proxy.kind == ProxyKind.http)
          InlineWarning(l.proxyHttpNote)
        else
          SettingNote(l.proxySocksNote),
        const SizedBox(height: 6),
        InlineWarning(l.proxyPasswordWarning),
      ],
    );
  }
}

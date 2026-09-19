import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/proxy_settings.dart';
import '../feedback/snack.dart';
import '../widgets/inline_warning.dart';
import '../widgets/section_card.dart';
import 'proxy_address_fields.dart';
import 'proxy_apply_row.dart';
import 'proxy_kind_picker.dart';
import 'setting_note.dart';
import 'setting_switch.dart';

/// Раздел «Прокси» для движка загрузок.
class ProxySettingsCard extends StatefulWidget {
  const ProxySettingsCard({super.key});

  @override
  State<ProxySettingsCard> createState() => _ProxySettingsCardState();
}

class _ProxySettingsCardState extends State<ProxySettingsCard> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _password;

  @override
  void initState() {
    super.initState();
    final proxy = context.read<SettingsBloc>().state.proxy;
    _host = TextEditingController(text: proxy.host);
    _port = TextEditingController(text: '${proxy.port}');
    _user = TextEditingController(text: proxy.username);
    _password = TextEditingController(text: proxy.password);
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Настройки применяются кнопкой, а не по каждому символу: смена прокси
  /// перезапускает активные задачи.
  void _apply(ProxySettings current) {
    final store = context.read<SettingsBloc>();
    final next = current.copyWith(
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? current.port,
      username: _user.text.trim(),
      password: _password.text,
    );
    store.add(SettingsChanged(store.state.copyWith(proxy: next)));
    showInfo(context, L.of(context).proxyApplied);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsBloc>();
    final proxy = store.state.proxy;
    final l = L.of(context);

    void update(ProxySettings next) {
      store.add(SettingsChanged(store.state.copyWith(proxy: next)));
    }

    return SectionCard(
      title: l.proxy,
      icon: Icons.vpn_lock_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingSwitch(
            value: proxy.enabled,
            onChanged: (value) => update(proxy.copyWith(enabled: value)),
            title: l.proxyEnable,
          ),
          const SizedBox(height: 8),
          ProxyKindPicker(proxy: proxy, onChanged: update),
          const SizedBox(height: 12),
          ProxyAddressFields(
            host: _host,
            port: _port,
            user: _user,
            password: _password,
            enabled: proxy.enabled,
          ),
          const SizedBox(height: 10),
          ProxyApplyRow(proxy: proxy, onApply: () => _apply(proxy)),
          const SizedBox(height: 6),
          SettingSwitch(
            value: proxy.useForSteam,
            onChanged: proxy.enabled
                ? (value) => update(proxy.copyWith(useForSteam: value))
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
      ),
    );
  }
}

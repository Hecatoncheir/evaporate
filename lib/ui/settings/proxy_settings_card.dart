import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../models/proxy_settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../../l10n/app_localizations.dart';

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

    void update(ProxySettings next) {
      store.add(SettingsChanged(store.state.copyWith(proxy: next)));
    }

    return SectionCard(
      title: L.of(context).proxy,
      icon: Icons.vpn_lock_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: proxy.enabled,
            onChanged: (value) => update(proxy.copyWith(enabled: value)),
            contentPadding: EdgeInsets.zero,
            title: Text(
              L.of(context).proxyEnable,
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 220,
                child: Text(
                  L.of(context).proxyKind,
                  style: TextStyle(fontSize: 13),
                ),
              ),
              SegmentedButton<ProxyKind>(
                segments: const [
                  ButtonSegment(value: ProxyKind.socks5, label: Text('SOCKS5')),
                  ButtonSegment(value: ProxyKind.http, label: Text('HTTP')),
                ],
                selected: {proxy.kind},
                onSelectionChanged: proxy.enabled
                    ? (value) => update(proxy.copyWith(kind: value.first))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Field(
            label: L.of(context).proxyHost,
            controller: _host,
            enabled: proxy.enabled,
          ),
          _Field(
            label: L.of(context).proxyPort,
            controller: _port,
            enabled: proxy.enabled,
            numeric: true,
          ),
          _Field(
            label: L.of(context).proxyUser,
            controller: _user,
            enabled: proxy.enabled,
          ),
          _Field(
            label: L.of(context).proxyPassword,
            controller: _password,
            enabled: proxy.enabled,
            obscure: true,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: proxy.enabled ? () => _apply(proxy) : null,
                child: Text(L.of(context).proxyApply),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  proxy.isUsable ? proxy.uri : L.of(context).proxyNoAddress,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: EvaporateTheme.monoFontFamily,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            value: proxy.useForSteam,
            onChanged: proxy.enabled
                ? (value) => update(proxy.copyWith(useForSteam: value))
                : null,
            contentPadding: EdgeInsets.zero,
            title: Text(
              L.of(context).proxyForSteam,
              style: TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              L.of(context).proxyForSteamNote,
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 6),
          if (proxy.kind == ProxyKind.http)
            _Warning(L.of(context).proxyHttpNote)
          else
            _Note(L.of(context).proxySocksNote),
          const SizedBox(height: 6),
          _Warning(L.of(context).proxyPasswordWarning),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.enabled,
    this.numeric = false,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool numeric;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: controller,
              enabled: enabled,
              obscureText: obscure,
              keyboardType: numeric ? TextInputType.number : null,
              inputFormatters: numeric
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: 15,
          color: context.colors.warning,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: context.colors.warning,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: context.colors.textSecondary,
        height: 1.4,
      ),
    );
  }
}

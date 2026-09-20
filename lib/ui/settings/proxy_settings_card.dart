import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/proxy_form/proxy_form_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/proxy_settings.dart';
import '../widgets/section_card.dart';
import 'proxy_form_body.dart';

/// Раздел «Прокси» для движка загрузок.
///
/// Набранное держит `ProxyFormBloc`: строка рядом с клавишей показывает то,
/// что применят, а не то, что сохранено, и неверный порт гасит клавишу
/// вместо того, чтобы молча подменяться прежним.
class ProxySettingsCard extends StatefulWidget {
  const ProxySettingsCard({super.key});

  @override
  State<ProxySettingsCard> createState() => _ProxySettingsCardState();
}

class _ProxySettingsCardState extends State<ProxySettingsCard> {
  late final ProxySettings _saved = context.read<SettingsBloc>().state.proxy;
  late final _host = TextEditingController(text: _saved.host);
  late final _port = TextEditingController(text: '${_saved.port}');
  late final _user = TextEditingController(text: _saved.username);
  late final _password = TextEditingController(text: _saved.password);

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProxyFormBloc(_saved),
      child: SectionCard(
        title: L.of(context).proxy,
        icon: Icons.vpn_lock_outlined,
        child: ProxyFormBody(
          host: _host,
          port: _port,
          user: _user,
          password: _password,
        ),
      ),
    );
  }
}

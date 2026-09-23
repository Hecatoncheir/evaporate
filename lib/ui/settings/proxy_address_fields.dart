import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/proxy_form/proxy_form_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import 'setting_text_field.dart';

/// Адрес, порт и учётные данные прокси.
///
/// Поля правятся руками и уходят в настройки по «Применить», а не на
/// каждый знак: на полпути набранный адрес — не адрес. Набранное держит
/// блок формы — строка рядом с клавишей показывает то, что применят, — а
/// контроллеры текста поля заводят сами, с того же набранного.
///
/// Блок формы поля читают и правят сами: прежде карточка передавала сюда
/// десять параметров и превращала события блока в колбэки — ни один из них
/// ей самой не был нужен. Контроллеры она заводила тоже и везла их сюда
/// через тело формы, которое их не трогало.
class ProxyAddressFields extends StatefulWidget {
  const ProxyAddressFields({super.key});

  @override
  State<ProxyAddressFields> createState() => _ProxyAddressFieldsState();
}

class _ProxyAddressFieldsState extends State<ProxyAddressFields> {
  late final ProxyForm _typed = context.read<ProxyFormBloc>().state;
  late final _host = TextEditingController(text: _typed.host);
  late final _port = TextEditingController(text: _typed.port);
  late final _user = TextEditingController(text: _typed.user);
  late final _password = TextEditingController(text: _typed.password);

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
    final l = L.of(context);
    final form = context.read<ProxyFormBloc>();
    final enabled = context.select<SettingsBloc, bool>(
      (bloc) => bloc.state.proxy.enabled,
    );
    final portInvalid = context.select<ProxyFormBloc, bool>(
      (bloc) => bloc.state.portInvalid,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingTextField(
          label: l.proxyHost,
          controller: _host,
          enabled: enabled,
          onChanged: (value) => form.add(ProxyHostChanged(value)),
        ),
        SettingTextField(
          label: l.proxyPort,
          controller: _port,
          enabled: enabled,
          numeric: true,
          onChanged: (value) => form.add(ProxyPortChanged(value)),
          errorText: portInvalid ? l.proxyPortInvalid : null,
        ),
        SettingTextField(
          label: l.proxyUser,
          controller: _user,
          enabled: enabled,
          onChanged: (value) => form.add(ProxyUserChanged(value)),
        ),
        SettingTextField(
          label: l.proxyPassword,
          controller: _password,
          enabled: enabled,
          obscure: true,
          onChanged: (value) => form.add(ProxyPasswordChanged(value)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/proxy_form/proxy_form_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import 'setting_text_field.dart';

/// Адрес, порт и учётные данные прокси.
///
/// Поля правятся руками и уходят в настройки по «Применить», а не на
/// каждый знак: на полпути набранный адрес — не адрес. Контроллеры при
/// этом держит карточка, а набранное — блок формы: строка рядом с клавишей
/// показывает то, что применят.
///
/// Блок формы поля читают и правят сами: прежде карточка передавала сюда
/// десять параметров и превращала события блока в колбэки — ни один из них
/// ей самой не был нужен.
class ProxyAddressFields extends StatelessWidget {
  const ProxyAddressFields({
    super.key,
    required this.host,
    required this.port,
    required this.user,
    required this.password,
  });

  final TextEditingController host;
  final TextEditingController port;
  final TextEditingController user;
  final TextEditingController password;

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
          controller: host,
          enabled: enabled,
          onChanged: (value) => form.add(ProxyHostChanged(value)),
        ),
        SettingTextField(
          label: l.proxyPort,
          controller: port,
          enabled: enabled,
          numeric: true,
          onChanged: (value) => form.add(ProxyPortChanged(value)),
          errorText: portInvalid ? l.proxyPortInvalid : null,
        ),
        SettingTextField(
          label: l.proxyUser,
          controller: user,
          enabled: enabled,
          onChanged: (value) => form.add(ProxyUserChanged(value)),
        ),
        SettingTextField(
          label: l.proxyPassword,
          controller: password,
          enabled: enabled,
          obscure: true,
          onChanged: (value) => form.add(ProxyPasswordChanged(value)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'setting_text_field.dart';

/// Адрес, порт и учётные данные прокси.
///
/// Поля правятся руками и уходят в настройки по «Применить», а не на
/// каждый знак: на полпути набранный адрес — не адрес. Поэтому контроллеры
/// держит карточка, а не эти поля.
class ProxyAddressFields extends StatelessWidget {
  const ProxyAddressFields({
    super.key,
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    required this.enabled,
  });

  final TextEditingController host;
  final TextEditingController port;
  final TextEditingController user;
  final TextEditingController password;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingTextField(
          label: l.proxyHost,
          controller: host,
          enabled: enabled,
        ),
        SettingTextField(
          label: l.proxyPort,
          controller: port,
          enabled: enabled,
          numeric: true,
        ),
        SettingTextField(
          label: l.proxyUser,
          controller: user,
          enabled: enabled,
        ),
        SettingTextField(
          label: l.proxyPassword,
          controller: password,
          enabled: enabled,
          obscure: true,
        ),
      ],
    );
  }
}

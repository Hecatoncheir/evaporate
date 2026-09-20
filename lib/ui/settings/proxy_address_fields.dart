import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'setting_text_field.dart';

/// Адрес, порт и учётные данные прокси.
///
/// Поля правятся руками и уходят в настройки по «Применить», а не на
/// каждый знак: на полпути набранный адрес — не адрес. Контроллеры при
/// этом держит карточка, а набранное — блок формы: строка рядом с клавишей
/// показывает то, что применят.
class ProxyAddressFields extends StatelessWidget {
  const ProxyAddressFields({
    super.key,
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    required this.enabled,
    required this.portError,
    required this.onHost,
    required this.onPort,
    required this.onUser,
    required this.onPassword,
  });

  final TextEditingController host;
  final TextEditingController port;
  final TextEditingController user;
  final TextEditingController password;
  final bool enabled;

  /// Почему порт не годится; `null` — годится.
  final String? portError;

  final ValueChanged<String> onHost;
  final ValueChanged<String> onPort;
  final ValueChanged<String> onUser;
  final ValueChanged<String> onPassword;

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
          onChanged: onHost,
        ),
        SettingTextField(
          label: l.proxyPort,
          controller: port,
          enabled: enabled,
          numeric: true,
          onChanged: onPort,
          errorText: portError,
        ),
        SettingTextField(
          label: l.proxyUser,
          controller: user,
          enabled: enabled,
          onChanged: onUser,
        ),
        SettingTextField(
          label: l.proxyPassword,
          controller: password,
          enabled: enabled,
          obscure: true,
          onChanged: onPassword,
        ),
      ],
    );
  }
}

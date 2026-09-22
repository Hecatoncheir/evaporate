import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/proxy_form/proxy_form_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/proxy_settings.dart';
import 'proxy_address_fields.dart';
import 'proxy_apply_row.dart';
import 'proxy_kind_picker.dart';
import 'proxy_notes.dart';
import 'setting_switch.dart';

/// Содержимое карточки «Прокси».
class ProxyFormBody extends StatelessWidget {
  const ProxyFormBody({
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

  /// Переключатели уходят в настройки сразу: они не про адрес, и
  /// собирать их нечего.
  void _update(BuildContext context, ProxySettings next) {
    final store = context.read<SettingsBloc>();
    store.add(SettingsPatched((current) => current.copyWith(proxy: next)));
    context.read<ProxyFormBloc>().add(ProxySavedChanged(next));
  }

  /// Набранное уходит в настройки по клавише: смена прокси перезапускает
  /// активные задачи, и делать это на каждый знак нельзя.
  void _apply(BuildContext context, ProxyForm form) {
    final store = context.read<SettingsBloc>();
    final next = form.draft;
    store.add(SettingsPatched((current) => current.copyWith(proxy: next)));
    context.read<ProxyFormBloc>().add(ProxySavedChanged(next));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final saved = context.select<SettingsBloc, ProxySettings>(
      (bloc) => bloc.state.proxy,
    );

    return BlocBuilder<ProxyFormBloc, ProxyForm>(
      builder: (context, form) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingSwitch(
            value: saved.enabled,
            onChanged: (value) =>
                _update(context, saved.copyWith(enabled: value)),
            title: l.proxyEnable,
          ),
          const SizedBox(height: 8),
          ProxyKindPicker(
            proxy: saved,
            onChanged: (next) => _update(context, next),
          ),
          const SizedBox(height: 12),
          ProxyAddressFields(
            host: host,
            port: port,
            user: user,
            password: password,
          ),
          const SizedBox(height: 10),
          ProxyApplyRow(
            draft: form.draft,
            canApply: form.canApply,
            onApply: () => _apply(context, form),
          ),
          ProxyNotes(proxy: saved, onChanged: (next) => _update(context, next)),
        ],
      ),
    );
  }
}

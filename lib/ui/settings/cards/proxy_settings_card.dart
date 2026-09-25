import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/proxy_form/proxy_form_bloc.dart';
import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/section_card.dart';
import '../proxy_form_body.dart';

/// Раздел «Прокси» для движка загрузок.
///
/// Набранное держит `ProxyFormBloc`: строка рядом с клавишей показывает то,
/// что применят, а не то, что сохранено, и неверный порт гасит клавишу
/// вместо того, чтобы молча подменяться прежним.
class ProxySettingsCard extends StatelessWidget {
  const ProxySettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProxyFormBloc(context.read<SettingsBloc>().state.proxy),
      child: SectionCard(
        title: L.of(context).proxy,
        icon: Icons.vpn_lock_outlined,
        child: const ProxyFormBody(),
      ),
    );
  }
}

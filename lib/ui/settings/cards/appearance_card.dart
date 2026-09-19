import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/app_settings.dart';
import '../../theme.dart';
import '../../widgets/scale_control.dart';
import '../../widgets/section_card.dart';
import '../language_picker.dart';
import '../setting_note.dart';
import '../theme_picker.dart';

/// Язык, тема и крупность интерфейса.
///
/// Всё это лежало в карточке «Сохранения» — не по вкусовщине, а по ошибке
/// раскладки: искать язык в сохранениях никто не станет. Теперь вид
/// отдельно, окно и запуск отдельно, сохранения — про сохранения.
class AppearanceCard extends StatelessWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<SettingsBloc>();
    final settings = store.state;
    void update(AppSettings next) => store.add(SettingsChanged(next));

    return SectionCard(
      title: l.appearanceAndLanguage,
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LanguagePicker(
            value: settings.locale,
            onChanged: (code) => update(settings.copyWith(locale: code)),
          ),
          const SizedBox(height: 12),
          ThemePicker(
            value: settings.themeMode,
            onChanged: (mode) => update(settings.copyWith(themeMode: mode)),
          ),
          const SizedBox(height: 14),
          // Крупность обложек отсюда убрана: она стоит в самой библиотеке,
          // рядом с тем, на что влияет. Два ползунка с одинаковой подписью
          // в двух местах — это выбор, какой из них настоящий.
          Wrap(
            spacing: 20,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: EvaporateLayout.settingLabelWidth,
                child: Text(l.interfaceScale, style: context.text.body),
              ),
              ScaleControl(
                key: const ValueKey('interface-scale'),
                label: l.interfaceScale,
                value: settings.interfaceScale,
                min: AppSettings.minInterfaceScale,
                max: AppSettings.maxInterfaceScale,
                step: 0.05,
                onChanged: (value) =>
                    update(settings.copyWith(interfaceScale: value)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SettingNote(l.interfaceScaleNote),
        ],
      ),
    );
  }
}

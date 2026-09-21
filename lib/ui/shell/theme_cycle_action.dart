import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_theme_mode.dart';
import 'top_action.dart';

/// Клавиша смены оформления в верхней рейке.
///
/// Перебирает все три состояния, а не два: прежде она переключала тёмное
/// со светлым и молча съедала «как в системе» — вернуть его можно было
/// только в настройках, куда за этим никто не идёт.
class ThemeCycleAction extends StatelessWidget {
  const ThemeCycleAction({super.key});

  /// Порядок перебора: из системного — в светлое, дальше в тёмное и назад
  /// в системное. Подпись на клавише обещает то, что получится после
  /// нажатия.
  static AppThemeMode nextTheme(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => AppThemeMode.light,
    AppThemeMode.light => AppThemeMode.dark,
    AppThemeMode.dark => AppThemeMode.system,
  };

  static IconData _icon(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => Icons.brightness_auto_outlined,
    AppThemeMode.light => Icons.light_mode_outlined,
    AppThemeMode.dark => Icons.dark_mode_outlined,
  };

  static String _label(BuildContext context, AppThemeMode mode) =>
      switch (mode) {
        AppThemeMode.system => L.of(context).systemThemeAction,
        AppThemeMode.light => L.of(context).lightThemeAction,
        AppThemeMode.dark => L.of(context).darkThemeAction,
      };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsBloc>();
    final settings = store.state;
    final mode = settings.themeMode;
    return TopAction(
      tooltip: _label(context, nextTheme(mode)),
      icon: _icon(mode),
      onPressed: () => store.add(
        SettingsPatched(
          (current) => current.copyWith(themeMode: nextTheme(mode)),
        ),
      ),
    );
  }
}

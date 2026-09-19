import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../models/app_settings.dart';

/// Спрашивает папку и кладёт её в настройки правкой, а не снимком: пока
/// открыт системный диалог, настройки могли поменяться, и снимок, взятый
/// до него, затёр бы это.
Future<void> pickSettingsFolder(
  BuildContext context,
  AppSettings Function(AppSettings current, String dir) apply,
) async {
  final store = context.read<SettingsBloc>();
  final dir = await getDirectoryPath();
  if (dir == null) return;
  store.add(SettingsPatched((s) => apply(s, dir)));
}

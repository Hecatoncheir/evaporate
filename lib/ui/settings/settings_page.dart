import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../models/app_settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'gamepad_settings.dart';
import 'notification_settings.dart';
import 'proxy_settings_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsBloc>();
    final downloads = context.watch<DownloadsBloc>();
    final settings = store.state;

    void update(AppSettings next, {bool restartEngine = false}) {
      store.add(SettingsChanged(next));
      if (restartEngine) downloads.add(const DownloadSettingsApplied());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      children: [
        const Text(
          'Настройки',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        const GamepadSettingsCard(),
        const NotificationSettingsCard(),
        SectionCard(
          title: 'Загрузки',
          icon: Icons.download_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PathSetting(
                label: 'Папка для игр',
                value: settings.installDir,
                onPick: () async {
                  final dir = await getDirectoryPath();
                  if (dir == null) return;
                  update(
                    settings.copyWith(installDir: dir),
                    restartEngine: true,
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 220,
                    child: Text(
                      'Одновременных загрузок',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  DropdownButton<int>(
                    value: settings.maxConcurrent,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final value in [1, 2, 3, 5, 8])
                        DropdownMenuItem(value: value, child: Text('$value')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      update(
                        settings.copyWith(maxConcurrent: value),
                        restartEngine: true,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Движок загрузок',
          icon: Icons.settings_ethernet,
          trailing: OutlinedButton.icon(
            onPressed: () =>
                downloads.add(const DownloadEngineRestartRequested()),
            icon: const Icon(Icons.restart_alt, size: 16),
            label: const Text('Перезапустить'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(
                label: 'Состояние',
                value:
                    downloads.state.engine.message ??
                    downloads.state.engine.label,
                valueColor: downloads.state.engine.isReady
                    ? EvaporateTheme.accent
                    : EvaporateTheme.warning,
              ),
              const InfoRow(
                label: 'Реализация',
                value: 'Встроенный клиент на Dart',
              ),
              const SizedBox(height: 8),
              const Text(
                'Движок встроен в приложение — внешних программ ставить не '
                'нужно. Список загрузок переживает перезапуск.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: EvaporateTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const ProxySettingsCard(),
        SectionCard(
          title: 'Сохранения',
          icon: Icons.save_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PathSetting(
                label: 'Папка синхронизации',
                value: settings.syncFolder ?? 'не задана',
                onPick: () async {
                  final dir = await getDirectoryPath();
                  if (dir == null) return;
                  update(settings.copyWith(syncFolder: dir));
                },
                onClear: settings.syncFolder == null
                    ? null
                    : () => update(settings.copyWith(syncFolder: null)),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                value: settings.autoExportToSync,
                onChanged: (value) =>
                    update(settings.copyWith(autoExportToSync: value)),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Копировать новые снимки в папку синхронизации',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 6),
              _PathSetting(
                label: 'Ludusavi (необязательно)',
                value: settings.ludusaviPath ?? 'искать самим',
                onPick: () async {
                  final file = await openFile();
                  if (file == null) return;
                  update(settings.copyWith(ludusaviPath: file.path));
                },
                onClear: settings.ludusaviPath == null
                    ? null
                    : () => update(settings.copyWith(ludusaviPath: null)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Пути сохранений берутся у Ludusavi — он идёт в комплекте, '
                'ставить отдельно ничего не нужно. Здесь можно указать свою '
                'копию: её настройки могут знать про нестандартные папки с '
                'играми. Если Ludusavi недоступен, работает встроенная база '
                'путей — она покрывает меньше случаев, но не требует ничего.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: EvaporateTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                value: settings.rememberWindowSize,
                onChanged: (value) =>
                    update(settings.copyWith(rememberWindowSize: value)),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Открывать окно там же, где закрыли',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              SwitchListTile(
                value: settings.startMaximized,
                onChanged: (value) =>
                    update(settings.copyWith(startMaximized: value)),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Всегда разворачивать при запуске',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Перекрывает запомненный размер',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              SwitchListTile(
                value: settings.launchAtStartup,
                onChanged: (value) =>
                    update(settings.copyWith(launchAtStartup: value)),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Запускать вместе с системой',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Загрузки продолжатся сразу после входа',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              SwitchListTile(
                value: settings.autoSnapshotOnExit,
                onChanged: (value) =>
                    update(settings.copyWith(autoSnapshotOnExit: value)),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Снимать сохранения после выхода из игры',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Значение по умолчанию для новых игр',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PathSetting extends StatelessWidget {
  const _PathSetting({
    required this.label,
    required this.value,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 220,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontFamily: EvaporateTheme.monoFontFamily,
              color: EvaporateTheme.textSecondary,
            ),
          ),
        ),
        TextButton(onPressed: onPick, child: const Text('Изменить')),
        if (onClear != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Очистить',
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

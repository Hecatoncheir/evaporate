import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_settings.dart';
import '../../models/window_start_mode.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_card.dart';
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
              const SizedBox(height: 14),
              _SpeedField(
                label: 'Ограничение приёма',
                value: settings.limits.download,
                onChanged: (value) => update(
                  settings.copyWith(
                    limits: settings.limits.copyWith(download: value),
                  ),
                ),
              ),
              _SpeedField(
                label: 'Ограничение раздачи',
                value: settings.limits.upload,
                hint:
                    'Раздача — плата за скачанное, совсем перекрывать не стоит',
                onChanged: (value) => update(
                  settings.copyWith(
                    limits: settings.limits.copyWith(upload: value),
                  ),
                ),
              ),
              _SpeedField(
                label: 'Приём, пока идёт игра',
                value: settings.limits.whilePlaying,
                hint: 'Качая на полную, легко испортить себе же отклик в игре',
                onChanged: (value) => update(
                  settings.copyWith(
                    limits: settings.limits.copyWith(whilePlaying: value),
                  ),
                ),
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
                    ? context.colors.accent
                    : context.colors.warning,
              ),
              const InfoRow(
                label: 'Реализация',
                value: 'Встроенный клиент на Dart',
              ),
              const SizedBox(height: 8),
              Text(
                'Движок встроен в приложение — внешних программ ставить не '
                'нужно. Список загрузок переживает перезапуск.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.colors.textSecondary,
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
              Text(
                'Пути сохранений берутся у Ludusavi — он идёт в комплекте, '
                'ставить отдельно ничего не нужно. Здесь можно указать свою '
                'копию: её настройки могут знать про нестандартные папки с '
                'играми. Если Ludusavi недоступен, работает встроенная база '
                'путей — она покрывает меньше случаев, но не требует ничего.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.colors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              _LanguagePicker(
                value: settings.locale,
                onChanged: (code) => update(settings.copyWith(locale: code)),
              ),
              const SizedBox(height: 10),
              _ThemePicker(
                value: settings.themeMode,
                onChanged: (mode) => update(settings.copyWith(themeMode: mode)),
              ),
              const SizedBox(height: 10),
              _WindowStartPicker(
                value: settings.windowStart,
                onChanged: (mode) =>
                    update(settings.copyWith(windowStart: mode)),
              ),
              const SizedBox(height: 10),
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
        const AboutCard(),
      ],
    );
  }
}

/// Выбор оформления.
///
/// Три кнопки, а не переключатель: «как в системе» — не середина между
/// светлой и тёмной, а отдельный вариант, и выпадающим списком его пришлось
/// бы искать.
/// Поле скорости в килобайтах в секунду. Пустое значение и ноль означают
/// «без ограничения» — так понятнее, чем отдельная галочка рядом с числом.
class _SpeedField extends StatefulWidget {
  const _SpeedField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final int value;
  final String? hint;
  final ValueChanged<int> onChanged;

  @override
  State<_SpeedField> createState() => _SpeedFieldState();
}

class _SpeedFieldState extends State<_SpeedField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value > 0 ? '${widget.value}' : '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final parsed = int.tryParse(raw.trim()) ?? 0;
    widget.onChanged(parsed > 0 ? parsed : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(widget.label, style: const TextStyle(fontSize: 13)),
            ),
          ),
          SizedBox(
            width: 130,
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'без огр.',
                suffixText: 'КБ/с',
              ),
              onSubmitted: _submit,
              onTapOutside: (_) => _submit(_controller.text),
            ),
          ),
          if (widget.hint != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 12),
                child: Text(
                  widget.hint!,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Выбор языка интерфейса.
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.value, required this.onChanged});

  /// null — брать язык системы.
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      children: [
        SizedBox(
          width: 220,
          child: Text(l.language, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: '', label: Text(l.languageSystem)),
              ButtonSegment(value: 'ru', label: Text(l.languageRussian)),
              ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
            ],
            selected: {value ?? ''},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              final code = selection.first;
              onChanged(code.isEmpty ? null : code);
            },
            style: const ButtonStyle(
              textStyle: WidgetStatePropertyAll(
                TextStyle(
                  fontSize: 12.5,
                  fontFamily: EvaporateTheme.fontFamily,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Каким открывать окно при запуске.
class _WindowStartPicker extends StatelessWidget {
  const _WindowStartPicker({required this.value, required this.onChanged});

  final WindowStartMode value;
  final ValueChanged<WindowStartMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 220,
          child: Text('Окно при запуске', style: TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: SegmentedButton<WindowStartMode>(
            segments: const [
              ButtonSegment(
                value: WindowStartMode.remembered,
                icon: Icon(Icons.crop_din, size: 17),
                label: Text('Как закрыли'),
              ),
              ButtonSegment(
                value: WindowStartMode.maximized,
                icon: Icon(Icons.fullscreen, size: 17),
                label: Text('Развёрнутым'),
              ),
              ButtonSegment(
                value: WindowStartMode.minimized,
                icon: Icon(Icons.expand_more, size: 17),
                label: Text('В трей'),
              ),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
            style: const ButtonStyle(
              textStyle: WidgetStatePropertyAll(
                TextStyle(
                  fontSize: 12.5,
                  fontFamily: EvaporateTheme.fontFamily,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 220,
          child: Text('Оформление', style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined, size: 17),
                label: Text('Как в системе'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined, size: 17),
                label: Text('Светлое'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined, size: 17),
                label: Text('Тёмное'),
              ),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
            style: ButtonStyle(
              textStyle: WidgetStatePropertyAll(
                TextStyle(
                  fontSize: 12.5,
                  fontFamily: EvaporateTheme.fontFamily,
                ),
              ),
            ),
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
            style: TextStyle(
              fontSize: 12.5,
              fontFamily: EvaporateTheme.monoFontFamily,
              color: context.colors.textSecondary,
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

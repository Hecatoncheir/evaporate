import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_settings.dart';
import '../../models/window_start_mode.dart';
import '../labels.dart';
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
        Text(
          L.of(context).settings,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        const GamepadSettingsCard(),
        const NotificationSettingsCard(),
        SectionCard(
          title: L.of(context).downloads,
          icon: Icons.download_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PathSetting(
                label: L.of(context).gamesFolder,
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
                  SizedBox(
                    width: 220,
                    child: Text(
                      L.of(context).concurrentDownloads,
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
                label: L.of(context).limitDownload,
                value: settings.limits.download,
                onChanged: (value) => update(
                  settings.copyWith(
                    limits: settings.limits.copyWith(download: value),
                  ),
                ),
              ),
              _SpeedField(
                label: L.of(context).limitUpload,
                value: settings.limits.upload,
                hint: L.of(context).limitUploadNote,
                onChanged: (value) => update(
                  settings.copyWith(
                    limits: settings.limits.copyWith(upload: value),
                  ),
                ),
              ),
              _SpeedField(
                label: L.of(context).seedRatio,
                value: settings.limits.seedRatio,
                unit: L.of(context).seedRatioUnit,
                hint: L.of(context).seedRatioNote,
                onChanged: (value) => update(
                  settings.copyWith(
                    limits: settings.limits.copyWith(seedRatio: value),
                  ),
                ),
              ),
              _SpeedField(
                label: L.of(context).limitWhilePlaying,
                value: settings.limits.whilePlaying,
                hint: L.of(context).limitPlayingNote,
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
          title: L.of(context).downloadEngine,
          icon: Icons.settings_ethernet,
          trailing: OutlinedButton.icon(
            onPressed: () =>
                downloads.add(const DownloadEngineRestartRequested()),
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(L.of(context).restart),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(
                label: L.of(context).engineState,
                value:
                    downloads.state.engine.message ??
                    engineStateLabel(
                      L.of(context),
                      downloads.state.engine.state,
                    ),
                valueColor: downloads.state.engine.isReady
                    ? context.colors.accent
                    : context.colors.warning,
              ),
              InfoRow(
                label: L.of(context).engineImplementation,
                value: L.of(context).engineBuiltIn,
              ),
              const SizedBox(height: 8),
              Text(
                L.of(context).engineNote,
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
          title: L.of(context).saves,
          icon: Icons.save_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PathSetting(
                label: L.of(context).syncFolder,
                value: settings.syncFolder ?? L.of(context).notSet,
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
                title: Text(
                  L.of(context).copyToSyncFolder,
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 6),
              _PathSetting(
                label: L.of(context).ludusaviOptional,
                value:
                    settings.ludusaviPath ??
                    L.of(context).ludusaviFindOurselves,
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
                L.of(context).ludusaviNote,
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
                title: Text(
                  L.of(context).launchAtStartup,
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  L.of(context).launchAtStartupNote,
                  style: TextStyle(fontSize: 12),
                ),
              ),
              SwitchListTile(
                value: settings.autoSnapshotOnExit,
                onChanged: (value) =>
                    update(settings.copyWith(autoSnapshotOnExit: value)),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  L.of(context).snapshotOnExit,
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  L.of(context).defaultForNewGames,
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
    this.unit,
  });

  final String label;
  final int value;
  final String? hint;

  /// Единица измерения. По умолчанию килобайты в секунду —
  /// поле задумывалось для скорости, но порог раздачи считается
  /// в сотых долях.
  final String? unit;
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
              decoration: InputDecoration(
                isDense: true,
                hintText: L.of(context).unlimitedShort,
                suffixText: widget.unit ?? L.of(context).kilobytesPerSecond,
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
        SizedBox(
          width: 220,
          child: Text(
            L.of(context).windowOnStart,
            style: TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: SegmentedButton<WindowStartMode>(
            segments: [
              ButtonSegment(
                value: WindowStartMode.remembered,
                icon: Icon(Icons.crop_din, size: 17),
                label: Text(L.of(context).windowRemembered),
              ),
              ButtonSegment(
                value: WindowStartMode.maximized,
                icon: Icon(Icons.fullscreen, size: 17),
                label: Text(L.of(context).windowMaximized),
              ),
              ButtonSegment(
                value: WindowStartMode.minimized,
                icon: Icon(Icons.expand_more, size: 17),
                label: Text(L.of(context).windowMinimized),
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
          child: Text(
            L.of(context).appearance,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined, size: 17),
                label: Text(L.of(context).themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined, size: 17),
                label: Text(L.of(context).themeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined, size: 17),
                label: Text(L.of(context).themeDark),
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
        TextButton(onPressed: onPick, child: Text(L.of(context).change)),
        if (onClear != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 16),
            tooltip: L.of(context).clear,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

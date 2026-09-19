import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../core/app_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../services/system/desktop_entry.dart';
import '../../services/system/update_check.dart';
import '../../services/system/update_download.dart';
import '../../services/system/update_installer.dart';
import '../theme.dart';
import '../widgets/info_row.dart';
import '../widgets/section_card.dart';
import 'about_actions.dart';
import 'menu_entry_row.dart';
import 'setting_switch.dart';

/// Версия приложения и проверка обновлений.
class AboutCard extends StatefulWidget {
  const AboutCard({super.key, this.check, this.openLink, this.desktop});

  /// Подменяется в тестах: настоящий запрос к GitHub там ни к чему.
  final UpdateCheck? check;

  /// Чем открывать ссылку. Тоже подменяется в тестах: браузер посреди
  /// прогона никому не нужен.
  final Future<bool> Function(Uri uri)? openLink;

  /// Запись в меню приложений. В тестах подменяется на такую, у которой нет
  /// домашней папки: иначе виджет полез бы за настоящим файлом.
  final DesktopEntry? desktop;

  @override
  State<AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<AboutCard> {
  /// Куда ведёт «Исходный код». Отсюда же человек попадает к релизам:
  /// ссылка на них у GitHub своя, и вторую клавишу она не заслуживает.
  static const _repositoryUrl = 'https://github.com/Hecatoncheir/evaporate';

  late final UpdateCheck _check = widget.check ?? UpdateCheck();

  bool _busy = false;
  String? _message;
  bool _isError = false;
  Release? _found;

  @override
  void initState() {
    super.initState();
    _refreshMenuState();
  }

  /// Ссылку показывали текстом, который надо было выделить и скопировать.
  /// Открыть её — единственное, что с ней делают.
  Future<void> _openRelease(String url) async {
    final l = L.of(context);
    final target = Uri.tryParse(url);
    final open =
        widget.openLink ??
        (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    final opened = target != null && await open(target);
    if (opened || !mounted) return;
    setState(() {
      _isError = true;
      _message = l.openLinkFailed(url);
    });
  }

  Future<void> _lookForUpdate() async {
    // До первого await: потом трогать context нельзя.
    final l = L.of(context);
    setState(() {
      _busy = true;
      _message = null;
      _found = null;
    });

    try {
      final release = await _check.latest();
      if (!mounted) return;
      setState(() {
        _found = release;
        _isError = false;
        _message = release == null
            ? l.upToDate
            : l.newVersionOut(release.version);
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message = error.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  late final _desktop = widget.desktop ?? DesktopEntry();
  bool? _inMenu;

  Future<void> _refreshMenuState() async {
    if (!_desktop.isSupported) return;
    final installed = await _desktop.isInstalled();
    if (mounted) setState(() => _inMenu = installed);
  }

  Future<void> _toggleMenuEntry() async {
    final wasIn = _inMenu ?? false;
    try {
      wasIn ? await _desktop.remove() : await _desktop.install();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _isError = true;
          _message = error.toString();
        });
      }
    }
    await _refreshMenuState();
  }

  /// Идёт подготовка обновления.
  bool _updating = false;

  /// Скачивает обновление, проверяет его и запускает замену.
  ///
  /// На Windows дальше работает сам Inno Setup, на macOS и Linux —
  /// POSIX-помощник. Нам остаётся закрыться через тот же путь, что и
  /// обычное закрытие окна, чтобы всё успело лечь на диск.
  Future<void> _install() async {
    final release = _found;
    if (release == null) return;
    final l = L.of(context);

    setState(() {
      _updating = true;
      _isError = false;
      _message = l.updateRestartNote;
    });

    try {
      final paths = AppPaths.instance;
      final installer = UpdateInstaller(workDir: paths.dataDir);
      if (!await installer.canInstall) {
        throw UpdateException(l.updateNotWritable);
      }

      final staged = await UpdateDownload(workDir: paths.dataDir).prepare(
        release,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _message = switch (progress.phase) {
              UpdatePhase.downloading => l.updateDownloading(
                ((progress.fraction ?? 0) * 100).round(),
              ),
              UpdatePhase.verifying => l.updateVerifying,
              UpdatePhase.unpacking => l.updateUnpacking,
              _ => l.updateRestartNote,
            };
          });
        },
      );

      await installer.apply(staged);
      // Дальше нас заменит setup или помощник — уходим тем же путём, что и по
      // закрытию окна: иначе отложенные записи не лягут на диск.
      await windowManager.close();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _updating = false;
        _isError = true;
        _message = error is UpdateException ? error.message : error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsBloc>().state;
    final l = L.of(context);

    return SectionCard(
      title: l.about,
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(label: l.version, value: AppVersion.current),
          const SizedBox(height: 6),
          AboutActions(
            busy: _busy,
            updating: _updating,
            found: _found,
            onCheck: _lookForUpdate,
            onSourceCode: () => _openRelease(_repositoryUrl),
            onInstall: _install,
            onReleasePage: () => _openRelease(_found!.url),
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: context.text.note.copyWith(
                color: _isError
                    ? context.colors.danger
                    : context.colors.textSecondary,
              ),
            ),
          ],
          if (_desktop.isSupported)
            MenuEntryRow(inMenu: _inMenu ?? false, onToggle: _toggleMenuEntry),
          SettingSwitch(
            value: settings.checkUpdates,
            onChanged: (value) => context.read<SettingsBloc>().add(
              SettingsChanged(settings.copyWith(checkUpdates: value)),
            ),
            title: l.checkUpdatesOnStart,
            note: l.updateNote,
          ),
        ],
      ),
    );
  }
}

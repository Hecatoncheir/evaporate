import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../services/system/desktop_entry.dart';
import '../../services/system/update_check.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../../l10n/app_localizations.dart';

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

  /// Сборка под Linux — папка с файлом, а не установленный пакет, поэтому
  /// в меню приложений оно само не появляется.
  Widget _menuEntryRow(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _inMenu ?? false ? l.menuEntryAdded : l.menuEntryMissing,
              style: TextStyle(
                fontSize: 12.5,
                color: context.colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: _toggleMenuEntry,
            child: Text(_inMenu ?? false ? l.menuEntryRemove : l.menuEntryAdd),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsBloc>().state;

    return SectionCard(
      title: L.of(context).about,
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(label: L.of(context).version, value: AppVersion.current),
          const SizedBox(height: 6),
          // Wrap, а не Row: две кнопки с длинными немецкими по духу подписями
          // в узком окне не умещаются в строку, и вторая уезжает за край.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _lookForUpdate,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(L.of(context).checkForUpdates),
              ),
              if (_found != null) ...[
                FilledButton.icon(
                  onPressed: () => _openRelease(_found!.url),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(L.of(context).openReleasePage),
                ),
              ],
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: TextStyle(
                fontSize: 12.5,
                color: _isError
                    ? context.colors.danger
                    : context.colors.textSecondary,
              ),
            ),
          ],
          if (_desktop.isSupported) _menuEntryRow(context),
          SwitchListTile(
            value: settings.checkUpdates,
            onChanged: (value) => context.read<SettingsBloc>().add(
              SettingsChanged(settings.copyWith(checkUpdates: value)),
            ),
            contentPadding: EdgeInsets.zero,
            title: Text(
              L.of(context).checkUpdatesOnStart,
              style: TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              L.of(context).updateNote,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

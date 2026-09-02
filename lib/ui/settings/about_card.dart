import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../services/system/update_check.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Версия приложения и проверка обновлений.
class AboutCard extends StatefulWidget {
  const AboutCard({super.key, this.check});

  /// Подменяется в тестах: настоящий запрос к GitHub там ни к чему.
  final UpdateCheck? check;

  @override
  State<AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<AboutCard> {
  late final UpdateCheck _check = widget.check ?? UpdateCheck();

  bool _busy = false;
  String? _message;
  bool _isError = false;
  Release? _found;

  Future<void> _lookForUpdate() async {
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
            ? 'Установлена последняя версия'
            : 'Вышла версия ${release.version}';
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsBloc>().state;

    return SectionCard(
      title: 'О программе',
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(label: 'Версия', value: AppVersion.current),
          const SizedBox(height: 6),
          Row(
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
                label: const Text('Проверить обновления'),
              ),
              if (_found != null) ...[
                const SizedBox(width: 8),
                SelectableText(
                  _found!.url,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: EvaporateTheme.monoFontFamily,
                    color: context.colors.textSecondary,
                  ),
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
          SwitchListTile(
            value: settings.checkUpdates,
            onChanged: (value) => context.read<SettingsBloc>().add(
              SettingsChanged(settings.copyWith(checkUpdates: value)),
            ),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Проверять обновления при запуске',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              'Приложение только сообщает о новой версии и даёт ссылку — '
              'скачивать и ставить ничего само не будет',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

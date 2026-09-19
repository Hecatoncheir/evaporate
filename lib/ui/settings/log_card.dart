import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../services/system/app_log.dart';
import '../feedback/snack.dart';
import '../theme.dart';
import '../widgets/section_card.dart';
import 'setting_note.dart';

/// Показ журнала приложения.
///
/// Семь десятков мест в приложении гасят ошибку молча — иначе каждая мелочь
/// вылезала бы поверх экрана. Здесь всё это можно наконец увидеть: и то, что
/// приложение решило не тревожить, и то, что человек уже закрыл, не успев
/// прочитать.
///
/// Наружу журнал не уходит: его показывают и дают скопировать, а отправлять
/// ли его дальше — решает человек.
class LogCard extends StatefulWidget {
  const LogCard({super.key, this.log});

  /// Подменяется в тестах: настоящий журнал живёт в папке данных.
  final AppLog? log;

  @override
  State<LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<LogCard> {
  List<String>? _lines;
  bool _busy = false;

  AppLog get _log => widget.log ?? AppLog.instance;

  Future<void> _load() async {
    setState(() => _busy = true);
    // Записанное могло ещё не лечь на диск: пишем в очередь, а не сразу.
    await _log.flush();
    final lines = await _log.tail();
    if (mounted) {
      setState(() {
        _lines = lines;
        _busy = false;
      });
    }
  }

  Future<void> _clear() async {
    await _log.clear();
    if (mounted) setState(() => _lines = const []);
  }

  Future<void> _copy() async {
    final lines = _lines;
    if (lines == null || lines.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) showInfo(context, L.of(context).logCopied);
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;

    return SectionCard(
      title: L.of(context).logTitle,
      icon: Icons.receipt_long_outlined,
      trailing: Row(
        children: [
          if (lines != null && lines.isNotEmpty) ...[
            TextButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy_all_outlined, size: 16),
              label: Text(L.of(context).logCopy),
            ),
            TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text(L.of(context).logClear),
            ),
          ],
          OutlinedButton.icon(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: Text(L.of(context).logShow),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingNote(L.of(context).logNote),
          if (lines != null) ...[
            const SizedBox(height: 12),
            if (lines.isEmpty)
              Text(L.of(context).logEmpty, style: context.text.note)
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surfaceHigh,
                  borderRadius: BorderRadius.circular(
                    EvaporateTheme.radiusControl,
                  ),
                  border: Border.all(color: context.colors.outline),
                ),
                // Снизу вверх: важно последнее, а не первое.
                child: ListView(
                  reverse: true,
                  shrinkWrap: true,
                  children: [
                    for (final line in lines.reversed)
                      SelectableText(
                        line,
                        style: context.text.pathSmall.copyWith(height: 1.5),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

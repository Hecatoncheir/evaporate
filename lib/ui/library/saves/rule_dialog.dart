import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/save_path_template.dart';
import '../../../models/save_profile.dart';
import '../../theme.dart';
import '../../../l10n/app_localizations.dart';

class RuleDraft {
  const RuleDraft(this.label, this.template, this.currentPlatformOnly);

  final String label;
  final String template;
  final bool currentPlatformOnly;
}

class RuleDialog extends StatefulWidget {
  const RuleDialog({
    super.key,
    required this.template,
    required this.label,
    required this.gameDir,
  });

  final String template;
  final String label;

  /// Папка игры для `{GAME}` — без неё предпросмотр показал бы шаблон
  /// вместо пути.
  final String? gameDir;

  @override
  State<RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<RuleDialog> {
  late final _labelController = TextEditingController(text: widget.label);
  late final _templateController = TextEditingController(text: widget.template);
  bool _currentPlatformOnly = false;

  @override
  void dispose() {
    _labelController.dispose();
    _templateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final template = _templateController.text;
    final portable = SavePathTemplate.isPortable(template);

    return AlertDialog(
      title: Text(L.of(context).savePath),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                labelText: L.of(context).label,
                helperText: L.of(context).labelNote,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _templateController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontFamily: EvaporateTheme.monoFontFamily,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                labelText: L.of(context).pathTemplate,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              L
                  .of(context)
                  .expandsTo(
                    SavePathTemplate.expand(template, gameDir: widget.gameDir),
                  ),
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            if (!portable) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 15,
                    color: context.colors.warning,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      L.of(context).absolutePathWarning,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.warning,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _currentPlatformOnly,
              onChanged: (value) =>
                  setState(() => _currentPlatformOnly = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(
                L
                    .of(context)
                    .onlyForPlatform(platformLabel(currentPlatformKey())),
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                L.of(context).onlyForPlatformNote,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L.of(context).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            RuleDraft(
              // Именно константа, а не `L.of(context).saves`. Показывают
              // метку переведённой (`ruleLabelText`), но хранят и
              // сопоставляют — как есть: правила сходятся между
              // устройствами по метке, и записанное здесь «Saves» с
              // английского интерфейса не сошлось бы с «Сохранениями» на
              // русском. Сейв просто не восстановился бы, и никто не
              // догадался бы почему.
              _labelController.text.trim().isEmpty
                  ? SavePathRule.defaultLabel
                  : _labelController.text.trim(),
              _templateController.text.trim(),
              _currentPlatformOnly,
            ),
          ),
          child: Text(L.of(context).save),
        ),
      ],
    );
  }
}

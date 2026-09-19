import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/save_path_template.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/save_profile.dart';
import '../../theme.dart';
import '../../widgets/inline_warning.dart';

class RuleDraft {
  const RuleDraft(
    this.label,
    this.template, {
    required this.currentPlatformOnly,
  });

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
    this.profile = const SaveProfile(),
  });

  final String template;
  final String label;

  /// Уже заданные правила игры: метка нового не должна совпасть ни с одной
  /// из них — по метке правила сходятся между устройствами.
  final SaveProfile profile;

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
    final l = L.of(context);
    final template = _templateController.text;
    final draft = _draft();
    final labelTaken = widget.profile.labelTaken(
      draft.label,
      platform: draft.currentPlatformOnly ? currentPlatformKey() : null,
    );
    // Пустой шаблон развернулся бы в рабочую папку процесса, а занятая
    // метка сделала бы оба правила непереносимыми.
    final canSave = draft.template.isNotEmpty && !labelTaken;

    return AlertDialog(
      title: Text(l.savePath),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.label,
                helperText: l.labelNote,
                errorText: labelTaken ? l.labelTaken : null,
                errorMaxLines: 2,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _templateController,
              onChanged: (_) => setState(() {}),
              style: context.text.path.copyWith(
                color: context.colors.textPrimary,
              ),
              decoration: InputDecoration(labelText: l.pathTemplate),
            ),
            const SizedBox(height: 8),
            Text(
              l.expandsTo(
                SavePathTemplate.expand(template, gameDir: widget.gameDir),
              ),
              style: context.text.captionMuted,
            ),
            // Путь без плейсхолдера на другом устройстве не развернётся
            // ни во что осмысленное — об этом предупреждают сразу.
            if (!SavePathTemplate.isPortable(template)) ...[
              const SizedBox(height: 10),
              InlineWarning(l.absolutePathWarning),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _currentPlatformOnly,
              onChanged: (value) =>
                  setState(() => _currentPlatformOnly = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                l.onlyForPlatform(platformLabel(currentPlatformKey())),
                style: context.text.body,
              ),
              subtitle: Text(
                l.onlyForPlatformNote,
                style: context.text.caption,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: canSave ? () => Navigator.pop(context, draft) : null,
          child: Text(l.save),
        ),
      ],
    );
  }

  /// Правило, каким его записывают.
  ///
  /// Метка по умолчанию — именно константа, а не `L.of(context).saves`.
  /// Показывают её переведённой (`ruleLabelText`), но хранят и
  /// сопоставляют как есть: правила сходятся между устройствами по метке,
  /// и записанное здесь «Saves» с английского интерфейса не сошлось бы
  /// с «Сохранениями» на русском. Сейв просто не восстановился бы, и
  /// никто не догадался бы почему.
  RuleDraft _draft() {
    final label = _labelController.text.trim();
    return RuleDraft(
      label.isEmpty ? SavePathRule.defaultLabel : label,
      _templateController.text.trim(),
      currentPlatformOnly: _currentPlatformOnly,
    );
  }
}

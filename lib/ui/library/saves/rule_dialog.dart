import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/rule_form/rule_form_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/save_profile.dart';
import 'rule_form_fields.dart';

/// Окно правила: метка, шаблон пути и «только на этой системе».
///
/// Что из набранного следует — развернётся ли путь, переживёт ли переезд,
/// не занята ли метка и можно ли вообще сохранять — считает
/// `RuleFormBloc`. Контроллеры текста остаются здесь: это не состояние, а
/// ресурс.
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

  @override
  void dispose() {
    _labelController.dispose();
    _templateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return BlocProvider(
      create: (context) => RuleFormBloc(
        label: widget.label,
        template: widget.template,
        profile: widget.profile,
        gameDir: widget.gameDir,
      ),
      child: BlocBuilder<RuleFormBloc, RuleForm>(
        builder: (context, form) => AlertDialog(
          title: Text(l.savePath),
          content: RuleFormFields(
            form: form,
            labelController: _labelController,
            templateController: _templateController,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: form.canSave
                  ? () => Navigator.pop(context, form.draft)
                  : null,
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}

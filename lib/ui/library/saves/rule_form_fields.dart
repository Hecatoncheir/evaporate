import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/rule_form/rule_form_bloc.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../labels.dart';
import '../../theme.dart';
import '../../widgets/inline_warning.dart';

/// Поля правила: метка, шаблон, во что он развернётся здесь, и галочка
/// «только на этой системе».
class RuleFormFields extends StatelessWidget {
  const RuleFormFields({
    super.key,
    required this.form,
    required this.labelController,
    required this.templateController,
  });

  final RuleForm form;
  final TextEditingController labelController;
  final TextEditingController templateController;

  /// Почему путь не годится, — или `null`, если годится.
  String? _templateError(L l) {
    if (form.tooBroad) return l.pathTooBroad;
    final overlaps = form.overlaps;
    return overlaps == null
        ? null
        : l.pathOverlapsRule(ruleLabelText(l, overlaps));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bloc = context.read<RuleFormBloc>();

    return SizedBox(
      width: EvaporateLayout.dialogWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: labelController,
            onChanged: (value) => bloc.add(RuleLabelChanged(value)),
            decoration: InputDecoration(
              labelText: l.label,
              helperText: l.labelNote,
              errorText: form.labelTaken ? l.labelTaken : null,
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: EvaporateSpacing.panel),
          TextField(
            controller: templateController,
            onChanged: (value) => bloc.add(RuleTemplateChanged(value)),
            style: context.text.path.copyWith(
              color: context.colors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: l.pathTemplate,
              errorText: _templateError(l),
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: EvaporateSpacing.gap),
          Text(l.expandsTo(form.expanded), style: context.text.captionMuted),
          // Путь без плейсхолдера на другом устройстве не развернётся
          // ни во что осмысленное — об этом предупреждают сразу.
          if (!form.portable) ...[
            const SizedBox(height: EvaporateSpacing.cluster),
            InlineWarning(l.absolutePathWarning),
          ],
          const SizedBox(height: EvaporateSpacing.field),
          CheckboxListTile(
            value: form.currentPlatformOnly,
            onChanged: (value) =>
                bloc.add(RulePlatformOnlyChanged(only: value ?? false)),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              l.onlyForPlatform(platformLabel(currentPlatformKey())),
              style: context.text.body,
            ),
            subtitle: Text(l.onlyForPlatformNote, style: context.text.caption),
          ),
        ],
      ),
    );
  }
}

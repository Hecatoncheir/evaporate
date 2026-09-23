import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme.dart';
import '../restore_options.dart';

/// Две галочки: снять резервную копию и стереть целевую папку до
/// распаковки.
///
/// Выбор — одно значение [RestoreOptions], то же, что окно отдаёт наружу:
/// прежде две галочки ехали сюда четырьмя параметрами через тело окна,
/// которому не были нужны.
class RestoreOptionsForm extends StatelessWidget {
  const RestoreOptionsForm({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final RestoreOptions value;
  final ValueChanged<RestoreOptionsPatch> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CheckboxListTile(
          value: value.backupCurrent,
          onChanged: (on) =>
              onChanged((now) => now.copyWith(backupCurrent: on ?? true)),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l.backupFirst, style: context.text.body),
        ),
        CheckboxListTile(
          value: value.wipeTarget,
          onChanged: (on) =>
              onChanged((now) => now.copyWith(wipeTarget: on ?? false)),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l.wipeBeforeUnpack, style: context.text.body),
          subtitle: Text(l.wipeNote, style: context.text.small),
        ),
      ],
    );
  }
}

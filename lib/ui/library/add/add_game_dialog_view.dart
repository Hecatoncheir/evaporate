import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/add_game/add_game_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/busy_spinner.dart';
import 'add_game_fields.dart';
import 'source_fields.dart';

/// Окно «Добавить игру» изнутри: поля и клавиши под ними.
class AddGameDialogView extends StatelessWidget {
  const AddGameDialogView({
    super.key,
    required this.form,
    required this.inputs,
  });

  final AddGameForm form;
  final AddGameInputs inputs;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bloc = context.read<AddGameBloc>();

    return AlertDialog(
      title: Text(l.addGame),
      content: SizedBox(
        width: EvaporateLayout.dialogWidth,
        child: SingleChildScrollView(child: AddGameFields(inputs: inputs)),
      ),
      actions: [
        TextButton(
          onPressed: form.busy ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: form.busy
              ? null
              : () => bloc.add(const AddGameSubmitted()),
          child: form.busy
              ? const BusySpinner(size: EvaporateIconSize.key)
              : Text(l.add),
        ),
      ],
    );
  }
}

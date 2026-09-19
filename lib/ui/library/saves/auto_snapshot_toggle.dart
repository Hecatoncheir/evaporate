import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../widgets/labeled_switch_row.dart';

class AutoSnapshotToggle extends StatelessWidget {
  const AutoSnapshotToggle({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryBloc>();
    final l = L.of(context);

    return Column(
      children: [
        LabeledSwitchRow(
          label: l.autoSnapshotOnExit,
          value: game.saveProfile.autoSnapshotOnExit,
          onChanged: (next) =>
              library.add(AutoSnapshotChanged(game.id, onExit: next)),
        ),
        LabeledSwitchRow(
          label: l.autoSnapshotOnLaunch,
          value: game.saveProfile.autoSnapshotOnLaunch,
          onChanged: (next) =>
              library.add(AutoSnapshotChanged(game.id, onLaunch: next)),
        ),
      ],
    );
  }
}

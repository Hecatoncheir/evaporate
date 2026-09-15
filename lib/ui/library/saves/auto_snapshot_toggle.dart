import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../models/save_profile.dart';

class AutoSnapshotToggle extends StatelessWidget {
  const AutoSnapshotToggle({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryBloc>();

    Widget row(String label, bool value, SaveProfile Function(bool) apply) =>
        Row(
          children: [
            Switch(
              value: value,
              onChanged: (next) => library.add(
                GameUpdated(game.copyWith(saveProfile: apply(next))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          ],
        );

    return Column(
      children: [
        row(
          L.of(context).autoSnapshotOnExit,
          game.saveProfile.autoSnapshotOnExit,
          (next) => game.saveProfile.copyWith(autoSnapshotOnExit: next),
        ),
        row(
          L.of(context).autoSnapshotOnLaunch,
          game.saveProfile.autoSnapshotOnLaunch,
          (next) => game.saveProfile.copyWith(autoSnapshotOnLaunch: next),
        ),
      ],
    );
  }
}

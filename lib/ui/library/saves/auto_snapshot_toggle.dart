import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';

class AutoSnapshotToggle extends StatelessWidget {
  const AutoSnapshotToggle({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryBloc>();

    Widget row(
      String label,
      bool value,
      AutoSnapshotChanged Function(bool) change,
    ) => Row(
      children: [
        Switch(value: value, onChanged: (next) => library.add(change(next))),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      ],
    );

    return Column(
      children: [
        row(
          L.of(context).autoSnapshotOnExit,
          game.saveProfile.autoSnapshotOnExit,
          (next) => AutoSnapshotChanged(game.id, onExit: next),
        ),
        row(
          L.of(context).autoSnapshotOnLaunch,
          game.saveProfile.autoSnapshotOnLaunch,
          (next) => AutoSnapshotChanged(game.id, onLaunch: next),
        ),
      ],
    );
  }
}

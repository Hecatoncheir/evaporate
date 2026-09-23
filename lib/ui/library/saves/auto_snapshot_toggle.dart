import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../theme.dart';

class AutoSnapshotToggle extends StatelessWidget {
  const AutoSnapshotToggle({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryBloc>();
    final l = L.of(context);

    return Column(
      children: [
        _LabeledSwitchRow(
          label: l.autoSnapshotOnExit,
          value: game.saveProfile.autoSnapshotOnExit,
          onChanged: (next) =>
              library.add(AutoSnapshotChanged(game.id, onExit: next)),
        ),
        _LabeledSwitchRow(
          label: l.autoSnapshotOnLaunch,
          value: game.saveProfile.autoSnapshotOnLaunch,
          onChanged: (next) =>
              library.add(AutoSnapshotChanged(game.id, onLaunch: next)),
        ),
      ],
    );
  }
}

/// Переключатель с подписью справа, без отступов `SwitchListTile`: строки
/// стоят плотно и выравниваются по левому краю.
class _LabeledSwitchRow extends StatelessWidget {
  const _LabeledSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Switch(value: value, onChanged: onChanged),
        const SizedBox(width: EvaporateSpacing.cluster),
        Expanded(child: Text(label, style: context.text.body)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../theme.dart';
import '../../widgets/busy_spinner.dart';

/// Правая половина ряда действий: что делают с ярлыком игры в Steam.
///
/// Wrap — на случай, когда места и правда мало: подписи у Steam длинные,
/// и в узком окне две клавиши рядом с «Играть» переполнили бы ряд
/// полосатой лентой.
class SteamActions extends StatelessWidget {
  const SteamActions({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final library = context.read<LibraryBloc>();
    // Обе подписки заводятся всегда, а не внутри условия: число подписок в
    // `build` не должно зависеть от состояния игры.
    final addingShortcut = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.isBusy(LibraryBloc.steamShortcutKey(game.id)),
    );
    final lookingUp = context.select<LibraryBloc, bool>(
      (bloc) => bloc.state.isBusy(LibraryBloc.steamKey(game.id)),
    );

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: EvaporateSpacing.cluster,
      runSpacing: EvaporateSpacing.cluster,
      children: [
        if (game.canLaunch)
          _BusyOutlinedButton(
            busy: addingShortcut,
            onPressed: () => library.add(SteamShortcutRequested(game)),
            icon: Icons.library_add_outlined,
            label: l.steamAddAction,
          ),
        _BusyOutlinedButton(
          busy: lookingUp,
          onPressed: () => library.add(SteamLookupRequested(game)),
          icon: Icons.travel_explore,
          label: game.details.steamAppId == null
              ? l.findInSteam
              : l.refreshFromSteam,
        ),
      ],
    );
  }
}

/// Обведённая клавиша, которая на время работы гаснет и крутит колесо
/// вместо значка.
///
/// Была выписана дважды — «Добавить в Steam» и «Найти в Steam», — и копии
/// различались только ключом занятости, событием и значком. Занятость
/// приходит снаружи: клавише незачем знать, какой блок её считает.
class _BusyOutlinedButton extends StatelessWidget {
  const _BusyOutlinedButton({
    required this.busy,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final bool busy;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy ? const BusySpinner() : Icon(icon),
      label: Text(label),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/update/update_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/busy_spinner.dart';

/// Клавиши карточки «О программе». Две последние появляются, только когда
/// проверка нашла версию новее нашей.
///
/// `Wrap`, а не `Row`: две кнопки с длинными немецкими по духу подписями
/// в узком окне не умещаются в строку, и вторая уезжает за край.
///
/// Ход проверки и её события клавиши берут у `UpdateBloc` сами: прежде
/// карточка передавала сюда семь значений, и четыре из них были
/// однострочными `bloc.add`.
class AboutActions extends StatelessWidget {
  const AboutActions({super.key});

  /// Куда ведёт «Исходный код». Отсюда же человек попадает к релизам:
  /// ссылка на них у GitHub своя, и вторую клавишу она не заслуживает.
  static const _repositoryUrl = 'https://github.com/Hecatoncheir/evaporate';

  /// Кружок вместо значка, пока клавиша занята работой. Размер тот же, что
  /// у значка: иначе ряд дёргался бы на каждое нажатие.
  static const _spinner = BusySpinner();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bloc = context.read<UpdateBloc>();
    final update = context.watch<UpdateBloc>().state;
    final release = update.found;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: update.checking
              ? null
              : () => bloc.add(const UpdateCheckRequested()),
          icon: update.checking
              ? _spinner
              : const Icon(Icons.refresh, size: EvaporateIconSize.panel),
          label: Text(l.checkForUpdates),
        ),
        // Ссылка переехала сюда из нижней строки окна: там она занимала
        // место навсегда, а нажимают её один раз в жизни, и остальное про
        // сборку — версия, обновления — и так здесь.
        FilledButton.tonalIcon(
          onPressed: () => bloc.add(const UpdateLinkRequested(_repositoryUrl)),
          icon: const Icon(Icons.open_in_new),
          label: Text(l.sourceCode),
        ),
        if (release != null) ...[
          if (release.updateForThisPlatform != null)
            FilledButton.icon(
              onPressed: update.installing
                  ? null
                  : () => bloc.add(const UpdateInstallRequested()),
              icon: update.installing
                  ? _spinner
                  : const Icon(Icons.system_update_alt),
              label: Text(l.updateInstall),
            ),
          FilledButton.tonalIcon(
            onPressed: () => bloc.add(UpdateLinkRequested(release.url)),
            icon: const Icon(Icons.open_in_new),
            label: Text(l.openReleasePage),
          ),
        ],
      ],
    );
  }
}

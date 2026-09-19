import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/system/update_check.dart';
import '../widgets/busy_spinner.dart';

/// Клавиши карточки «О программе». Две последние появляются, только когда
/// проверка нашла версию новее нашей.
///
/// `Wrap`, а не `Row`: две кнопки с длинными немецкими по духу подписями
/// в узком окне не умещаются в строку, и вторая уезжает за край.
class AboutActions extends StatelessWidget {
  const AboutActions({
    super.key,
    required this.busy,
    required this.updating,
    required this.found,
    required this.onCheck,
    required this.onSourceCode,
    required this.onInstall,
    required this.onReleasePage,
  });

  /// Идёт проверка обновлений.
  final bool busy;

  /// Идёт подготовка обновления.
  final bool updating;

  /// Что нашла проверка. `null` — не искали или мы и так свежие.
  final Release? found;

  final VoidCallback onCheck;
  final VoidCallback onSourceCode;
  final VoidCallback onInstall;
  final VoidCallback onReleasePage;

  /// Кружок вместо значка, пока клавиша занята работой. Размер тот же, что
  /// у значка: иначе ряд дёргался бы на каждое нажатие.
  static const _spinner = BusySpinner();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final release = found;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: busy ? null : onCheck,
          icon: busy ? _spinner : const Icon(Icons.refresh, size: 18),
          label: Text(l.checkForUpdates),
        ),
        // Ссылка переехала сюда из нижней строки окна: там она занимала
        // место навсегда, а нажимают её один раз в жизни, и остальное про
        // сборку — версия, обновления — и так здесь.
        FilledButton.tonalIcon(
          onPressed: onSourceCode,
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(l.sourceCode),
        ),
        if (release != null) ...[
          if (release.updateForThisPlatform != null)
            FilledButton.icon(
              onPressed: updating ? null : onInstall,
              icon: updating
                  ? _spinner
                  : const Icon(Icons.system_update_alt, size: 16),
              label: Text(l.updateInstall),
            ),
          FilledButton.tonalIcon(
            onPressed: onReleasePage,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(l.openReleasePage),
          ),
        ],
      ],
    );
  }
}

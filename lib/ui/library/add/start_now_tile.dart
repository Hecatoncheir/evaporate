import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme.dart';

/// Ставить ли загрузку сразу.
///
/// Пока движок не поднялся, галочка погашена, и рядом сказано почему:
/// иначе она выглядела бы сломанной.
class StartNowTile extends StatelessWidget {
  const StartNowTile({
    super.key,
    required this.value,
    required this.ready,
    required this.engineState,
    required this.onChanged,
  });

  final bool value;

  /// Движок загрузок поднят.
  final bool ready;

  /// Чем он занят, если не поднят, — словами для человека.
  final String engineState;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return CheckboxListTile(
      value: value && ready,
      onChanged: ready ? (next) => onChanged(next ?? false) : null,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(l.startDownloadNow),
      subtitle: ready
          ? null
          : Text(
              l.engineUnavailable(engineState),
              style: context.text.caption.copyWith(
                color: context.colors.warning,
              ),
            ),
    );
  }
}

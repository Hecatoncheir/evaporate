import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/log/log_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/system/app_log.dart';
import '../../feedback/snack.dart';
import '../../theme.dart';
import '../../widgets/section_card.dart';
import '../log_view.dart';
import '../setting_note.dart';

/// Показ журнала приложения.
///
/// Семь десятков мест в приложении гасят ошибку молча — иначе каждая мелочь
/// вылезала бы поверх экрана. Здесь всё это можно наконец увидеть: и то, что
/// приложение решило не тревожить, и то, что человек уже закрыл, не успев
/// прочитать.
///
/// Наружу журнал не уходит: его показывают и дают скопировать, а отправлять
/// ли его дальше — решает человек.
class LogCard extends StatelessWidget {
  const LogCard({super.key, this.log});

  /// Подменяется в тестах: настоящий журнал живёт в папке данных.
  final AppLog? log;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return BlocProvider(
      create: (context) => LogBloc(log: log),
      child: BlocBuilder<LogBloc, LogState>(
        builder: (context, state) {
          final lines = state.lines;
          return SectionCard(
            title: l.logTitle,
            icon: Icons.receipt_long_outlined,
            trailing: _LogActions(lines: lines, busy: state.busy),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingNote(l.logNote),
                if (lines != null) ...[
                  const SizedBox(height: EvaporateSpacing.field),
                  LogView(lines: lines),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Копирование — единственное, что остаётся у карточки: буфер обмена не
/// состояние, а сообщение об удаче показывает `SnackBar` по месту.
Future<void> _copy(BuildContext context, List<String> lines) async {
  if (lines.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: lines.join('\n')));
  if (context.mounted) showInfo(context, L.of(context).logCopied);
}

/// Клавиши журнала в заголовке карточки. Переносом, а не строкой: строка
/// забирала бы у заголовка всю ширину и уводила клавиши под имя карточки
/// в любом окне.
class _LogActions extends StatelessWidget {
  const _LogActions({required this.lines, required this.busy});

  final List<String>? lines;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bloc = context.read<LogBloc>();
    final shown = lines ?? const [];
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (shown.isNotEmpty) ...[
          TextButton.icon(
            onPressed: () => _copy(context, shown),
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(l.logCopy),
          ),
          TextButton.icon(
            onPressed: () => bloc.add(const LogClearRequested()),
            icon: const Icon(Icons.delete_outline),
            label: Text(l.logClear),
          ),
        ],
        OutlinedButton.icon(
          onPressed: busy ? null : () => bloc.add(const LogShowRequested()),
          icon: const Icon(Icons.visibility_outlined),
          label: Text(l.logShow),
        ),
      ],
    );
  }
}

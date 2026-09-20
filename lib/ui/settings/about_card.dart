import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/update/update_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../services/system/desktop_entry.dart';
import '../../services/system/update_check.dart';
import '../widgets/section_card.dart';
import 'about_body.dart';

/// Версия приложения и проверка обновлений.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key, this.check, this.openLink, this.desktop});

  /// Подменяется в тестах: настоящий запрос к GitHub там ни к чему.
  final UpdateCheck? check;

  /// Чем открывать ссылку. Тоже подменяется в тестах: браузер посреди
  /// прогона никому не нужен.
  final Future<bool> Function(Uri uri)? openLink;

  /// Запись в меню приложений. В тестах подменяется на такую, у которой нет
  /// домашней папки: иначе карточка полезла бы за настоящим файлом.
  final DesktopEntry? desktop;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UpdateBloc(
        check: check,
        openLink: openLink,
        desktop: desktop,
        localizations: () => L.of(context),
      ),
      child: SectionCard(
        title: L.of(context).about,
        icon: Icons.info_outline,
        child: const AboutBody(),
      ),
    );
  }
}

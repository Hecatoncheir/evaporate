import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/section_heading.dart';
import 'about_card.dart';
import 'cards/appearance_card.dart';
import 'cards/download_settings_card.dart';
import 'cards/engine_info_card.dart';
import 'cards/metadata_card.dart';
import 'cards/save_settings_card.dart';
import 'cards/window_startup_card.dart';
import 'effects_card.dart';
import 'gamepad_settings.dart';
import 'log_card.dart';
import 'notification_settings.dart';
import 'proxy_settings_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Стрелки вверх и вниз уводят фокус, даже стоя в поле ввода. Штатная
    // привязка несёт `ignoreTextFields: true`, и действие внутри поля её
    // сознательно отбрасывает — для однострочного поля это значит «ничего
    // не делать», и спустившись сюда с клавиатуры, человек в поле и
    // застревал. Здесь флаг снят: вверх и вниз в настройках всегда про
    // переход между строками, а правка текста остаётся ←/→.
    //
    // Список собран не ListView, и это тоже про навигацию: ListView строит
    // только то, что видно, и следующей карточки просто нет в дереве —
    // фокусу некуда идти. Спуск с геймпада упирался в последнюю построенную
    // карточку и дальше не шёл. Настроек десяток, лениво строить тут нечего.
    return FocusTraversalGroup(
      policy: _ListTraversal(),
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
            TraversalDirection.up,
            ignoreTextFields: false,
          ),
          SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
            TraversalDirection.down,
            ignoreTextFields: false,
          ),
        },
        child: SingleChildScrollView(
          padding: EvaporateLayout.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeading(
                label: L.of(context).conceptSettingsLabel,
                semanticsLabel: L.of(context).settings,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 18),
              // Каждая карточка сама берёт из блоков то, что показывает:
              // страница не подписана ни на что, и правка одной настройки
              // не перестраивает соседние карточки.
              const AppearanceCard(),
              const WindowStartupCard(),
              const GamepadSettingsCard(),
              const NotificationSettingsCard(),
              const DownloadSettingsCard(),
              const MetadataCard(),
              const EngineInfoCard(),
              const ProxySettingsCard(),
              const SaveSettingsCard(),
              const LibraryEffectsCard(),
              const LogCard(),
              const AboutCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Настройки — столбец, а не сетка.
///
/// Штатный обход ищет соседа по пересечению полос: «Показать» в карточке
/// журнала прижата вправо, а «Проверить обновления» под ней — влево, полосы
/// не пересекаются, и спуск перепрыгивал кнопку целиком, а следом уходил в
/// боковую панель. В столбце «вниз» всегда значит «следующая строка», и
/// геометрии тут решать нечего.
///
/// Влево и вправо остаются штатными: там как раз строки — переключатели
/// вида «Как в системе» и ползунки.
class _ListTraversal extends ReadingOrderTraversalPolicy {
  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) =>
      switch (direction) {
        TraversalDirection.down => next(currentNode),
        TraversalDirection.up => previous(currentNode),
        TraversalDirection.left ||
        TraversalDirection.right => super.inDirection(currentNode, direction),
      };
}

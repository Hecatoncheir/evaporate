import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_settings.dart';
import '../../services/download/download_engine.dart';
import '../labels.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/scale_control.dart';
import '../widgets/section_heading.dart';
import 'about_card.dart';
import 'effects_card.dart';
import 'gamepad_settings.dart';
import 'log_card.dart';
import 'notification_settings.dart';
import 'path_setting.dart';
import 'pickers.dart';
import 'proxy_settings_card.dart';
import 'speed_field.dart';

/// Как правка настроек уходит в блок. Все карточки страницы получают её
/// одинаково: собрали новые настройки целиком — отдали.
typedef _Update = void Function(AppSettings next);

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsBloc>();
    // Только состояние движка, а не весь блок: скорости в нём меняются раз
    // в секунду, а страница живёт в IndexedStack и строится даже тогда,
    // когда открыта библиотека. Подписка на всё перерисовывала бы её
    // ежесекундно всю загрузку напролёт.
    final engine = context.select<DownloadsBloc, EngineStatus>(
      (bloc) => bloc.state.engine,
    );
    final settings = store.state;

    void update(AppSettings next) {
      store.add(SettingsChanged(next));
    }

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
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeading(
                label: L.of(context).conceptSettingsLabel,
                semanticsLabel: L.of(context).settings,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 18),
              _appearanceCard(context, settings, update),
              _windowCard(context, settings, update),
              const GamepadSettingsCard(),
              const NotificationSettingsCard(),
              _downloadsCard(context, settings, update),
              _metadataCard(context),
              _engineCard(context, engine),
              const ProxySettingsCard(),
              _savesCard(context, settings, update),
              const LibraryEffectsCard(),
              const LogCard(),
              const AboutCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// Язык, тема и крупность интерфейса.
  ///
  /// Всё это лежало в карточке «Сохранения» — не по вкусовщине, а по ошибке
  /// раскладки: искать язык в сохранениях никто не станет. Теперь вид
  /// отдельно, окно и запуск отдельно, сохранения — про сохранения.
  Widget _appearanceCard(
    BuildContext context,
    AppSettings settings,
    _Update update,
  ) {
    final l = L.of(context);
    return SectionCard(
      title: l.appearanceAndLanguage,
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LanguagePicker(
            value: settings.locale,
            onChanged: (code) => update(settings.copyWith(locale: code)),
          ),
          const SizedBox(height: 12),
          ThemePicker(
            value: settings.themeMode,
            onChanged: (mode) => update(settings.copyWith(themeMode: mode)),
          ),
          const SizedBox(height: 14),
          // Крупность обложек отсюда убрана: она стоит в самой библиотеке,
          // рядом с тем, на что влияет. Два ползунка с одинаковой подписью
          // в двух местах — это выбор, какой из них настоящий.
          Wrap(
            spacing: 20,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: Text(
                  l.interfaceScale,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              ScaleControl(
                key: const ValueKey('interface-scale'),
                label: l.interfaceScale,
                value: settings.interfaceScale,
                min: AppSettings.minInterfaceScale,
                max: AppSettings.maxInterfaceScale,
                step: 0.05,
                onChanged: (value) =>
                    update(settings.copyWith(interfaceScale: value)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _note(context, l.interfaceScaleNote),
        ],
      ),
    );
  }

  /// Каким показывается окно при запуске и запускаться ли с системой.
  Widget _windowCard(
    BuildContext context,
    AppSettings settings,
    _Update update,
  ) {
    final l = L.of(context);
    return SectionCard(
      title: l.windowAndStartup,
      icon: Icons.desktop_windows_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WindowStartPicker(
            value: settings.windowStart,
            onChanged: (mode) => update(settings.copyWith(windowStart: mode)),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            value: settings.launchAtStartup,
            onChanged: (value) =>
                update(settings.copyWith(launchAtStartup: value)),
            contentPadding: EdgeInsets.zero,
            title: Text(
              l.launchAtStartup,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              l.launchAtStartupNote,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Куда качать, сколько задач разом и какие держать скорости.
  Widget _downloadsCard(
    BuildContext context,
    AppSettings settings,
    _Update update,
  ) {
    final l = L.of(context);
    final limits = settings.limits;
    return SectionCard(
      title: l.downloads,
      icon: Icons.download_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PathSetting(
            label: l.gamesFolder,
            value: settings.installDir,
            onPick: () async {
              final dir = await getDirectoryPath();
              if (dir == null) return;
              update(settings.copyWith(installDir: dir));
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 220,
                child: Text(
                  l.concurrentDownloads,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              DropdownButton<int>(
                value: settings.maxConcurrent,
                underline: const SizedBox.shrink(),
                items: [
                  for (final value in [1, 2, 3, 5, 8])
                    DropdownMenuItem(value: value, child: Text('$value')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  update(settings.copyWith(maxConcurrent: value));
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          SpeedField(
            label: l.limitDownload,
            value: limits.download,
            onChanged: (value) => update(
              settings.copyWith(limits: limits.copyWith(download: value)),
            ),
          ),
          SpeedField(
            label: l.limitUpload,
            value: limits.upload,
            hint: l.limitUploadNote,
            onChanged: (value) => update(
              settings.copyWith(limits: limits.copyWith(upload: value)),
            ),
          ),
          SpeedField(
            label: l.seedRatio,
            value: limits.seedRatio,
            unit: l.seedRatioUnit,
            hint: l.seedRatioNote,
            onChanged: (value) => update(
              settings.copyWith(limits: limits.copyWith(seedRatio: value)),
            ),
          ),
          SpeedField(
            label: l.limitWhilePlaying,
            value: limits.whilePlaying,
            hint: l.limitPlayingNote,
            onChanged: (value) => update(
              settings.copyWith(limits: limits.copyWith(whilePlaying: value)),
            ),
          ),
        ],
      ),
    );
  }

  /// Просьба поискать обложки и пути заново — для игр, которым их не хватает.
  Widget _metadataCard(BuildContext context) {
    final l = L.of(context);
    return SectionCard(
      title: l.metadataRetryTitle,
      icon: Icons.image_search_outlined,
      trailing: OutlinedButton.icon(
        onPressed: () =>
            context.read<LibraryBloc>().add(const MetadataRetryRequested()),
        icon: const Icon(Icons.refresh, size: 16),
        label: Text(l.metadataRetryAction),
      ),
      child: _note(context, l.metadataRetryNote),
    );
  }

  /// Справка о движке загрузок.
  ///
  /// Без клавиши перезапуска: она осталась одна, на самих загрузках, где
  /// движок и живёт.
  Widget _engineCard(BuildContext context, EngineStatus engine) {
    final l = L.of(context);
    return SectionCard(
      title: l.downloadEngine,
      icon: Icons.settings_ethernet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(
            label: l.engineState,
            value: engine.message ?? engineStateLabel(l, engine.state),
            valueColor: engine.isReady
                ? context.colors.accent
                : context.colors.warning,
          ),
          InfoRow(label: l.engineImplementation, value: l.engineBuiltIn),
          const SizedBox(height: 8),
          _note(context, l.engineNote),
        ],
      ),
    );
  }

  /// Папка синхронизации и то, когда снимки снимаются сами.
  Widget _savesCard(
    BuildContext context,
    AppSettings settings,
    _Update update,
  ) {
    final l = L.of(context);
    return SectionCard(
      title: l.saves,
      icon: Icons.save_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PathSetting(
            label: l.syncFolder,
            value: settings.syncFolder ?? l.notSet,
            onPick: () async {
              final dir = await getDirectoryPath();
              if (dir == null) return;
              update(settings.copyWith(syncFolder: dir));
            },
            onClear: settings.syncFolder == null
                ? null
                : () => update(settings.copyWith(syncFolder: null)),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            value: settings.autoExportToSync,
            onChanged: (value) =>
                update(settings.copyWith(autoExportToSync: value)),
            contentPadding: EdgeInsets.zero,
            title: Text(
              l.copyToSyncFolder,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            value: settings.autoSnapshotOnExit,
            onChanged: (value) =>
                update(settings.copyWith(autoSnapshotOnExit: value)),
            contentPadding: EdgeInsets.zero,
            title: Text(l.snapshotOnExit, style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              l.defaultForNewGames,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          SwitchListTile(
            value: settings.autoSnapshotOnLaunch,
            onChanged: (value) =>
                update(settings.copyWith(autoSnapshotOnLaunch: value)),
            contentPadding: EdgeInsets.zero,
            title: Text(
              l.snapshotOnLaunch,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              l.autoSnapshotOnLaunchNote,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Пояснение под настройкой — одним начертанием на всю страницу.
  Widget _note(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 12.5,
      height: 1.5,
      color: context.colors.textSecondary,
    ),
  );
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

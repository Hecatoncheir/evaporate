import 'dart:io';

import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/l10n/app_localizations_en.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/models/window_start_mode.dart';
import 'package:evaporate/services/system/app_tray.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('режим запуска окна', () {
    test('имена читаются обратно', () {
      for (final mode in WindowStartMode.values) {
        expect(WindowStartMode.fromName(mode.name), mode);
      }
    });

    test('незнакомое имя означает «как закрыли»', () {
      expect(WindowStartMode.fromName('фуллскрин'), WindowStartMode.remembered);
      expect(WindowStartMode.fromName(null), WindowStartMode.remembered);
    });

    test('выбор переживает запись и чтение', () {
      for (final mode in WindowStartMode.values) {
        final settings = const AppSettings(installDir: '/games')
            .withStartup((s) => s.copyWith(windowStart: mode));

        final restored = AppSettings.fromJson(settings.toJson(), '/games');

        expect(restored.startup.windowStart, mode);
      }
    });
  });

  // Настройка раньше состояла из двух галочек. Файл настроек у пользователя
  // уже лежит на диске, и обновление приложения не должно молча сбрасывать
  // его выбор.
  group('старые настройки понимаются', () {
    AppSettings read(Map<String, dynamic> json) =>
        AppSettings.fromJson({'installDir': '/games', ...json}, '/games');

    test('прежнее «всегда разворачивать» становится режимом', () {
      expect(
        read({'startMaximized': true}).startup.windowStart,
        WindowStartMode.maximized,
      );
    });

    test('прежнее «не запоминать размер» тоже даёт развёрнутое', () {
      expect(
        read({'rememberWindowSize': false}).startup.windowStart,
        WindowStartMode.maximized,
      );
    });

    test('прежние значения по умолчанию дают «как закрыли»', () {
      expect(
        read({'rememberWindowSize': true, 'startMaximized': false})
            .startup
            .windowStart,
        WindowStartMode.remembered,
      );
    });

    test('новое значение важнее старых', () {
      expect(
        read({'windowStart': 'minimized', 'startMaximized': true})
            .startup
            .windowStart,
        WindowStartMode.minimized,
      );
    });

    test('пустой файл настроек не ломает чтение', () {
      expect(read({}).startup.windowStart, WindowStartMode.remembered);
    });
  });

  group('значок в трее', () {
    // `windowManager` при создании заводит канал к платформе, а без
    // привязки Flutter канала нет.
    TestWidgetsFlutterBinding.ensureInitialized();

    test('смена языка обновляет установленное меню', () async {
      final host = _RecordingHost();
      L language = LRu();
      final tray = AppTray(host: host, localizations: () => language);

      await tray.install();
      language = LEn();
      await tray.updateMenu();

      expect(host.menus, hasLength(2));
      expect(host.menus.last.first.label, 'Open Evaporate');
      await tray.dispose();
      expect(host.disposed, isTrue);
    });

    // На Windows — .ico: он несёт несколько размеров, и значок не мылится
    // при масштабе экрана больше ста процентов.
    test('формат значка выбирается под систему', () {
      expect(AppTray.iconPath, endsWith(Platform.isWindows ? '.ico' : '.png'));
    });

    test('оба файла значка лежат в проекте', () {
      expect(File('assets/branding/tray_icon.png').existsSync(), isTrue);
      expect(File('assets/branding/tray_icon.ico').existsSync(), isTrue);
    });

    test('в меню есть чем открыть и чем выйти', () {
      final ids = AppTray.menuEntries(LRu()).map((e) => e.id).toList();

      expect(ids, containsAll(['show', 'quit']));
    });

    test('текст меню берётся из выбранного языка', () {
      expect(AppTray.menuEntries(LEn()).first.label, 'Open Evaporate');
      expect(AppTray.menuEntries(LRu()).first.label, 'Открыть Evaporate');
    });

    // Своими силами трей умеет только убить окно вместе с процессом, и
    // отложенные записи на диск до него не доходят.
    test('«Выход» уходит через завершение приложения, а не мимо него', () {
      var quits = 0;
      final tray = AppTray(host: _RecordingHost(), onQuit: () async => quits++);

      tray.onMenuSelected('quit');

      expect(quits, 1);
    });

    // Отказ трея приложение переживает показом окна (`main`), а для этого
    // отказ должен дойти до него, а не потеряться внутри.
    test('отказ системного трея доходит до того, кто ставил', () async {
      final tray = AppTray(host: _RecordingHost(fails: true));

      await expectLater(tray.install(), throwsStateError);
    });
  });
}

/// Трей, который запоминает, что ему поручили.
class _RecordingHost implements TrayHost {
  _RecordingHost({this.fails = false});

  final bool fails;
  final menus = <List<TrayEntry>>[];
  var disposed = false;

  @override
  void show({
    required String iconAsset,
    required String tooltip,
    required List<TrayEntry> menu,
    required void Function() onIconClick,
    required void Function(String id) onMenuSelected,
  }) {
    if (fails) throw StateError('трей недоступен');
    menus.add(menu);
  }

  @override
  void setMenu(List<TrayEntry> menu, void Function(String id) onMenuSelected) =>
      menus.add(menu);

  @override
  void dispose() => disposed = true;
}

import 'dart:io';

import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/models/window_start_mode.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/l10n/app_localizations_en.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
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
            .copyWith(windowStart: mode);

        final restored = AppSettings.fromJson(settings.toJson(), '/games');

        expect(restored.windowStart, mode);
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
        read({'startMaximized': true}).windowStart,
        WindowStartMode.maximized,
      );
    });

    test('прежнее «не запоминать размер» тоже даёт развёрнутое', () {
      expect(
        read({'rememberWindowSize': false}).windowStart,
        WindowStartMode.maximized,
      );
    });

    test('прежние значения по умолчанию дают «как закрыли»', () {
      expect(
        read({'rememberWindowSize': true, 'startMaximized': false}).windowStart,
        WindowStartMode.remembered,
      );
    });

    test('новое значение важнее старых', () {
      expect(
        read({'windowStart': 'minimized', 'startMaximized': true}).windowStart,
        WindowStartMode.minimized,
      );
    });

    test('пустой файл настроек не ломает чтение', () {
      expect(read({}).windowStart, WindowStartMode.remembered);
    });
  });

  group('значок в трее', () {
    testWidgets('смена локали обновляет установленное меню', (tester) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('tray_manager');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      L language = LRu();
      final tray = AppTray(localizations: () => language);
      await tray.install();
      language = LEn();
      await tray.updateMenu();
      final menus = calls
          .where((call) => call.method == 'setContextMenu')
          .toList();
      expect(menus, hasLength(2));
      expect(menus.last.arguments.toString(), contains('Open Evaporate'));
      await tray.dispose();
      expect(calls.last.method, 'destroy');
    });
    // Windows принимает в трее только .ico — PNG там просто не появится.
    test('формат значка выбирается под систему', () {
      expect(AppTray.iconPath, endsWith(Platform.isWindows ? '.ico' : '.png'));
    });

    test('оба файла значка лежат в проекте', () {
      expect(File('assets/branding/tray_icon.png').existsSync(), isTrue);
      expect(File('assets/branding/tray_icon.ico').existsSync(), isTrue);
    });

    test('в меню есть чем открыть и чем выйти', () {
      final keys = AppTray.buildMenu(LRu()).items!.map((i) => i.key).toList();

      expect(keys, contains('show'));
      expect(keys, contains('quit'));
    });

    test('текст меню берётся из выбранного языка', () {
      expect(AppTray.buildMenu(LEn()).items!.first.label, 'Open Evaporate');
      expect(AppTray.buildMenu(LRu()).items!.first.label, 'Открыть Evaporate');
    });
  });
}

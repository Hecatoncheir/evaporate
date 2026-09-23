import 'dart:convert';
import 'dart:io';

import 'package:evaporate/bloc/update/update_bloc.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/l10n/app_localizations_en.dart';
import 'package:evaporate/services/system/desktop_entry.dart';
import 'package:evaporate/services/system/update_check.dart';
import 'package:evaporate/services/system/update_download.dart';
import 'package:evaporate/services/system/update_installer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/bloc_idle.dart';
import '../support/temp_dir.dart';

/// Обновление по нажатию заменяет само приложение: молчать здесь нельзя ни
/// об отказе, ни о том, что замена уже идёт.
void main() {
  late HandlerTracker handlers;
  setUp(() => handlers = installHandlerTracker());

  UpdateCheck answering(String body) =>
      UpdateCheck(currentVersion: '0.1.0', fetch: (uri) async => body);

  /// Ответ GitHub с одной версией.
  String releaseJson(String version) =>
      '{"tag_name": "v$version", "html_url": "https://релиз/$version", '
      '"body": "", "assets": []}';

  UpdateBloc bloc({
    UpdateCheck? check,
    DesktopEntry? desktop,
    UpdateInstaller? installer,
    UpdateDownload? download,
    Future<bool> Function(Uri uri)? openLink,
    Future<void> Function()? onRestart,
    L Function()? localizations,
  }) {
    final update = UpdateBloc(
      check: check ?? answering(releaseJson('0.1.0')),
      desktop: desktop ?? _NoDesktop(),
      installer: installer,
      download: download,
      openLink: openLink ?? (uri) async => true,
      onRestart: onRestart ?? () async {},
      localizations: localizations,
    );
    addTearDown(update.close);
    return update;
  }

  Future<UpdateState> settle(
    UpdateBloc update,
    bool Function(UpdateState) ok,
  ) => update.stream.firstWhere(ok).timeout(const Duration(seconds: 10));

  group('проверка', () {
    test('версия новее нашей находится и называется', () async {
      final update = bloc(check: answering(releaseJson('9.9.9')));

      update.add(const UpdateCheckRequested());
      final state = await settle(update, (s) => s.found != null);

      expect(state.found!.version, contains('9.9.9'));
      expect(state.message, contains('9.9.9'));
      expect(state.isError, isFalse);
    });

    test('у свежей копии находить нечего, и это не ошибка', () async {
      final update = bloc(check: answering(releaseJson('0.0.1')));

      update.add(const UpdateCheckRequested());
      final state = await settle(
        update,
        (s) => !s.checking && s.message != null,
      );

      expect(state.found, isNull);
      expect(state.isError, isFalse);
    });

    // Сеть отвалилась, GitHub ответил отказом — человеку говорят словами.
    test('неудача проверки приходит сообщением', () async {
      final update = bloc(check: answering('не json вовсе'));

      update.add(const UpdateCheckRequested());
      final state = await settle(update, (s) => s.isError);

      expect(state.message, isNotEmpty);
      expect(state.checking, isFalse);
    });
  });

  group('замена', () {
    test('копию, которую нам не переписать, не трогают', () async {
      final update = bloc(
        check: answering(releaseJson('9.9.9')),
        installer: _ReadOnlyInstall(),
      );

      update.add(const UpdateCheckRequested());
      await settle(update, (s) => s.found != null);
      update.add(const UpdateInstallRequested());
      final state = await settle(update, (s) => s.isError);

      expect(state.installing, isFalse);
      expect(state.message, isNotEmpty);
    });

    // Отказ приходит из глубины — транспорта, распаковки, установщика — и
    // прежде приходил оттуда русским литералом мимо переводов: в
    // английском интерфейсе «Сервер ответил 404».
    test('отказ из глубины обновления говорит на языке интерфейса', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      final work = await Directory.systemTemp.createTemp('ev_update_');
      addTearDown(() => deleteTempDir(work));
      const name = 'evaporate-9.9.9-windows-setup.exe';
      final release = jsonEncode({
        'tag_name': 'v9.9.9',
        'html_url': 'https://релиз/9.9.9',
        'body': '',
        'assets': [
          {
            'name': name,
            'browser_download_url': 'http://127.0.0.1:${server.port}/$name',
            'size': 5,
          },
        ],
      });
      final update = bloc(
        check: answering(release),
        installer: _WritableInstall(),
        download: UpdateDownload(workDir: work.path, platform: 'windows'),
        localizations: LEn.new,
      );

      update.add(const UpdateCheckRequested());
      await settle(update, (s) => s.found != null);
      update.add(const UpdateInstallRequested());
      final state = await settle(update, (s) => s.isError);

      expect(state.message, LEn().updateServerStatus('404'));
    });

    // Пока нечего ставить, нажимать нечего: без найденной версии замена
    // взяла бы неизвестно что.
    test('без найденной версии нажатие ничего не делает', () async {
      final update = bloc(installer: _ReadOnlyInstall());

      update.add(const UpdateInstallRequested());
      await handlers.settle();

      expect(update.state.installing, isFalse);
      expect(update.state.message, isNull);
    });
  });

  group('ссылки', () {
    test('когда открыть нечем, об этом говорят', () async {
      final update = bloc(openLink: (uri) async => false);

      update.add(const UpdateLinkRequested('https://релиз/9.9.9'));
      final state = await settle(update, (s) => s.isError);

      expect(state.message, contains('9.9.9'));
    });

    test('открытую ссылку молча и оставляют', () async {
      final update = bloc();

      update.add(const UpdateLinkRequested('https://релиз/9.9.9'));
      await handlers.settle();

      expect(update.state.message, isNull);
      expect(update.state.isError, isFalse);
    });
  });

  group('запись в меню приложений', () {
    test('там, где её не бывает, о ней и не спрашивают', () async {
      final update = bloc();
      await handlers.settle();

      expect(update.menuEntrySupported, isFalse);
      expect(update.state.inMenu, isNull);
    });

    // Запись могли убрать и мимо нас: верим системе, а не своему намерению.
    test('после переключения состояние спрашивают заново', () async {
      final desktop = _FakeDesktop();
      final update = bloc(desktop: desktop);
      await settle(update, (s) => s.inMenu == false);

      update.add(const MenuEntryToggled());
      final state = await settle(update, (s) => s.inMenu ?? false);

      expect(state.inMenu, isTrue);
      expect(desktop.asked, greaterThan(1));
    });
  });
}

/// Система без меню приложений — так ведут себя macOS и Windows.
class _NoDesktop extends DesktopEntry {
  @override
  bool get isSupported => false;

  @override
  Future<bool> isInstalled() async => false;

  @override
  Future<void> install() async {}

  @override
  Future<void> remove() async {}
}

/// Меню приложений, которое помнит, что ему сказали.
class _FakeDesktop extends DesktopEntry {
  bool installed = false;
  int asked = 0;

  @override
  bool get isSupported => true;

  @override
  Future<bool> isInstalled() async {
    asked++;
    return installed;
  }

  @override
  Future<void> install() async => installed = true;

  @override
  Future<void> remove() async => installed = false;
}

/// Копия, которую обновить можно: до самой замены тест не доходит.
class _WritableInstall extends UpdateInstaller {
  _WritableInstall() : super(workDir: 'нет');

  @override
  Future<bool> get canInstall async => true;

  @override
  Future<void> apply(String stagedRoot) async {}
}

/// Копия, поставленная пакетным менеджером: обновлять её должен он же.
class _ReadOnlyInstall extends UpdateInstaller {
  _ReadOnlyInstall() : super(workDir: 'нет');

  @override
  Future<bool> get canInstall async => false;

  @override
  Future<void> apply(String stagedRoot) async {}
}

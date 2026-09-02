import 'dart:io';

import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/services/system/desktop_entry.dart';
import 'package:evaporate/services/system/update_check.dart';
import 'package:evaporate/ui/settings/about_card.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_about_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Карточка «О программе» с подменённой проверкой обновлений.
  ///
  /// `environment: {}` оставляет запись в меню приложений без домашней папки —
  /// иначе на Linux виджет полез бы к настоящему файлу, а файловый ввод-вывод
  /// внутри `testWidgets` не завершается.
  Future<SettingsBloc> pumpCard(
    WidgetTester tester, {
    required String answer,
    Future<bool> Function(Uri uri)? openLink,
  }) async {
    final settings = SettingsBloc(
      AppPaths.custom(
        dataDir: p.join(tmp.path, 'data'),
        defaultInstallDir: p.join(tmp.path, 'games'),
      ),
    );
    await tester.pumpWidget(
      BlocProvider.value(
        value: settings,
        child: MaterialApp(
          theme: EvaporateTheme.dark(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          locale: const Locale('ru'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AboutCard(
                check: UpdateCheck(
                  currentVersion: '0.1.0',
                  fetch: (uri) async => answer,
                ),
                openLink: openLink,
                desktop: DesktopEntry(
                  executablePath: '/tmp/evaporate',
                  environment: const {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return settings;
  }

  const release =
      '{"tag_name": "v9.0.0", '
      '"html_url": "https://example.invalid/releases/v9.0.0"}';

  testWidgets('найденную версию открывают кнопкой, а не копируют текстом', (
    tester,
  ) async {
    final opened = <Uri>[];
    final settings = await pumpCard(
      tester,
      answer: release,
      openLink: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    addTearDown(settings.close);

    await tester.tap(find.text(LRu().checkForUpdates));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, LRu().openReleasePage);
    expect(button, findsOneWidget);
    expect(find.text('https://example.invalid/releases/v9.0.0'), findsNothing);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(opened, [Uri.parse('https://example.invalid/releases/v9.0.0')]);
  });

  testWidgets('когда открыть нечем, об этом говорят, а не молчат', (
    tester,
  ) async {
    final settings = await pumpCard(
      tester,
      answer: release,
      openLink: (uri) async => false,
    );
    addTearDown(settings.close);

    await tester.tap(find.text(LRu().checkForUpdates));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, LRu().openReleasePage));
    await tester.pumpAndSettle();

    expect(
      find.text(
        LRu().openLinkFailed('https://example.invalid/releases/v9.0.0'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('свежей версии — никакой кнопки', (tester) async {
    final settings = await pumpCard(
      tester,
      answer: '{"tag_name": "v0.0.1", "html_url": "https://example.invalid/"}',
    );
    addTearDown(settings.close);

    await tester.tap(find.text(LRu().checkForUpdates));
    await tester.pumpAndSettle();

    expect(find.text(LRu().openReleasePage), findsNothing);
    expect(find.text(LRu().upToDate), findsOneWidget);
  });
}

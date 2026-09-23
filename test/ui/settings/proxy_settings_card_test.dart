import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/ui/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// Карточка «Прокси»: поля открываются на сохранённом адресе, а набранное
/// уходит в настройки только по «Применить» — смена прокси перезапускает
/// загрузки, и делать это на каждый знак нельзя.
void main() {
  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  /// Настройки с включённым прокси, открытые на поле адреса.
  Future<TestHarness> openProxy(WidgetTester tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.settings.add(
      SettingsPatched(
        (s) => s.copyWith(
          proxy: s.proxy.copyWith(
            enabled: true,
            host: 'proxy.local',
            port: 1080,
          ),
        ),
      ),
    );
    await harness.pump(tester);
    harness.nav.add(const SectionSelected(AppSection.settings));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('proxy.local'),
      350,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('поля открываются на сохранённом адресе', (tester) async {
    await openProxy(tester);

    expect(find.widgetWithText(TextField, 'proxy.local'), findsOneWidget);
    expect(find.widgetWithText(TextField, '1080'), findsOneWidget);
  });

  testWidgets('набранный адрес уходит в настройки только по «Применить»', (
    tester,
  ) async {
    final harness = await openProxy(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'proxy.local'),
      'other.host',
    );
    await tester.pumpAndSettle();
    expect(harness.settings.state.proxy.host, 'proxy.local');

    final apply = find.widgetWithText(FilledButton, LRu().proxyApply);
    await tester.ensureVisible(apply);
    await tester.pumpAndSettle();
    await tester.tap(apply);
    await tester.pumpAndSettle();

    expect(harness.settings.state.proxy.host, 'other.host');
    expect(find.widgetWithText(TextField, 'other.host'), findsOneWidget);
  });
}

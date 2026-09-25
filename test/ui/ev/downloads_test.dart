import 'package:evaporate/ui/ev/data/sample_downloads.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/downloads/download_data.dart';
import 'package:evaporate/ui/ev/downloads/ev_torrent_row.dart';
import 'package:evaporate/ui/ev/downloads/rate_graph.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/screens/downloads_page.dart';
import 'package:evaporate/ui/ev/util/units.dart';
import 'package:evaporate/ui/ev/widgets/ev_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void _window(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Приборы раздела идут бесконечно, поэтому вместо pumpAndSettle —
/// фиксированные кадры.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> _app(WidgetTester tester) async {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  await tester.pumpWidget(EvaporateApp(effects: effects));
  await _settle(tester);
}

Future<void> _page(WidgetTester tester, EvDownloadsState state) async {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildEvTheme(),
      home: EvEffectsScope(
        effects: effects,
        child: Scaffold(
          body: DownloadsPage(downloads: sampleDownloadsFor(state)),
        ),
      ),
    ),
  );
  // Меньше секунды: за секунду график сделал бы шаг, и крупное число
  // уже не равнялось бы тому, с которого раздел начал.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

/// Выбрать состояние загрузок в «Настройках → Разработка».
Future<void> _pick(WidgetTester tester, String name) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
  await _settle(tester);
  await tester.ensureVisible(find.text(name));
  await _settle(tester);
  await tester.tap(find.text(name));
  await _settle(tester);
  await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
  await _settle(tester);
}

void main() {
  group('числа раздела складываются из строк', () {
    test('приём, отдача и «активных» — суммы по раздачам', () {
      final d = sampleDownloadsFor(EvDownloadsState.active);
      expect(d.downKb, 592 + 1030);
      expect(formatRate(d.downKb), '1.62 МБ/с');
      expect(d.upKb, 1600 + 340);
      expect(formatRate(d.upKb), '1.94 МБ/с');
      expect(d.active, 2);

      // Пик роя не ниже пика любой раздачи в нём.
      for (final t in d.torrents) {
        expect(d.peakKb, greaterThanOrEqualTo(t.peakKb));
      }
      // На диск ложится меньше, чем принято: часть частей ещё сверяется.
      expect(d.toDiskKb, lessThan(d.downKb));
      expect(formatRate(d.toDiskKb), '1.48 МБ/с');
    });

    test('кольцо и подписи под ним — одни и те же гигабайты', () {
      for (final state in EvDownloadsState.values) {
        final d = sampleDownloadsFor(state);
        final parts = d.parts;
        if (parts == null) continue;
        expect(
          parts.received + parts.inFlight + parts.verifying + parts.remaining,
          closeTo(parts.total, 1e-9),
          reason: '$state',
        );
      }
      // Кольцо показывает ту раздачу, которая принимает: первая встала —
      // кольцо перешло на вторую, а не осталось на остановленной.
      final stopped = sampleDownloadsFor(EvDownloadsState.noSpace);
      expect(percent(stopped.torrents.first.progress), 41);
      expect(percent(stopped.parts!.progress), 66);
      final active = sampleDownloadsFor(EvDownloadsState.active).parts!;
      expect(percent(active.progress), 41);
      expect(formatGbDot(active.received), '11.8 ГБ');
      expect(formatGbDot(active.total), '28.8 ГБ');

      // Двенадцать частей ушли из «получено» обратно в «проверку».
      final hash = sampleDownloadsFor(EvDownloadsState.hash).parts!;
      expect(percent(hash.progress), 38);
      expect(hash.verifying, greaterThan(active.verifying));
      expect(hash.total, closeTo(active.total, 1e-9));
    });

    test('«нечего качать» — значит и очереди нет', () {
      final empty = sampleDownloadsFor(EvDownloadsState.empty);
      expect(empty.torrents, isEmpty);
      expect(empty.queue, isEmpty);
      expect(empty.downKb, 0);
      expect(formatRate(empty.downKb), '0 Б/с');

      final active = sampleDownloadsFor(EvDownloadsState.active);
      expect(active.queue, hasLength(2));
      // Размер в очереди берётся из библиотеки, а не пишется рядом.
      expect(active.queue.first.line, 'neon-halcyon · v1.9 · 24.1 ГБ');
    });

    test('график приёма начинается с суммы раздач', () {
      final d = sampleDownloadsFor(EvDownloadsState.active);
      final series = EvRateSeries(d.downKb / 1000);
      expect(series.history, hasLength(60));
      expect(series.rate, closeTo(1.622, 1e-9));
      series.advance();
      expect(series.history, hasLength(60));
      expect(series.rate, isNot(closeTo(1.622, 1e-9)));
      expect(series.rate, inInclusiveRange(.25, 4.2));
    });
  });

  group('раздел «Загрузки»', () {
    testWidgets('обычный ход: две раздачи, очередь, приборы', (tester) async {
      _window(tester, 1440, 1200);
      await _page(tester, EvDownloadsState.active);

      expect(
        find.textContaining('1.62', findRichText: true),
        findsOneWidget,
        reason: 'приём начинается с суммы раздач',
      );
      expect(find.text('1.94 МБ/с'), findsOneWidget, reason: 'отдача');
      expect(find.text('2 / 3'), findsOneWidget, reason: 'активных');
      expect(find.text('1.48 МБ/с'), findsOneWidget, reason: 'на диск');

      expect(find.byType(EvTorrentRow), findsNWidgets(2));
      expect(
        find.text('11.8 ГБ / 28.8 ГБ · осталось 7 ч 59 мин'),
        findsOneWidget,
      );
      expect(find.text('41%'), findsOneWidget);
      expect(find.text('66%'), findsOneWidget);
      expect(find.byType(EvQueueRow), findsNWidgets(2));
      expect(find.text('2 раздачи'), findsNWidgets(2));
      expect(find.byType(EvAlertBox), findsNothing, reason: 'разбирать нечего');

      // Кольцо и подписи под ним.
      expect(find.text('41'), findsOneWidget);
      expect(find.text('11.8 ГБ'), findsOneWidget);
      expect(find.text('9.5 ГБ'), findsOneWidget, reason: 'осталось');
    });

    testWidgets('каждое состояние объясняет себя и даёт выход', (tester) async {
      _window(tester, 1440, 1200);

      await _page(tester, EvDownloadsState.noSeeds);
      expect(find.text('Ждём раздающих'), findsOneWidget);
      expect(find.text('Искать источники'), findsOneWidget);
      expect(find.text('В очередь'), findsOneWidget);
      expect(find.textContaining('приём 0 Б/с', findRichText: true), findsOne);

      await _page(tester, EvDownloadsState.noSpace);
      expect(find.text('На диске D: не хватает 6.2 ГБ'), findsOneWidget);
      expect(find.text('Выбрать диск'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget, reason: 'раздача встала');

      await _page(tester, EvDownloadsState.hash);
      expect(find.text('12 частей не прошли проверку'), findsOneWidget);
      expect(find.text('Перекачать'), findsOneWidget);
      expect(find.text('38'), findsOneWidget, reason: 'кольцо');
      expect(find.text('38%'), findsOneWidget, reason: 'строка');

      await _page(tester, EvDownloadsState.offline);
      expect(find.text('Нет сети · пауза'), findsOneWidget);
      expect(find.text('Повторить сейчас'), findsOneWidget);
      expect(find.text('0 / 3'), findsOneWidget);
      // Скорости нет — её не измеряют, а не считают нулём.
      expect(find.textContaining('приём —', findRichText: true), findsWidgets);

      await _page(tester, EvDownloadsState.empty);
      expect(find.byType(EvNothing), findsOneWidget);
      expect(find.text('Ничего не качается'), findsOneWidget);
      expect(find.text('Вставить ссылку'), findsOneWidget);
      expect(find.byType(EvQueueRow), findsNothing);
      expect(find.text('В очереди'), findsNothing);
      expect(find.text('Частей нет: ни одна раздача не идёт'), findsOneWidget);
      // Пиров нет — сетка обмена холодная, а не мигает обменом,
      // которого не происходит.
      expect(tester.widget<EvPeerHeat>(find.byType(EvPeerHeat)).live, isFalse);
    });

    testWidgets('после «меньше движения» приборы идут сразу, а не догоняют', (
      tester,
    ) async {
      _window(tester, 1440, 1200);
      await _page(tester, EvDownloadsState.active);
      List<double> series() =>
          tester.widget<EvRateGraph>(find.byType(EvRateGraph)).series;
      // Приборы прошли полминуты, потом движение выключили и включили.
      await tester.pump(const Duration(seconds: 30));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      final still = series();
      await tester.pump(const Duration(seconds: 3));
      expect(series(), still, reason: 'стоят');
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(series(), isNot(still), reason: 'снова идут');
    });

    testWidgets('на узком окне приборы встают друг под друга', (tester) async {
      _window(tester, 860, 1200);
      await _page(tester, EvDownloadsState.active);
      final rate = tester.getRect(find.byType(EvRateGraph));
      final heat = tester.getRect(find.byType(EvPeerHeat));
      expect(heat.top, greaterThan(rate.bottom), reason: 'одна колонка');
      expect(heat.left, closeTo(rate.left, 1), reason: 'одной ширины');

      _window(tester, 1440, 1200);
      await _page(tester, EvDownloadsState.active);
      final wide = tester.getRect(find.byType(EvPeerHeat));
      expect(
        wide.left,
        greaterThan(tester.getRect(find.byType(EvRateGraph)).right),
      );
    });
  });

  group('состояние окна', () {
    testWidgets('«Разработка» переключает раздел и плашки', (tester) async {
      _window(tester, 1440, 1000);
      await _app(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await _settle(tester);
      expect(find.byType(EvTorrentRow), findsNWidgets(2));
      expect(find.widgetWithText(EvPill, 'Движок готов'), findsOneWidget);

      await _pick(tester, 'Нет места на диске');
      expect(find.text('Выбрать диск'), findsOneWidget);
      expect(find.widgetWithText(EvPill, 'Диск переполнен'), findsOneWidget);
      // Плашка приёма — сумма раздач: вторая продолжает качаться.
      expect(find.widgetWithText(EvPill, '1.0 МБ/с'), findsOneWidget);

      await _pick(tester, 'Очередь пуста');
      expect(find.byType(EvNothing), findsOneWidget);
      expect(find.widgetWithText(EvPill, 'Движок простаивает'), findsOneWidget);
      expect(find.widgetWithText(EvPill, '0 Б/с'), findsOneWidget);
    });

    testWidgets('«нет сети» — состояние окна: его видят оба раздела', (
      tester,
    ) async {
      _window(tester, 1440, 1000);
      await _app(tester);

      // Со стороны загрузок: герой тоже уходит в офлайн.
      await _pick(tester, 'Сеть пропала');
      expect(find.text('Нет сети · пауза'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await _settle(tester);
      expect(find.text('НЕТ СЕТИ · ИГРАТЬ МОЖНО'), findsOneWidget);

      // И обратно: герой вернулся в покой — очередь тоже.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await _settle(tester);
      await tester.ensureVisible(find.text('Обычное состояние'));
      await _settle(tester);
      await tester.tap(find.text('Обычное состояние'));
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await _settle(tester);
      expect(find.text('Нет сети · пауза'), findsNothing);
      expect(find.byType(EvAlertBox), findsNothing);
      expect(find.widgetWithText(EvPill, 'Движок готов'), findsOneWidget);
    });
  });
}

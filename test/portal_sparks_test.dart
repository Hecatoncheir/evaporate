import 'package:evaporate/ui/library/portal_sparks.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Искры бегут по краю обложки бесконечно, поэтому проверять надо не
/// картинку, а то, что поток остаётся потоком: не растёт без предела, не
/// уходит в NaN и не прыгает через полконтура после свёрнутого окна.
void main() {
  const size = Size(200, 300);

  PortalSparkField field() => PortalSparkField()..resize(size);

  void run(PortalSparkField field, {int frames = 120, double dt = 1 / 60}) {
    for (var i = 0; i < frames; i++) {
      field.advance(dt);
    }
  }

  group('поток искр', () {
    test('искры появляются и держатся в пределе', () {
      final sparks = field();

      run(sparks, frames: 30);
      expect(sparks.sparks, isNotEmpty);

      // Десять секунд — вдесятеро дольше жизни самой долгой искры.
      run(sparks, frames: 600);
      expect(
        sparks.sparks.length,
        lessThanOrEqualTo(PortalSparkField.maxCount),
      );
    });

    // Свёрнутое окно возвращается одним огромным шагом. Без предела искры
    // проскочили бы через полконтура, и поток превратился бы в дрожь.
    test('огромный шаг не рвёт поток', () {
      final sparks = field();
      run(sparks, frames: 30);

      sparks.advance(5);

      for (final spark in sparks.sparks) {
        expect(spark.at, inInclusiveRange(0, 1));
        expect(spark.at.isFinite, isTrue);
        expect(spark.drift.isFinite, isTrue);
      }
    });

    test('искры сходят, а не копятся навсегда', () {
      final sparks = field();
      run(sparks, frames: 120);
      final born = sparks.sparks.toList();

      // Две секунды — дольше самой долгой жизни.
      run(sparks, frames: 120);

      expect(
        sparks.sparks.where(born.contains),
        isEmpty,
        reason: 'старые искры остались — поток перестал быть потоком',
      );
    });

    test('без размера поток стоит', () {
      final sparks = PortalSparkField();

      run(sparks);

      expect(sparks.sparks, isEmpty);
      expect(sparks.time, 0);
    });
  });

  group('точка на контуре', () {
    test('обходит все четыре стороны', () {
      final sparks = field();

      final top = sparks.pointAt(0.05, 0);
      final right = sparks.pointAt(0.35, 0);
      final bottom = sparks.pointAt(0.6, 0);
      final left = sparks.pointAt(0.9, 0);

      expect(top.dy, 0);
      expect(right.dx, size.width);
      expect(bottom.dy, size.height);
      expect(left.dx, 0);
    });

    // Доля пути считается по кругу: искра, ушедшая за единицу, продолжает
    // с начала, а не срывается в угол.
    test('путь замыкается', () {
      final sparks = field();

      expect(sparks.pointAt(1.25, 0), sparks.pointAt(0.25, 0));
      expect(sparks.pointAt(-0.75, 0), sparks.pointAt(0.25, 0));
    });

    test('снос уводит наружу, а не внутрь', () {
      final sparks = field();

      expect(sparks.pointAt(0.05, 4).dy, lessThan(0));
      expect(sparks.pointAt(0.6, 4).dy, greaterThan(size.height));
    });
  });

  group('плитка', () {
    Future<void> show(WidgetTester tester, {required bool enabled}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 100,
                height: 150,
                child: PortalSparks(
                  enabled: enabled,
                  child: const Text('обложка'),
                ),
              ),
            ),
          ),
        );

    testWidgets('выключенный эффект ничего не рисует', (tester) async {
      await show(tester, enabled: false);

      expect(find.text('обложка'), findsOneWidget);
      expect(find.byKey(const ValueKey('portal-sparks')), findsNothing);
    });

    testWidgets('включённый рисует поверх обложки', (tester) async {
      await show(tester, enabled: true);
      await tester.pump(const Duration(milliseconds: 17));

      expect(find.text('обложка'), findsOneWidget);
      expect(find.byKey(const ValueKey('portal-sparks')), findsOneWidget);
    });

    // Жалоба, с которой всё началось: искр почти не видно, и те, что
    // видно, лежат на самой обложке. Считаем зажжённые точки на снимке —
    // отдельно в кайме вокруг и отдельно поверх обложки.
    testWidgets('искры горят вокруг обложки, а не поверх неё', (tester) async {
      const cover = Size(120, 180);
      const halo = PortalSparkField.halo;
      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              // Чёрная подложка: иначе светлый фон сам считался бы
              // «горящим», и проверка вокруг обложки ничего не значила бы.
              child: ColoredBox(
                color: const Color(0xFF000000),
                child: SizedBox(
                  width: cover.width + halo * 2,
                  height: cover.height + halo * 2,
                  child: Center(
                    child: SizedBox(
                      width: cover.width,
                      height: cover.height,
                      child: const PortalSparks(
                        enabled: true,
                        // Непрозрачная обложка: всё, что окажется под ней,
                        // на снимок не попадёт — этого мы и добиваемся.
                        child: ColoredBox(color: Color(0xFF101010)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 17));
      }

      late ByteData bytes;
      late int width;
      late int height;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        width = image.width;
        height = image.height;
        bytes = (await image.toByteData())!;
        image.dispose();
      });

      final ratio = width / (cover.width + halo * 2);
      final inner = Rect.fromLTWH(
        halo * ratio,
        halo * ratio,
        cover.width * ratio,
        cover.height * ratio,
      );
      // Считаем не у самого шва: по краю обложки на снимке остаётся полоска
      // сглаживания в пару точек, и она не «искры поверх картинки».
      final artwork = inner.deflate(3);
      var around = 0;
      var over = 0;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final i = (y * width + x) * 4;
          // Обложка залита ровным тёмным, искры — заметно светлее.
          final lit = bytes.getUint8(i) > 90 || bytes.getUint8(i + 1) > 70;
          if (!lit) continue;
          final point = Offset(x + 0.5, y + 0.5);
          if (artwork.contains(point)) {
            over++;
          } else if (!inner.contains(point)) {
            around++;
          }
        }
      }

      // Кайма вокруг обложки — пятнадцать тысяч точек, и треть её должна
      // гореть. С прежней плотностью там едва набиралась сотня: искр
      // «почти совсем не видно» — с этого всё и началось.
      expect(
        around,
        greaterThan(2000),
        reason: 'вокруг обложки почти ничего не горит — искр не видно',
      );
      expect(
        over,
        0,
        reason: 'искры проступают поверх обложки, а должны быть под ней',
      );
    });

    // Тот же урок, что и с волной: рисовальщик пересоздаётся при каждой
    // пересборке плитки, а в библиотеке это происходит на каждом переводе
    // выделения. Начни поток с чистого места — искры вспыхивали бы заново.
    testWidgets('поток переживает пересборку', (tester) async {
      var label = 'первая';
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 100,
              height: 150,
              child: StatefulBuilder(
                builder: (context, setState) => PortalSparks(
                  enabled: true,
                  child: TextButton(
                    onPressed: () => setState(() => label = 'вторая'),
                    child: Text(label),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 17));
      }
      final before = tester
          .state<PortalSparksState>(find.byType(PortalSparks))
          .field
          .time;
      expect(before, greaterThan(0));

      await tester.tap(find.text('первая'));
      await tester.pump(const Duration(milliseconds: 17));

      expect(find.text('вторая'), findsOneWidget);
      // Время потока — не время виджета: обнулись оно, и поток начался бы с
      // чистого места, а искры вспыхнули бы разом.
      expect(
        tester.state<PortalSparksState>(find.byType(PortalSparks)).field.time,
        greaterThan(before),
        reason: 'поток начался заново — искры вспыхнут на ровном месте',
      );
    });
  });
}

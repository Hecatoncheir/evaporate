import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evaporate/ui/library/portal_sparks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// От кромки обложки летит сноп искр, снесённых вбок вращением. Проверять
/// тут надо не красоту, а то, что искры летят свободно,
/// мерцают вразнобой, не растут без предела, не уходят в
/// NaN и переживает возвращение свёрнутого окна одним огромным шагом. Видно
/// ли его вообще — отдельно, по снимку отрисовки.
void main() {
  const size = Size(200, 300);

  PortalSparkField field() => PortalSparkField()..resize(size);

  void run(PortalSparkField field, {int frames = 120, double dt = 1 / 60}) {
    for (var i = 0; i < frames; i++) {
      field.advance(dt);
    }
  }

  group('сноп искр', () {
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

    // Веер должен быть широким: у сварки искры не жмутся к шву, а
    // разлетаются на всю ширину каймы. Разброс скоростей это и даёт.
    test('искры заполняют кайму, а не жмутся к кромке', () {
      final sparks = field();
      run(sparks, frames: 90);

      final far = sparks.sparks
          .where(
            (spark) => !(Offset.zero & size)
                .inflate(PortalSparkField.halo / 2)
                .contains(spark.position),
          )
          .length;
      final near = sparks.sparks
          .where(
            (spark) => (Offset.zero & size).inflate(6).contains(spark.position),
          )
          .length;

      expect(far, greaterThan(0), reason: 'ни одна не долетела до края каймы');
      expect(near, greaterThan(0), reason: 'у кромки пусто — шва не видно');
    });

    test('следы короткие, частицы летят свободно у угла', () {
      final sparks = field();
      final spark = PortalSpark(
        position: const Offset(199, -3),
        velocity: const Offset(120, -20),
        twinkle: 0,
        life: 0.5,
        maxLife: 0.5,
        trail: 0.02,
      );
      sparks.sparks.add(spark);
      sparks.advance(1 / 60);
      expect(spark.position.dx, greaterThan(200));
      expect(spark.position.dy, lessThan(-3));
      expect(spark.velocity.dx, greaterThan(0));
      run(sparks, frames: 40);
      for (final particle in sparks.sparks) {
        expect(
          (sparks.positionOf(particle) - sparks.tailOf(particle)).distance,
          lessThan(6),
        );
      }
    });

    // Искрят, а не горят ровно: у каждой свой сдвиг мерцания, поэтому поле
    // рябит, а не дышит целиком.
    test('искры мерцают вразнобой', () {
      final sparks = field();
      run(sparks, frames: 30);

      final bright = sparks.sparks.map(sparks.brightnessOf).toList();

      expect(bright.every((b) => b >= 0 && b <= 1), isTrue);
      // Разброс яркостей — то самое «искрит».
      expect(
        bright.reduce(math.max) - bright.reduce(math.min),
        greaterThan(0.3),
      );
    });

    // Сопротивление задаёт, куда искра долетит: предел ухода — её скорость,
    // делённая на него. Без предела искры уходили бы к соседним обложкам.
    test('искры остаются в кайме', () {
      final sparks = field();
      run(sparks, frames: 300);

      for (final spark in sparks.sparks) {
        expect(
          (Offset.zero & size)
              .inflate(PortalSparkField.halo)
              .contains(spark.position),
          isTrue,
        );
      }
    });

    // Свёрнутое окно возвращается одним огромным шагом. Без предела искры
    // улетели бы неведомо куда одним кадром.
    test('огромный шаг не рвёт сноп', () {
      final sparks = field();
      run(sparks, frames: 30);

      sparks.advance(5);

      for (final spark in sparks.sparks) {
        expect(spark.position.dx.isFinite, isTrue);
        expect(spark.position.dy.isFinite, isTrue);
        expect(sparks.positionOf(spark).dx.isFinite, isTrue);
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
        reason: 'старые искры остались — сноп перестал сменяться',
      );
    });

    test(
      'невалидный шаг не меняет поток, новый размер очищает старые искры',
      () {
        final sparks = field();
        run(sparks, frames: 40);
        final time = sparks.time;
        final position = sparks.sparks.first.position;
        for (final dt in [double.nan, double.infinity, -1.0, 0.0]) {
          sparks.advance(dt);
        }
        expect(sparks.time, time);
        expect(sparks.sparks.first.position, position);
        sparks.resize(const Size(100, 150));
        expect(sparks.sparks, isEmpty);
        sparks.advance(1 / 60);
        expect(sparks.sparks, isNotEmpty);
      },
    );

    test('без размера ничего не происходит', () {
      final sparks = PortalSparkField();

      run(sparks);

      expect(sparks.sparks, isEmpty);
      expect(sparks.time, 0);
    });
  });

  group('кромка', () {
    test('обходит все четыре стороны', () {
      final sparks = field();

      expect(sparks.edgeAt(0.05).point.dy, 0);
      expect(sparks.edgeAt(0.35).point.dx, size.width);
      expect(sparks.edgeAt(0.6).point.dy, size.height);
      expect(sparks.edgeAt(0.9).point.dx, 0);
    });

    // Доля пути считается по кругу: искра, ушедшая за единицу, срывается с
    // того же места, а не из угла.
    test('путь замыкается', () {
      final sparks = field();

      expect(sparks.edgeAt(1.25).point, sparks.edgeAt(0.25).point);
      expect(sparks.edgeAt(-0.75).point, sparks.edgeAt(0.25).point);
    });

    // Углы. У острого прямоугольника нормаль скачком переходит с одной
    // стороны на другую: по диагонали не летит ничего, и угол выглядит
    // срезанным — это и было видно на плитке. На дуге она поворачивается
    // плавно, и сноп огибает угол.
    test('в углах есть направление по диагонали', () {
      final sparks = field();

      final diagonal = List.generate(400, (i) => sparks.edgeAt(i / 400))
          .where((edge) => edge.outward.dx.abs() > 0.3)
          .where((edge) => edge.outward.dy.abs() > 0.3);

      expect(
        diagonal,
        isNotEmpty,
        reason: 'наружу летят только по сторонам — углы будут срезаны',
      );
    });

    test('кромка нигде не рвётся', () {
      final sparks = field();

      var previous = sparks.edgeAt(0).point;
      for (var i = 1; i <= 400; i++) {
        final point = sparks.edgeAt(i / 400).point;
        // Шаг по периметру — около четверти процента: разрыв был бы кратно
        // больше и выдал бы ошибку в раскладке сторон.
        expect((point - previous).distance, lessThan(8));
        previous = point;
      }
    });

    test('наружу — это наружу, а вдоль перпендикулярно ему', () {
      final sparks = field();

      for (final at in [0.05, 0.35, 0.6, 0.9]) {
        final edge = sparks.edgeAt(at);
        // Скалярное произведение перпендикуляров — ноль.
        expect(
          edge.outward.dx * edge.along.dx + edge.outward.dy * edge.along.dy,
          0,
        );
      }
      expect(sparks.edgeAt(0.05).outward, const Offset(0, -1));
      expect(sparks.edgeAt(0.6).outward, const Offset(0, 1));
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

    testWidgets('включённый рисует слой искр', (tester) async {
      await show(tester, enabled: true);
      await tester.pump(const Duration(milliseconds: 17));

      expect(find.text('обложка'), findsOneWidget);
      expect(find.byKey(const ValueKey('portal-sparks')), findsOneWidget);
    });

    testWidgets('повторное включение запускает свежие искры сразу', (
      tester,
    ) async {
      await show(tester, enabled: true);
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 17));
      }
      final state = tester.state<PortalSparksState>(find.byType(PortalSparks));
      final oldSparks = state.field.sparks.toSet();
      await show(tester, enabled: false);
      expect(state.field.sparks, isEmpty);
      await show(tester, enabled: true);
      await tester.pump(const Duration(milliseconds: 17));
      expect(state.field.sparks, isNotEmpty);
      expect(state.field.sparks.any(oldSparks.contains), isFalse);
    });

    testWidgets(
      'сокращение движения убирает эффект, скрытая вкладка останавливает его',
      (tester) async {
        var reduced = false;
        var visible = true;
        Future<void> render() => tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: TickerMode(
                enabled: visible,
                child: const Center(
                  child: SizedBox(
                    width: 120,
                    height: 180,
                    child: PortalSparks(
                      enabled: true,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await render();
        await tester.pump(const Duration(milliseconds: 170));
        final state = tester.state<PortalSparksState>(
          find.byType(PortalSparks),
        );
        expect(state.field.sparks, isNotEmpty);
        visible = false;
        await render();
        final time = state.field.time;
        await tester.pump(const Duration(seconds: 1));
        expect(state.field.time, time);
        visible = true;
        reduced = true;
        await render();
        expect(find.byKey(const ValueKey('portal-sparks')), findsNothing);
        expect(state.field.sparks, isEmpty);
        reduced = false;
        await render();
        await tester.pump(const Duration(milliseconds: 17));
        expect(state.field.sparks, isNotEmpty);
        expect(tester.takeException(), isNull);
      },
    );

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
      late ByteData reference;
      late int width;
      late int height;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final preview = Platform.environment['PORTAL_PREVIEW'];
        if (preview != null) {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(preview).writeAsBytes(png!.buffer.asUint8List());
        }
        width = image.width;
        height = image.height;
        bytes = (await image.toByteData())!;
        image.dispose();
        final codec = await ui.instantiateImageCodec(
          await File('test/goldens/portal_sparks_reference.png').readAsBytes(),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, width);
        expect(frame.image.height, height);
        reference = (await frame.image.toByteData())!;
        frame.image.dispose();
        codec.dispose();
      });

      // Эталон снят с принятого эффекта до оптимизации. Сравниваем светящиеся
      // пиксели, чтобы пустой чёрный фон не скрыл потерю искр. Небольшой
      // допуск нужен для сглаживания повёрнутых спрайтов и округления длины.
      var colorError = 0;
      var compared = 0;
      for (var i = 0; i < bytes.lengthInBytes; i += 4) {
        if (bytes.getUint8(i) <= 70 && reference.getUint8(i) <= 70) continue;
        for (var channel = 0; channel < 3; channel++) {
          colorError +=
              (bytes.getUint8(i + channel) - reference.getUint8(i + channel))
                  .abs();
          compared++;
        }
      }
      expect(compared, greaterThan(0));
      expect(colorError / compared, lessThan(22.5));

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
      // Ближняя половина каймы и дальняя: у сварки густо у шва и редко по
      // краям, и это видно счётом.
      final near = inner.inflate(halo / 2);
      var around = 0;
      var over = 0;
      var closeIn = 0;
      var farOut = 0;
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
            if (near.contains(point)) {
              closeIn++;
            } else {
              farOut++;
            }
          }
        }
      }

      // Видны отдельные искры с тёмными просветами, а не сплошная
      // пересвеченная рамка. Старая отрисовка зажигала более 8000 пикселей.
      expect(around, inExclusiveRange(500, 6000));
      expect(
        over,
        0,
        reason: 'искры проступают поверх обложки, а должны быть под ней',
      );
      // Половины каймы почти равны по площади, поэтому сравнивать счёт
      // можно прямо: у ровной пелены они сошлись бы.
      expect(
        closeIn,
        greaterThan(farOut * 2),
        reason: 'у кромки должно быть гуще, чем на краю поля',
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

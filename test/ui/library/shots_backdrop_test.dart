import 'dart:io';

import 'package:evaporate/ui/library/shots_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/temp_dir.dart';

/// Подложка из кадров игры под крупной обложкой библиотеки.
///
/// Проверяется не красота, а то, чем она отличается от обычной картинки:
/// кадры есть не у всех игр, ходят по кругу и обязаны замолкать по системной
/// просьбе не двигаться.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late List<String> shots;

  /// Настоящие файлы, а не пути наугад: виджет читает их с диска, и на
  /// выдуманном пути мы бы проверяли только ветку ошибки.
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_shots_');
    shots = [];
    // Однопиксельный PNG: содержимое неважно, важно, что файл читается.
    final png = <int>[
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, //
      0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, //
      0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 250, 207, 0, 0, //
      3, 1, 1, 0, 24, 221, 141, 219, 0, 0, 0, 0, 73, 69, 78, 68, //
      174, 66, 96, 130,
    ];
    for (var i = 0; i < 3; i++) {
      final file = File('${tmp.path}${Platform.pathSeparator}shot$i.png');
      await file.writeAsBytes(png, flush: true);
      shots.add(file.path);
    }
  });

  tearDown(() => deleteTempDir(tmp));

  Widget wrap(Widget child, {bool reduceMotion = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: 400, height: 200, child: child),
    ),
  );

  const fallback = ColoredBox(
    key: ValueKey('fallback'),
    color: Color(0xFF123456),
  );

  testWidgets('без кадров показывается обложка, а не пустое место', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ShotsBackdrop(shots: [], enabled: true, fallback: fallback)),
    );

    expect(find.byKey(const ValueKey('fallback')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('выключенная подложка не трогает кадры вовсе', (tester) async {
    await tester.pumpWidget(
      wrap(ShotsBackdrop(shots: shots, enabled: false, fallback: fallback)),
    );

    expect(find.byKey(const ValueKey('fallback')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  /// Прокручивает часы украшений на [seconds].
  ///
  /// Одним большим `pump` их не проскочить: шаг там ограничен сверху
  /// (1/30 с), чтобы возвращение свёрнутого окна не прыгало на минуту
  /// вперёд, — поэтому время набирается кадрами.
  Future<void> advance(WidgetTester tester, double seconds) async {
    for (var i = 0; i < (seconds * 30).ceil() + 2; i++) {
      await tester.pump(const Duration(milliseconds: 34));
    }
  }

  testWidgets('кадры сменяют друг друга по кругу', (tester) async {
    await tester.pumpWidget(
      wrap(ShotsBackdrop(shots: shots, enabled: true, fallback: fallback)),
    );
    await tester.pump();

    // `cacheWidth` заворачивает источник в ResizeImage — разворачиваем.
    String shown() => _pathOf(tester.widget<Image>(find.byType(Image).first));

    expect(shown(), shots.first);

    // Черёд кадра плюс перетекание: к этому времени первый уже уступил.
    const turn = ShotsBackdrop.hold + ShotsBackdrop.fade;
    await advance(tester, turn);
    expect(shown(), shots[1]);

    // Круг замыкается: после последнего снова первый.
    await advance(tester, turn * 2);
    expect(shown(), shots.first);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('приходящий кадр уже в движении, когда уходит предыдущий', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(ShotsBackdrop(shots: shots, enabled: true, fallback: fallback)),
    );
    await tester.pump();

    // Досюда кадр один: перетекание начинается в хвосте черёда.
    await advance(tester, ShotsBackdrop.hold + 0.3);
    expect(find.byType(Image), findsNWidgets(2));

    // Пока предыдущий ещё виден, следующий обязан уже ехать. Прежде он
    // стоял неподвижно всё перетекание и трогался с места только тогда,
    // когда предыдущий убирали, — эта заминка и была видна.
    final before = _shiftOf(tester, 1);
    await advance(tester, 0.9);
    expect(find.byType(Image), findsNWidgets(2));

    // Сдвиг растёт к нулю: кадр идёт к началу своего черёда и придёт туда
    // ровно к смене — без стыка и без заминки.
    final after = _shiftOf(tester, 1);
    expect(after, greaterThan(before));
    expect(after, lessThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('системная просьба не двигаться останавливает смену кадров', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ShotsBackdrop(shots: shots, enabled: true, fallback: fallback),
        reduceMotion: true,
      ),
    );
    await tester.pump();

    // `cacheWidth` заворачивает источник в ResizeImage — разворачиваем.
    String shown() => _pathOf(tester.widget<Image>(find.byType(Image).first));

    final first = shown();
    const turn = ShotsBackdrop.hold + ShotsBackdrop.fade;
    await advance(tester, turn * 2);

    // Часы остановлены — значит, и кадр остался тем же: движущийся фон
    // мешает ровно тому, кто просил его не двигать.
    expect(shown(), first);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// Путь к файлу за картинкой, сквозь обёртку изменения размера.
String _pathOf(Image image) {
  final provider = image.image;
  final source = provider is ResizeImage ? provider.imageProvider : provider;
  return (source as FileImage).file.path;
}

/// Горизонтальный сдвиг кадра под номером [index], долей его ширины.
double _shiftOf(WidgetTester tester, int index) => tester
    .widgetList<FractionalTranslation>(
      find.ancestor(
        of: find.byType(Image).at(index),
        matching: find.byType(FractionalTranslation),
      ),
    )
    .first
    .translation
    .dx;

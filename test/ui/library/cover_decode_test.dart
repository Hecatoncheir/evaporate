import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/cover/cover_art.dart';
import 'package:evaporate/ui/library/cover/decode_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Обложка расшифровывается под размер показа, а не в полный размер файла.
///
/// 600×900 — около двух мегабайт в памяти, сорок восемь плиток — почти
/// весь кэш картинок, а выбранная человеком 2000×3000 — двадцать три
/// мегабайта одна.
void main() {
  testWidgets('плитка просит ширину своего размера, а не файла', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final game = Game(
      id: 'g',
      title: 'Игра',
      addedAt: DateTime(2026),
      details: const GameDetails(coverPath: '/нет/такой/обложки.png'),
    );

    await tester.pumpWidget(
      hostWidget(
        Center(
          child: SizedBox(
            width: 200,
            height: 300,
            child: CoverArt(game: game, underStrip: false),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image)).image;
    expect(image, isA<ResizeImage>());
    // 200 точек при плотности 2 — 400 пикселей, ступенью в 64 — 448.
    expect((image as ResizeImage).width, 448);
  });

  testWidgets('ширина идёт ступенями и не уходит в бесконечность', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final dpr = MediaQuery.devicePixelRatioOf(context);

    expect(decodeWidth(context, 100) % 64, 0);
    expect(decodeWidth(context, 100), greaterThanOrEqualTo(100 * dpr));
    expect(decodeWidth(context, double.infinity), 1024);
  });
}

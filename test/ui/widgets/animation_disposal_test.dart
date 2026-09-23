import 'package:evaporate/ui/library/rise_in.dart';
import 'package:evaporate/ui/shell/fade_indexed_stack.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Кривые поверх контроллеров освобождаются вместе с виджетом.
///
/// `CurvedAnimation` вешает на свой контроллер слушателя. Заведённая в
/// `build`, она у `FadeIndexedStack` рождалась на каждую пересборку и не
/// освобождалась никогда: контроллер живёт всю сессию, и слушатели на нём
/// копились. У `RiseIn` — та же кривая без `dispose`.
void main() {
  /// Сколько кривых создано и так и не освобождено за время [body].
  Future<int> liveCurves(Future<void> Function() body) async {
    final live = <Object>{};
    void track(ObjectEvent event) {
      if (event.object is! CurvedAnimation) return;
      if (event is ObjectCreated) live.add(event.object);
      if (event is ObjectDisposed) live.remove(event.object);
    }

    FlutterMemoryAllocations.instance.addListener(track);
    try {
      await body();
    } finally {
      FlutterMemoryAllocations.instance.removeListener(track);
    }
    return live.length;
  }

  Widget host(Widget child) => MaterialApp(
    theme: EvaporateTheme.dark(),
    home: Scaffold(body: child),
  );

  testWidgets('смена разделов не оставляет неосвобождённых кривых', (
    tester,
  ) async {
    final left = await liveCurves(() async {
      for (var index = 0; index < 4; index++) {
        await tester.pumpWidget(
          host(
            FadeIndexedStack(
              index: index % 2,
              children: const [Text('первый'), Text('второй')],
            ),
          ),
        );
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
    });

    expect(left, 0);
  });

  testWidgets('плитка, взошедшая и убранная, не оставляет кривой', (
    tester,
  ) async {
    final left = await liveCurves(() async {
      await tester.pumpWidget(
        host(
          const RiseIn(
            delay: Duration(milliseconds: 40),
            child: Text('плитка'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    expect(left, 0);
  });
}

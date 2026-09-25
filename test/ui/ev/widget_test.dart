import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/design/tokens.dart';
import 'package:evaporate/ui/ev/widgets/ev_controls.dart';
import 'package:evaporate/ui/ev/widgets/ev_play_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {EvSkin skin = EvSkin.magma}) => MaterialApp(
  theme: buildEvTheme(skin: skin),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('токены доходят до виджетов через ThemeExtension', (
    tester,
  ) async {
    late EvTheme ev;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            ev = context.ev;
            return const SizedBox();
          },
        ),
      ),
    );
    // Расширение должно находиться: поле с именем `type` когда-то перекрывало
    // ключ ThemeExtension.type и ломало этот поиск.
    expect(ev.colors.hot1, EvColors.magma.hot1);
    expect(
      ev.radii.pill,
      EvRadii.tight.pill,
      reason: 'по умолчанию потолок 8 px',
    );
  });

  testWidgets('облик меняет палитру, не трогая виджеты', (tester) async {
    late EvColors c;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            c = context.evc;
            return const SizedBox();
          },
        ),
        skin: EvSkin.cryo,
      ),
    );
    expect(c.hot1, EvColors.cryo.hot1);
  });

  testWidgets('нажатие не запускает игру — кнопку нужно удержать', (
    tester,
  ) async {
    var launched = 0;
    await tester.pumpWidget(_host(EvPlayButton(onLaunch: () => launched++)));

    // короткое нажатие: заряд не добран
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(EvPlayButton)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(launched, 0, reason: 'защита от случайного старта');

    // удержание дольше 620 мс
    final hold = await tester.startGesture(
      tester.getCenter(find.byType(EvPlayButton)),
    );
    // первый кадр после forward() только заводит тикер: elapsed на нём = 0
    await tester.pump();
    await tester.pump(EvMotion.hold + const Duration(milliseconds: 40));
    expect(launched, 1);
    await hold.up();
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('с выключенным удержанием кнопка срабатывает сразу', (
    tester,
  ) async {
    var launched = 0;
    await tester.pumpWidget(
      _host(EvPlayButton(requireHold: false, onLaunch: () => launched++)),
    );
    await tester.tap(find.byType(EvPlayButton));
    await tester.pump();
    expect(launched, 1);
  });

  // Стекло само по себе не проходит проверку попадания, поэтому нажатие
  // по мелкой кнопке до действия не доходило: она была нарисована, но
  // не работала. Клавиатура — вторая половина той же проверки.
  testWidgets('мелкая кнопка нажимается мышью и с клавиатуры', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _host(EvMiniButton(label: 'Проверить', onPressed: () => pressed++)),
    );
    await tester.tap(find.text('Проверить'));
    await tester.pump();
    expect(pressed, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(pressed, 2);
  });

  testWidgets('без действия мелкая кнопка выпадает из обхода', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EvMiniButton(label: 'Нечего', onPressed: null),
            EvMiniButton(label: 'Можно', onPressed: () => pressed++),
          ],
        ),
      ),
    );
    // Tab пропускает неактивную и встаёт на вторую.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(pressed, 1);

    await tester.tap(find.text('Нечего'));
    await tester.pump();
    expect(pressed, 1, reason: 'нажатие по неактивной ничего не делает');
  });
}

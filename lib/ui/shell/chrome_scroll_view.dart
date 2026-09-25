import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'chrome_overlap.dart';

/// Прокрутка раздела, уходящая под стекло полос каркаса целиком.
///
/// Раздел стоит между полосами (`docs/decisions/0012`), и снятой обрезки
/// прокрутке мало: окно рисует только то, что задевает его самого, и
/// строка, целиком ушедшая за край, под стеклом пропадала рывком — полоса
/// вспыхивала картинкой и тут же гасла. Поэтому окно этой прокрутки
/// выходит за место раздела под обе полосы ([ChromeOverlap]), а содержимое
/// отступает на их высоту: в покое оно начинается там же, где и прежде.
///
/// Подводить к выбранному при этом надо к краю видимого, а не окна: иначе
/// строка, догнанная стрелками или геймпадом, встала бы под полосу. Куда
/// мотать, решает само окно — одним расчётом для фокуса, поля ввода и
/// диктора, — и его ответ здесь сдвинут на полосы (`_RenderChromeViewport`).
/// Почему так, а не проще, — `docs/decisions/0014`.
class ChromeScrollView extends StatelessWidget {
  const ChromeScrollView({
    super.key,
    required this.controller,
    required this.slivers,
  });

  final ScrollController controller;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final overlap = ChromeOverlap.of(context);
    final content = [
      SliverPadding(padding: EdgeInsets.only(top: overlap.top)),
      ...slivers,
      SliverPadding(padding: EdgeInsets.only(bottom: overlap.bottom)),
    ];
    // Нажатия под полосами сюда не доходят: место раздела кончается у их
    // кромки, и там они принадлежат полосам. Обрезки нет и у самого окна:
    // искры и наклон плиток у края страницы уходят под стекло рейла.
    // `Scrollable` здесь вместо `CustomScrollView`: от того нужно было бы
    // одно — своё окно, — а оно и есть `viewportBuilder`.
    //
    // Полоса прокрутки, которую достраивает поведение прокрутки на
    // настольных системах, отступает на отступы `MediaQuery`: без них она
    // растянулась бы на всё окно, и бегунок уходил бы под стекло.
    // Содержимому эти отступы ни к чему — оно отступает само.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: -overlap.top,
          bottom: -overlap.bottom,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.only(
                top: overlap.top,
                bottom: overlap.bottom,
              ),
            ),
            child: Scrollable(
              controller: controller,
              clipBehavior: Clip.none,
              viewportBuilder: (context, offset) => MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: _ChromeViewport(
                  offset: offset,
                  overlap: overlap,
                  slivers: content,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Окно вертикальной прокрутки сверху вниз, без обрезки.
class _ChromeViewport extends Viewport {
  _ChromeViewport({
    required super.offset,
    required this.overlap,
    required super.slivers,
  }) : super(clipBehavior: Clip.none);

  final EdgeInsets overlap;

  @override
  RenderViewport createRenderObject(BuildContext context) =>
      _RenderChromeViewport(
        overlap: overlap,
        crossAxisDirection: Viewport.getDefaultCrossAxisDirection(
          context,
          axisDirection,
        ),
        offset: offset,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderChromeViewport renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    renderObject.overlap = overlap;
  }
}

/// Окно, которое отвечает «куда мотать» с поправкой на полосы.
///
/// Через этот ответ идут все, кто подводит к выбранному: `ensureVisible`
/// фокуса и обхода, `showOnScreen` поля ввода и диктора. Поправить его
/// здесь — значит поправить всех разом, а не каждого по месту.
class _RenderChromeViewport extends RenderViewport {
  _RenderChromeViewport({
    required this.overlap,
    required super.crossAxisDirection,
    required super.offset,
  }) : super(clipBehavior: Clip.none);

  /// Сколько окна закрыто полосами сверху и снизу. Раскладку не меняет —
  /// спрашивают его только в ответе, поэтому и перекладывать нечего.
  EdgeInsets overlap;

  @override
  RevealedOffset getOffsetToReveal(
    RenderObject target,
    double alignment, {
    Rect? rect,
    Axis? axis,
  }) {
    final revealed = super.getOffsetToReveal(
      target,
      alignment,
      rect: rect,
      axis: axis,
    );
    // По чужой оси и у прижатого заголовка (ответ — бесконечность)
    // поправлять нечего.
    if (axis == Axis.horizontal || !revealed.offset.isFinite) return revealed;
    // Доля `alignment` отмеряется в видимом — между полосами, — а не во
    // всём окне: ноль ставит цель под верхней, единица — над нижней.
    final shift = overlap.top - alignment * overlap.vertical;
    return RevealedOffset(
      offset: revealed.offset - shift,
      rect: revealed.rect.shift(Offset(0, shift)),
    );
  }
}

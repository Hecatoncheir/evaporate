import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/guards.dart';
import '../support/text_roles.dart';

/// Облик задаёт тема, а не виджет.
///
/// Разбросанные по виджетам числа расходятся сами собой — тот же довод,
/// которым в `motion.dart` обоснованы токены длительностей, — а ветвление
/// по схеме внутри виджета означает, что третья схема потребовала бы
/// правки каждого из них. Вне файлов темы не должно быть:
///
/// - `isDark` и яркость темы — различие схем записывается данными темы, а
///   не кодом;
/// - `fontSize:` — кегль берётся из ролей типографики;
/// - `Duration(<единицы>: <число>)` — длительность берётся из
///   `context.motion`;
/// - `Radius.circular(<число>)` — радиус берётся из `EvaporateTheme`;
/// - поле страницы 28, предельная ширина 1340, подпись настройки 220,
///   ширины диалогов 460 и 560, ширина обоймы 76, высоты полос 58 и 32,
///   высоты органа 48 и 42 и наименьшая ширина главной клавиши 112 — из
///   `EvaporateLayout`;
/// - промежуток (`SizedBox` с одной шириной или высотой, `spacing` и
///   `runSpacing` переноса и ряда) и поле (`EdgeInsets`) числом — ступенью
///   шкалы `EvaporateSpacing`;
/// - радиус числом в умолчании параметра и в аргументе (`radius:`,
///   `borderRadius:`) — токеном `EvaporateTheme`;
/// - размер значка числом — ступенью `EvaporateIconSize`;
/// - `withValues(alpha: <число>)` и `opacity: <дробь>`, в том числе в ветви
///   условия (`lit ? 0.34 : 0.18`), — прозрачность берётся ступенью
///   `EvaporateAlpha`.
///
/// Списки ниже — известные нарушители на момент введения правила (этап 2
/// первого разбора, `docs/reviews/2026-09-19.md`), с числом вхождений.
/// Пополнять их нельзя; вынесенное —
/// вычёркивать или уменьшать число.
void main() {
  bool isThemeFile(String path) =>
      path.startsWith('lib/ui/theme/') || path == 'lib/ui/theme.dart';

  final sources = dartSources('lib/ui', skip: isThemeFile);

  Iterable<String> count(RegExp pattern) sync* {
    for (final file in sources) {
      final n = pattern.allMatches(file.code).length;
      if (n > 0) yield '${file.path}: $n';
    }
  }

  test('isDark не ветвит виджеты', () {
    expectRatchet(
      found: count(_schemeBranch),
      known: _isDark,
      rule: 'различие схем — поле темы компонента, а не ветвление в виджете',
    );
  });

  test('кегль не задаётся по месту', () {
    expectRatchet(
      found: count(_fontSizeHere),
      known: _fontSize,
      rule: 'кегль — роль типографики темы',
    );
  });

  test('кривые движения интерфейса — токены, а не Curves по месту', () {
    expectRatchet(
      found: count(_curveHere),
      known: _curves,
      rule: 'кривая — EvaporateMotion.ease / enter / exit',
    );
  });

  test('длительности не задаются числом по месту', () {
    expectRatchet(
      found: count(_durationHere),
      known: _durations,
      rule: 'длительность — токен context.motion',
    );
  });

  test('радиусы не задаются числом по месту', () {
    expectRatchet(
      found: count(_radiusHere),
      known: _radii,
      rule: 'радиус — токен EvaporateTheme',
    );
  });

  // Ловит только числа, которые уже были токенами: 28 бывает и отступом
  // сетки, и размытием, и запрет «любого 28» бил бы мимо.
  test('размеры раскладки не задаются числом по месту', () {
    expectRatchet(
      found: count(_layoutHere),
      known: const [],
      rule: 'поля, ширины и высоты полос — постоянные EvaporateLayout',
    );
  });

  // Промежуток — `SizedBox` только с шириной или высотой; поле — число в
  // `EdgeInsets`. `SizedBox` с содержимым задаёт размер, а не отступ, и
  // сюда не попадает.
  test('промежутки и поля — ступени шкалы, а не числа по месту', () {
    expectRatchet(
      found: count(_gapHere),
      known: const [],
      rule: 'промежуток — ступень EvaporateSpacing',
    );
    expectRatchet(
      found: count(_insetsHere),
      known: const [],
      rule: 'поле — ступени EvaporateSpacing в EdgeInsets',
    );
  });

  // Жирность, разрядка и межстрочие по месту — это и было расползание,
  // от которого роли заводили: у подписи «жирнее обычного» набиралось три
  // разных набора. Нужен другой облик — другая роль в `typography.dart`.
  test('роль текста по месту правят только цветом', () {
    expectRatchet(
      found: sources.expand(roleTweaks),
      known: _roleTweaks,
      rule: 'другой облик текста — другая роль в typography.dart',
    );
  });

  test('стиль текста не собирается по месту', () {
    expectRatchet(
      found: sources.expand(inlineTextStyles),
      known: _textStyles,
      rule: 'стиль текста — роль context.text, по месту только цвет',
    );
  });

  test('размер значка — ступень, а не число по месту', () {
    expectRatchet(
      found: count(_iconSizeHere),
      known: _iconSizes,
      rule: 'размер значка — ступень EvaporateIconSize',
    );
  });

  // В списке — художники, у которых прозрачность — часть расчёта
  // анимации (фольга, искры, пульс, график), и подписи поверх обложки.
  test('прозрачность не задаётся числом по месту', () {
    expectRatchet(
      found: count(_alphaHere),
      known: _alphas,
      rule: 'прозрачность — ступень EvaporateAlpha',
    );
  });

  // Прозрачность целого виджета — та же ступень, только `Opacity`, а не
  // цвет. 0 и 1 — «скрыто» и «видно», облика в них нет.
  test('прозрачность виджета не задаётся числом по месту', () {
    expectRatchet(
      found: count(_opacityHere),
      known: const [],
      rule: 'прозрачность — ступень EvaporateAlpha',
    );
  });

  // Промежуток в переносе и столбце — та же ступень, что у `SizedBox`:
  // числом по месту их набралось двадцать с лишним, и страж промежутков
  // видел только `SizedBox`.
  test('промежутки переноса и ряда — ступени шкалы, а не числа', () {
    expectRatchet(
      found: count(_wrapSpacingHere),
      known: const [],
      rule: 'spacing и runSpacing — ступени EvaporateSpacing',
    );
  });

  // Радиус числом в умолчании параметра и в аргументе с именем радиуса —
  // обход стража радиусов: сам `Radius.circular` в виджете стоял с именем
  // поля, а число жило в умолчании.
  test('радиусы не прячутся в умолчаниях и аргументах', () {
    expectRatchet(
      found: count(_radiusParamHere),
      known: const [],
      rule: 'радиус — токен EvaporateTheme',
    );
  });

  // Сломанная регулярка — вечная зелень: страж, который ничего не
  // находит, выглядит ровно как страж, которому нечего найти.
  group('страж ловит нарушение', () {
    final cases = {
      _schemeBranch: (
        catches: [
          'if (isDark) {}',
          'Theme.of(context).brightness == x',
          'Brightness.dark',
        ],
        passes: ['final darkness = 1;'],
      ),
      _fontSizeHere: (
        catches: ['TextStyle(fontSize: 12)', 'fontSize : 9'],
        passes: ['context.text.body'],
      ),
      _curveHere: (
        catches: [
          'curve: Curves.easeOut,',
          'Curves.easeInOutCubic.transform(t)',
        ],
        passes: ['curve: EvaporateMotion.ease,'],
      ),
      _durationHere: (
        catches: [
          'Duration(milliseconds: 200)',
          'Duration(seconds: 2)',
          'Duration(microseconds: 16000)',
          'Duration(minutes: 1)',
        ],
        passes: ['Duration(seconds: seconds)', 'context.motion.fast'],
      ),
      _radiusHere: (
        catches: [
          'BorderRadius.circular(8)',
          'BorderRadius.all(Radius.circular(8))',
          'Radius.circular(12.5)',
        ],
        passes: ['BorderRadius.circular(EvaporateTheme.radiusChip)'],
      ),
      _layoutHere: (
        catches: [
          'EdgeInsets.fromLTRB(28, 0, 28, 0)',
          'BoxConstraints(maxWidth: 1340)',
          'SizedBox(width: 220)',
          'SizedBox(width: 560)',
          'Container(width: 76)',
          'SizedBox(height: 58, child: bar)',
          'Container(height: 32)',
          'minimumSize: const Size(0, 48)',
          'SizedBox(width: 144, height: 42, child: c)',
          'BoxConstraints(minWidth: 112, minHeight: 48)',
        ],
        passes: [
          'SizedBox(width: 2200)',
          'EdgeInsets.fromLTRB(280, 0, 0, 0)',
          'SizedBox(width: 760)',
          'height: 580',
          'static const halo = 48.0;',
          'minimumSize: const Size(0, EvaporateLayout.controlHeight)',
          'height: 480',
        ],
      ),
      _alphaHere: (
        catches: [
          'c.withValues(alpha: 0.4)',
          'c.withValues(alpha: .4)',
          'c.withValues(alpha: lit ? 0.34 : 0.18)',
        ],
        passes: [
          'c.withValues(alpha: EvaporateAlpha.rim)',
          'c.withValues(alpha: lit ? look.haloLit : look.haloRest)',
          'c.withValues(alpha: c.a * math.sin(t))',
          'c.withValues(alpha: widget.fade?.value)',
        ],
      ),
      _gapHere: (
        catches: [
          'const SizedBox(height: 8)',
          'SizedBox(width: 7,)',
          'SizedBox(\n  height: 12.5,\n)',
        ],
        passes: [
          'const SizedBox(height: EvaporateSpacing.gap)',
          'SizedBox(width: 250, child: chip)',
          'SizedBox(height: 0)',
        ],
      ),
      _insetsHere: (
        catches: [
          'EdgeInsets.all(18)',
          'EdgeInsets.fromLTRB(EvaporateLayout.gutter, 20, 0, 0)',
          'EdgeInsets.symmetric(\n  horizontal: EvaporateSpacing.gap,\n  vertical: 9,\n)',
          'EvaporateLayout.inset(top: 24)',
        ],
        passes: [
          'EdgeInsets.all(EvaporateSpacing.card)',
          'EdgeInsets.only(top: 0)',
          'EdgeInsets.zero',
          'EdgeInsets.all(EvaporateLayout.wellInset)',
        ],
      ),
      _iconSizeHere: (
        catches: ['Icon(icon, size: 17)', 'iconSize: 20', 'size:16'],
        passes: [
          'Icon(icon, size: EvaporateIconSize.key)',
          'fontSize: 12',
          'const Size(10, 10)',
        ],
      ),
      _wrapSpacingHere: (
        catches: [
          'Wrap(spacing: 10, children: c)',
          'runSpacing: 8,',
          'Column(spacing: 4)',
        ],
        passes: [
          'spacing: EvaporateSpacing.gap',
          'letterSpacing: 1.4',
          'crossAxisSpacing: 28',
          'spacing: 0,',
        ],
      ),
      _radiusParamHere: (
        catches: [
          'this.radius = 24,',
          'this.borderRadius = 3,',
          'borderRadius: 4,',
          'GlassSurface(radius: 24, child: c)',
          'TonedChip(radius: 4)',
          '{double radius = 8, Widget? child}',
          'Widget child,\n    double cornerRadius = 12,',
        ],
        passes: [
          'this.radius = EvaporateTheme.radiusChip,',
          'blurRadius: 26,',
          'radius: 1.05,',
          'radius: 1,',
          'radius: 0.95,',
          'static const cornerRadius = 16.0;',
          'double _radius = 18;',
          'radius: EvaporateTheme.radiusPanel,',
        ],
      ),
      _opacityHere: (
        catches: [
          'Opacity(opacity: 0.35)',
          'opacity: .5',
          'opacity: enabled ? 1 : 0.45',
        ],
        passes: [
          'Opacity(opacity: 0)',
          'Opacity(opacity: 1)',
          'opacity: EvaporateAlpha.ghost',
          'opacity: shown ? 1 : 0',
        ],
      ),
    };
    for (final MapEntry(key: pattern, value: (:catches, :passes))
        in cases.entries) {
      test(pattern.pattern, () {
        for (final code in catches) {
          expect(pattern.hasMatch(code), isTrue, reason: 'пропустил: $code');
        }
        for (final code in passes) {
          expect(pattern.hasMatch(code), isFalse, reason: 'поймал: $code');
        }
      });
    }
  });

  group('страж ролей ловит нарушение', () {
    SourceFile file(String code) => SourceFile('lib/ui/x.dart', code);

    test('правку роли не цветом', () {
      for (final code in [
        'context.text.caption.copyWith(fontWeight: FontWeight.w600)',
        'text.label.copyWith(\n  color: c,\n  letterSpacing: 0,\n)',
        '(a ? context.text.chip : context.text.caption).copyWith(height: 1)',
      ]) {
        expect(roleTweaks(file(code)), isNotEmpty, reason: 'пропустил: $code');
      }
      for (final code in [
        'context.text.caption.copyWith(color: c)',
        'context.text.note.copyWith(\n  color: a ? b : c,\n)',
        'context.text.caption',
        'decoration.copyWith(border: b)',
      ]) {
        expect(roleTweaks(file(code)), isEmpty, reason: 'поймал: $code');
      }
    });

    test('стиль, собранный по месту', () {
      expect(inlineTextStyles(file('TextStyle(height: 1.5)')), isNotEmpty);
      expect(
        inlineTextStyles(file('const TextStyle(\n  fontSize: 15,\n)')),
        isNotEmpty,
      );
      expect(inlineTextStyles(file('TextStyle(color: c)')), isEmpty);
      expect(
        inlineTextStyles(file('DefaultTextStyle(style: s, child: c)')),
        isEmpty,
      );
    });
  });

  // Расширение, которое есть у одной схемы и нет у другой, молча отдаёт
  // виджету запасное значение, а плавная смена схемы смешивает его с
  // пустотой. Проверяем и сами схемы, и их смесь посередине перехода.
  test('у обеих схем один набор расширений, и он переживает смену', () {
    final dark = EvaporateTheme.dark();
    final light = EvaporateTheme.light();

    expect(dark.extensions.keys.toSet(), light.extensions.keys.toSet());
    final mixed = ThemeData.lerp(dark, light, 0.5);
    expect(mixed.extensions.keys.toSet(), dark.extensions.keys.toSet());
    for (final extension in mixed.extensions.values) {
      expect(
        extension.runtimeType,
        dark.extensions[extension.type]!.runtimeType,
      );
    }
  });
}

/// Ветвление по схеме: `isDark` и то, чем его обходят, — яркость темы.
final _schemeBranch = RegExp(r'\bisDark\b|\.brightness\b|\bBrightness\.');

final _fontSizeHere = RegExp(r'\bfontSize\s*:');

/// Длительность числом в любых единицах: секунды и микросекунды — те же
/// числа по месту, что и миллисекунды. Переменная (`seconds: seconds`) —
/// не облик, а расчёт.
final _durationHere = RegExp(
  r'Duration\(\s*(?:milliseconds|microseconds|seconds|minutes)\s*:\s*\d',
);

/// Кривая из `Curves` по месту: у интерфейса их четыре токена, и
/// разбросанные кривые расходятся так же, как числа длительностей.
final _curveHere = RegExp(r'\bCurves\.\w');

/// Радиус числом — и `BorderRadius.circular(8)`, и
/// `BorderRadius.all(Radius.circular(8))`: второе прежде проходило мимо.
final _radiusHere = RegExp(r'Radius\.circular\(\s*\d');

/// Ловит только числа, которые уже были токенами: 28 бывает и отступом
/// сетки, и размытием, и запрет «любого 28» бил бы мимо.
final _layoutHere = RegExp(
  r'fromLTRB\(\s*28\b|maxWidth:\s*1340\b|width:\s*(76|220|460|560)\b'
  r'|height:\s*(58|32|48|42)\b|minHeight:\s*(48|42)\b|minWidth:\s*112\b'
  r'|Size\(\s*[\w.]+\s*,\s*(48|42)\b',
);

/// Прозрачность числом — и прямо, и в ветви условия (`lit ? 0.34 :
/// 0.18`): второе прежде проходило мимо стража.
final _alphaHere = RegExp(
  r'withValues\(\s*alpha:\s*(?:[^,()]*[?:]\s*)?(?:\d|\.\d)',
);

/// Ненулевое число само по себе, а не часть имени: `12`, `.5`, `12.5`.
const _number = r'(?<![\w.$])(?:0*[1-9]\d*(?:\.\d+)?|0*\.\d*[1-9]\d*)(?![\w.])';

/// Промежуток числом: `SizedBox` только с шириной или только с высотой.
final _gapHere = RegExp(
  [r'SizedBox\(\s*(?:width|height)\s*:\s*', _number, r'\s*,?\s*\)'].join(),
);

/// Поле числом: число внутри `EdgeInsets.…(…)` или `EvaporateLayout.inset`.
/// Ноль — «поля нет», облика в нём нет.
final _insetsHere = RegExp(
  [
    r'(?:EdgeInsets\.(?:all|symmetric|only|fromLTRB)|EvaporateLayout\.inset)',
    r'\([^)]*?',
    _number,
  ].join(),
);

/// Размер значка числом.
final _iconSizeHere = RegExp([r'\b(?:size|iconSize)\s*:\s*', _number].join());

/// `opacity:` дробным числом; 0 и 1 — «скрыто» и «видно», облика в них нет.
final _opacityHere = RegExp(r'\bopacity:\s*(?:[^,()]*[?:]\s*)?0?\.\d*[1-9]');

/// Промежуток переноса и ряда числом; ноль — «без промежутка».
final _wrapSpacingHere = RegExp(
  [r'\b(?:spacing|runSpacing)\s*:\s*', _number].join(),
);

/// Радиус числом в умолчании параметра (полем `this.` или своим типом)
/// или в аргументе `radius:` и `borderRadius:`. Дробные радиусы
/// градиентов (`radius: 1.05`) — не угол панели; приватное поле
/// (`_radius = 18`) — не умолчание.
final _radiusParamHere = RegExp(
  r'this\.\w*[rR]adius\s*=\s*\d'
  r'|[{,]\s*double\??\s+(?:[a-zA-Z]\w*)?[rR]adius\s*=\s*\d'
  r'|\bborderRadius:\s*\d|\bradius:\s*(?:[2-9]|\d{2})',
);

const _isDark = <String>[];

const _fontSize = [
  // Типографика картинки, а не роль: надписи поверх обложки и крупного
  // кадра.
  'lib/ui/library/detail/detail_cover.dart: 1',
  'lib/ui/library/cover/cover_title_plate.dart: 1',
  'lib/ui/library/featured/featured_title.dart: 1',
];

const _durations = [
  // Не моторика, а частота кадров: шестьдесят раз в секунду. При
  // системной просьбе не двигаться набор длительностей обнуляется, а
  // шаг часов обнулять нельзя — делить на него.
  'lib/ui/widgets/frame_step.dart: 1',
  // Путь капли выделения, 460 — между `base` и `slow`, подобран по месту.
  // Просьбу не двигаться капля проверяет сама (`_sync` ставит её на место),
  // поэтому нулевой набор ей не нужен; перевод на ступень поменял бы облик
  // и решается как облик, а не уборкой.
  'lib/ui/widgets/liquid/liquid_selection.dart: 1',
  // Не длительность, а метка: нулевая означает «всход ещё не начинался»,
  // и `_start` по ней отличает первый заход от пересборки.
  'lib/ui/library/rise_in.dart: 1',
];

const _radii = <String>[];

/// Типографика картинки, а не роль — те же места, что в [_fontSize]:
/// надписи поверх обложки и крупного кадра.
const _textStyles = [
  'lib/ui/library/cover/cover_title_plate.dart: 1',
  'lib/ui/library/detail/detail_cover.dart: 1',
  'lib/ui/library/featured/featured_title.dart: 1',
];

/// Описание игры поверх крупного кадра — та же типографика картинки:
/// межстрочие у него своё, под затемнённый кадр.
const _roleTweaks = <String>[];

const _iconSizes = <String>[];

// Не переходы интерфейса, а геометрия украшений: форма капли выбора,
// пробег света и фольга считают положение кривой, а не анимируют переход.
// Токен тут подменил бы рисунок, а не характер движения.
const _curves = [
  'lib/ui/library/effects/foil/foil_motion.dart: 1',
  'lib/ui/library/effects/hero_sweep.dart: 1',
  'lib/ui/library/featured/shots_slideshow.dart: 1',
  'lib/ui/widgets/liquid/liquid_selection_path.dart: 3',
  // Прозрачность нарочно на своей кривой поверх общей: она догоняет
  // смещение, иначе плитка проявлялась бы уже на месте.
  'lib/ui/library/rise_in.dart: 1',
];

const _alphas = [
  'lib/ui/downloads/download_chart.dart: 2',
  'lib/ui/library/featured/featured_actions.dart: 1',
  'lib/ui/library/effects/foil/foil_surface.dart: 2',
  'lib/ui/library/effects/library_atmosphere.dart: 2',
  'lib/ui/library/effects/portal/portal_atlas.dart: 1',
  'lib/ui/widgets/animated_progress.dart: 1',
  'lib/ui/widgets/pulse_dot.dart: 2',
];

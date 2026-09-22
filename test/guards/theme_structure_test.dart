import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/guards.dart';

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
/// - поле страницы 28, предельная ширина 1340, подпись настройки 220 и
///   ширины диалогов 460 и 560 — из `EvaporateLayout`;
/// - `withValues(alpha: <число>)` и `opacity: <дробь>` — прозрачность
///   берётся ступенью `EvaporateAlpha`.
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
        ],
        passes: ['SizedBox(width: 2200)', 'EdgeInsets.fromLTRB(280, 0, 0, 0)'],
      ),
      _alphaHere: (
        catches: ['c.withValues(alpha: 0.4)', 'c.withValues(alpha: .4)'],
        passes: ['c.withValues(alpha: EvaporateAlpha.rim)'],
      ),
      _opacityHere: (
        catches: ['Opacity(opacity: 0.35)', 'opacity: .5'],
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
  r'fromLTRB\(\s*28\b|maxWidth:\s*1340\b|width:\s*(220|460|560)\b',
);

final _alphaHere = RegExp(r'withValues\(\s*alpha:\s*[\d.]');

/// `opacity:` дробным числом; 0 и 1 — «скрыто» и «видно», облика в них нет.
final _opacityHere = RegExp(r'\bopacity:\s*0?\.\d*[1-9]');

const _isDark = <String>[];

const _fontSize = [
  // Типографика картинки, а не роль: надписи поверх обложки и крупного
  // кадра, знак приложения в верхней панели.
  'lib/ui/library/detail/detail_cover.dart: 1',
  'lib/ui/library/cover/cover_title_plate.dart: 1',
  'lib/ui/library/featured/featured_compact_bar.dart: 1',
  'lib/ui/library/featured/featured_poster.dart: 1',
  'lib/ui/shell/top_bar_brand.dart: 1',
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
  'lib/ui/widgets/rise_in.dart: 1',
];

const _radii = <String>[];

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
  'lib/ui/widgets/rise_in.dart: 1',
];

const _alphas = [
  'lib/ui/downloads/download_chart.dart: 2',
  'lib/ui/library/featured/featured_actions.dart: 1',
  'lib/ui/library/featured/playtime_readout.dart: 1',
  'lib/ui/library/effects/foil/foil_surface.dart: 2',
  'lib/ui/library/effects/library_atmosphere.dart: 2',
  'lib/ui/library/effects/portal/portal_atlas.dart: 1',
  'lib/ui/widgets/progress_hatching.dart: 1',
  'lib/ui/widgets/pulse_dot.dart: 2',
];

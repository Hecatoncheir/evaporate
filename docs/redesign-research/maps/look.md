# Сопоставление, линза: Облик: токены, палитра, типографика, радиусы, моушн, иконки — дизайн-система evaporate_design (EvColors Magma/Nebula/Cryo, EvRadii, EvType на google_fonts, EvMotion, EvSpace, SVG-иконки) против темы evaporate (две схемы Арклайт/Картридж в пяти ThemeExtension, 32 роли текста, шкалы EvaporateSpacing/IconSize/Alpha/Layout/Motion, три корпусных радиуса + radiusSelection, вариативные TTF в ассетах, Material Icons) — с учётом стражей theme_structure_test/theme_test/theme_fields_test/color_palette_test/fonts_test и решения 0002.

## Сопоставления

### EvColors — четыре подложки: void/ground #06060A, sub #0A0B11, surface #0E0F16, raised #15161F (tokens.dart:27-37, 64-69)

- **Аналог в evaporate:** EvaporatePalette.background/railBackground/surface/surfaceHigh (palette.dart:41-43, 79; dark: 131-133, 146)
- **Решение:** адаптировать
- **Почему:** Ролей столько же: void→background, sub→railBackground (у Арклайта он и так темнее фона: 0xFF080B0F, palette.dart:146), surface→surface, raised→surfaceHigh. Новые значения ложатся в существующий экземпляр dark, а theme_test меряет текст ровно на трёх подложках background/surface/surfaceHigh (theme_test.dart:61, 71, 82) — четвёртая подложка нового поля не требует.
- **Файлы дизайна:** evaporate_design/lib/design/tokens.dart
- **Файлы evaporate:** lib/ui/theme/palette.dart
- **Стражи:** test/ui/theme/theme_test.dart (контраст на трёх подложках, outline/background в 1.2..6.0), test/ui/theme/hardware_surface_theme_test.dart:48-55 (палитра смешивается по всем полям)

### EvColors — четыре чернила: ink #F2F3F7, ink2 #A8ACBD, ink3 #6E7387, ink4 #464A5C (tokens.dart:42-47; «ink4 ниже 12 px не используется» — tokens.dart:46)

- **Аналог в evaporate:** textPrimary #ECE6D8 / textSecondary #9BA6B2 (palette.dart:144-145); третьего и четвёртого уровня нет — приглушение делают роли note/captionMuted/paragraph (typography.dart:40-65)
- **Решение:** адаптировать
- **Почему:** По WCAG (мой расчёт): ink 17.2:1 на surface — годится в textPrimary (порог 7, theme_test.dart:60-68); ink2 8.47 на surface, 7.97 на raised, 8.96 на void — годится в textSecondary с запасом (порог 4.5, theme_test.dart:70-78) и даже в textPrimary; ink3 4.06 на surface, 3.83 на raised, 4.30 на void — не проходит 4.5 ни на одной подложке; ink4 2.2:1 — непригоден для текста вовсе. Итог: textPrimary = ink, textSecondary = ink2 (или сдвинутый ink3 ≥ #82879D: 5.06 на raised); ink3/ink4 в палитру не заводить — приглушение третьего уровня остаётся ролью, а не цветом.
- **Файлы дизайна:** evaporate_design/lib/design/tokens.dart, evaporate_design/lib/design/typography.dart
- **Файлы evaporate:** lib/ui/theme/palette.dart, lib/ui/theme/typography.dart
- **Стражи:** test/ui/theme/theme_test.dart:60-78 (7.0 / 4.5), test/ui/theme/theme_test.dart:142-151 (textSecondary схем различаются)

### EvColors — акцент hot1 #FF7A18, hot2 #FFC24D, hotDeep #C93A05 и градиент playFill hot2→hot1→hotDeep (tokens.dart:49-52, 119-124)

- **Аналог в evaporate:** primary/primaryFill/onPrimary/glow/depth (palette.dart:46-57, 83-89; dark: primary = primaryFill = glow = 0xFFE9C877, depth прозрачный, 135-137, 149-150); блик клавиши — HardwareSurfaceTheme.keySheen 0.16/0.04 (hardware_surface_theme.dart:94, 111)
- **Решение:** адаптировать
- **Почему:** hot1 как текст даёт 7.33 на surface, 7.75 на void, 6.90 на raised — проходит 4.5, поэтому у Арклайта-Magma primary = primaryFill = hot1 остаётся одним значением, как сейчас у золота; hot2 → glow и heroEyebrow (decor_colors.dart:146); hotDeep → depth («торец под клавишей», сейчас прозрачный ночью) — так низ градиента «Играть» получает своё поле, а не число в виджете. Надпись #170800 на hot1 — 7.51, на hotDeep — 3.82: theme_test проверяет только onPrimary/primaryFill (theme_test.dart:95-97), значит градиент допустим, пока надпись лежит над стопами hot2/hot1, а hotDeep уходит в торец. Сам градиент — данные темы компонента клавиши с двумя экземплярами (у Картриджа «плоский цвет без переходов»), не поле палитры.
- **Файлы дизайна:** evaporate_design/lib/design/tokens.dart, evaporate_design/lib/widgets/ev_play_button.dart
- **Файлы evaporate:** lib/ui/theme/palette.dart, lib/ui/theme/hardware_surface_theme.dart, lib/ui/theme/decor_colors.dart
- **Стражи:** test/ui/theme/theme_test.dart:95-97 (onPrimary на primaryFill ≥ 4.5), test/ui/theme/theme_test.dart:80-90 (primary как текст ≥ 4.5 на трёх подложках), test/ui/theme/hardware_surface_theme_test.dart:22-29 (новое поле материала обязано различаться у схем)

### EvColors.cool #5EE7FF — «только для чисел и графиков, никогда для кнопок» (tokens.dart:54-55; README.md:64)

- **Аналог в evaporate:** accent/accentFill 0xFF49B7E0 — «служебный акцент для текста (скорости, ссылки, готово)» и «для заливок и светодиодов» (palette.dart:59-63, 138-139)
- **Решение:** взять как есть
- **Почему:** Роль совпадает дословно; cool даёт 13.06 на surface — с запасом проходит порог акцента 4.5 (theme_test.dart:80-90). Значение просто подставляется в accent и accentFill Арклайта; у Картриджа остаётся своя пара 0xFF006472/0xFF0090A8 (palette.dart:165-166).
- **Файлы дизайна:** evaporate_design/lib/design/tokens.dart
- **Файлы evaporate:** lib/ui/theme/palette.dart
- **Стражи:** test/ui/theme/theme_test.dart:80-90

### EvColors.arc #A66BFF — «магические состояния» (tokens.dart:57, 115); тон EvBarTone.arc с вшитым 0xFF3A1E63 (ev_surfaces.dart:394)

- **Аналог в evaporate:** Поля нет; фиолетовый живёт только в кольце украшений libraryInkColors 0xFF9A7BD8 (decor_colors.dart:120)
- **Решение:** не брать
- **Почему:** Потребителей в четырёх разделах evaporate у «магического» тона нет (в дизайне он у полосы раздачи и аватаров друзей), а поле палитры без второго читателя противоречит правилу «класс темы на одно поле — церемония без выгоды» (hardware_surface_theme.dart:114-116). Оттенок уже есть в кольце libraryInkColors для переливов фольги.
- **Файлы дизайна:** evaporate_design/lib/design/tokens.dart, evaporate_design/lib/widgets/ev_surfaces.dart
- **Файлы evaporate:** lib/ui/theme/decor_colors.dart
- **Стражи:** test/ui/theme/color_palette_test.dart:8-30 (цвет заводится только в lib/ui/theme/)

### Семантика вне облика: EvColors.ok #3BE39B, warn #FFC24D, bad #FF4D5E — статические константы, одни для всех обликов (tokens.dart:59-62)

- **Аналог в evaporate:** warning (dark 0xFFF2A93B), danger/dangerFill/onDanger (0xFFE96A5C, onDanger 0xFF0A0D11) — поля схемы, у Картриджа свои (palette.dart:65-76, 140-143, 167-170); «готово» движка красится accent (engine_state_color.dart)
- **Решение:** адаптировать
- **Почему:** warn совпадает с hot2 побайтно — в evaporate warning обязан быть своим токеном, проходящим 4.5 (11.9 на surface — проходит). bad как текст — 5.89 на surface, 5.55 на raised (проходит); как заливка требует тёмной надписи: белый на bad даёт 3.24, #0A0D11 — 6.00, то есть onDanger остаётся тёмным, как сейчас у Арклайта (palette.dart:142). ok зелёного поля в палитре нет и заводить не стоит: «готово» уже accent, а полю без второго читателя место в константе.
- **Файлы дизайна:** evaporate_design/lib/design/tokens.dart
- **Файлы evaporate:** lib/ui/theme/palette.dart, lib/ui/downloads/engine_state_color.dart
- **Стражи:** test/ui/theme/theme_test.dart:102-104 (onDanger на dangerFill ≥ 4.5), test/ui/theme/theme_test.dart:80-90 (danger, warning как текст)

### line #22242F (границы 1 px) и lineSoft #191B24 (разделители) (tokens.dart:39-40, 69-70)

- **Аналог в evaporate:** outline 0xFF26303B один; мягкие варианты — ступени EvaporateAlpha (alpha.dart:98-114), например outline .62 в cardTheme (evaporate_theme.dart:164)
- **Решение:** адаптировать
- **Почему:** line/void = 1.31 — укладывается в коридор outline 1.2..6.0 (theme_test.dart:116-124), но на raised даёт 1.17: у evaporate outline измеряется только против background, так что проходит. lineSoft отдельным полем не нужен: разделитель — outline на ступени EvaporateAlpha.soft/subtle, как уже сделано у волосяных черт.
- **Файлы дизайна:** evaporate_design/lib/design/tokens.dart
- **Файлы evaporate:** lib/ui/theme/palette.dart, lib/ui/theme/alpha.dart
- **Стражи:** test/ui/theme/theme_test.dart:116-124, test/guards/theme_structure_test.dart:110, 141-147 (_alphaHere — прозрачность только ступенью)

### Три облика EvSkin magma/nebula/cryo с русскими подписями в enum ('янтарь · плазма'…) и EvAppearance (ChangeNotifier над MaterialApp, пересобирает ThemeData на каждое чтение) (theme.dart:77-87; appearance.dart:9-42)

- **Аналог в evaporate:** AppThemeMode system/light/dark — своя перечислимая без Flutter (app_theme_mode.dart:7), Appearance.themeMode в SettingsBloc (appearance.dart:16-26), переходник в ThemeMode (theme_mode.dart:10-16); экземпляров палитры два — dark/light
- **Решение:** не брать
- **Почему:** В план входит только Magma — как новые значения ночной схемы; Nebula и Cryo меняют лишь hot1/hot2/hotDeep/cool/arc и чернила (tokens.dart:82-116), то есть это не третья схема, а «температура акцента», для которой в evaporate потребовались бы новое поле Appearance с плоским ключом, дополнительные экземпляры всех пяти расширений (evaporate_theme.dart:76) и проверка контраста каждой (у Nebula ink3 4.14, у Cryo 4.03 — тот же провал, что у Magma). Подписи облика — ключи ARB, а не строки в enum (localization_test). ChangeNotifier-облик противоречит «новое состояние — блок» (docs/decisions/0001).
- **Файлы дизайна:** evaporate_design/lib/design/theme.dart, evaporate_design/lib/design/appearance.dart
- **Файлы evaporate:** lib/models/app_theme_mode.dart, lib/models/appearance.dart, lib/ui/theme/theme_mode.dart
- **Стражи:** test/guards/theme_structure_test.dart:307-320 (один набор расширений у схем, переживает lerp), test/guards/localization_test.dart (кириллица в lib/ui), test/models/model_roundtrip_test.dart (плоская запись настроек)

### EvRadii — шесть радиусов r1..r5,pill с тремя потолками tight 3/5/7/8/8/8, soft 6/10/16/22/24/24, full …/999 и переключатель EvGeometry в настройках (tokens.dart:150-204; theme.dart:90-99; README.md:69-89)

- **Аналог в evaporate:** Три корпусных константы radiusPanel 6 / radiusControl 4 / radiusChip 3 «одни на обе схемы» плюс radiusSelection 12 для подложки выбранного (evaporate_theme.dart:33-47); в виджетах 18/13/5/2 употреблений соответственно (grep lib/ui)
- **Решение:** адаптировать
- **Почему:** Берётся только tight как новые значения существующих констант: radiusChip 3 (=r1), radiusControl 5 (=r2), radiusPanel 8 (=r4=r5), radiusSelection 12 остаётся — это подложка evaporate, у дизайна её нет. Переключаемый потолок не брать: радиусы в evaporate нарочно константы, а не тема (evaporate_theme.dart:33-35), переключатель означал бы новое поле Appearance и запись в docs/decisions. Карточный r3=7 — отдельный вопрос: обложка режется radiusControl (cover_frame.dart), а кромка искр считается со скруглением 8 (portal_outline.dart:22) — см. preservedEffects.
- **Файлы дизайна:** evaporate_design/lib/design/tokens.dart, evaporate_design/lib/design/theme.dart
- **Файлы evaporate:** lib/ui/theme/evaporate_theme.dart
- **Стражи:** test/guards/theme_structure_test.dart:78-84, 102 (_radiusHere, список _radii пуст), test/ui/library/portal_sparks_test.dart (golden искр при смене радиуса плитки)

### EvMotion — abstract final class со статикой: easeOut (.16,1,.3,1), ease (.22,.9,.24,1), hover 400, screen 340/screenSettle 440, popover 280, fast 200 (tokens.dart:210-237); просьбу «не двигаться» каждый виджет проверяет сам (ev_play_button.dart:112, ev_glass.dart:145)

- **Аналог в evaporate:** EvaporateMotion — ThemeExtension с одним экземпляром standard (instant 120, fast 200, base 380, slow 760, track 900, stagger 55) и набором still; кривые ease (.16,1,.3,1) = easeOut дизайна побайтно, enter (.22,1,.36,1), exit; context.motion сам отдаёт still при disableAnimations (motion.dart:237-264, 315-322); 55 употреблений context.motion в lib/ui
- **Решение:** оставить evaporate
- **Почему:** Главная кривая уже общая, ступени сводятся: hover 400 → base 380, screen 340/440 → base/slow, popover 280 → base, fast → fast; дизайнерский ease → enter. Своя проверка disableAnimations в каждом виджете — ровно то, от чего evaporate ушёл в context.motion (motion.dart:312-314). План B11 (TODO.md:681-690) сам переводит EvaporateMotion в abstract final class, как у дизайна, — сходятся сами.
- **Файлы дизайна:** evaporate_design/lib/design/tokens.dart
- **Файлы evaporate:** lib/ui/theme/motion.dart
- **Стражи:** test/guards/theme_structure_test.dart:62-76 (_curveHere, _durationHere), test/ui/theme/motion_test.dart, test/ui/theme/theme_fields_test.dart:139-155 (EvaporateMotion среди расширений — править при B11)

### EvMotion.hold 620, ritual 2600, breathe 3600 — тайминги защиты и ритуала, у удержания AnimationBehavior.preserve, чтобы «уменьшить движение» не ужал 620 до 31 мс (tokens.dart:224-234; ev_play_button.dart:72-80)

- **Аналог в evaporate:** Аналога нет: длительности вне темы запрещены (_durationHere), а всё из context.motion обнуляется при still — защиту от случайного запуска обнулять нельзя
- **Решение:** новое
- **Почему:** Если удержание/ритуал войдут в план — это не ступень моторики, а константа поведения: static const в motion.dart (файлы темы страж пропускает — theme_structure_test.dart:34-37), вне набора still, по образцу кривых. Пополнять храповик _durations (theme_structure_test.dart:147-160) новой записью нельзя. Дыхание 3600 — период на часах DecorativeMotion, а не Duration.
- **Файлы дизайна:** evaporate_design/lib/design/tokens.dart, evaporate_design/lib/widgets/ev_play_button.dart
- **Файлы evaporate:** lib/ui/theme/motion.dart
- **Стражи:** test/guards/theme_structure_test.dart:70-76, 147-160 (_durations — храповик), test/ui/theme/motion_test.dart:26 (still не двигается вовсе)

### EvSpace — xs 4, s 8, m 12, l 16, xl 24, xxl 32, gutter 28, плавный gutterFor 16..44, каркас railWidth 76 / topBar 58 / hints 32 / bottomNav 60 / narrow 760 (tokens.dart:245-275)

- **Аналог в evaporate:** EvaporateSpacing 12 ступеней 2..32 (spacing.dart:19-56, 287 употреблений), EvaporateLayout gutter 28, contentMaxWidth 1340, wellInset 3, topBar 64 / rail 48 / footer 40 (layout.dart:142-198)
- **Решение:** оставить evaporate
- **Почему:** Все шесть ступеней дизайна лежат на шкале evaporate (4=line, 8=gap, 12=field, 16=panel, 24=wide, 32=vast, 28=gutter) — конфликта нет, а числа по месту в виджетах дизайна (padding 18, 9/4, 13/13, 11) при переносе сводятся к соседней ступени, как делалось при введении шкалы (spacing.dart:6-9). Плавное поле gutterFor и высоты каркаса — вопрос раскладки, а не токенов; если каркас сменится, gutterFor ложится статической функцией в layout.dart (файл темы, страж не считает).
- **Файлы дизайна:** evaporate_design/lib/design/tokens.dart
- **Файлы evaporate:** lib/ui/theme/spacing.dart, lib/ui/theme/layout.dart
- **Стражи:** test/guards/theme_structure_test.dart:88-110, 116-128 (_layoutHere, _gapHere, _insetsHere — списки пусты)

### EvType — роли: display Unbounded w300 fluid clamp(34,5.4vw,68)/0.94 с отрицательной разрядкой, section Unbounded 13 w600 капс ls 2.6, title Onest 15 w500, body 14/1.5 ink2, bodySmall 12.5 ink3, label JBM 10.5 w500 ls 2.1 ink4, data JBM 11.5 tabular ink3, big Unbounded w300 tabular (typography.dart:74-145; README.md:34-35)

- **Аналог в evaporate:** EvaporateTypography — 32 роли, производное от палитры, не ThemeExtension (typography.dart:24-27, 182-184): body 13, note 12.5, label mono 9 w700 ls 1.4, readout mono 14 w700 / readoutLarge 21, path mono 12, figure mono 12 w700 tabular, title 17, subtitle 15, pageTitle 24, keycap Unbounded 13 w800; заголовки textTheme — Unbounded w800 с положительным разрядом 1.2…0.5 (evaporate_theme.dart:125-154)
- **Решение:** адаптировать
- **Почему:** Шкалу дизайна вливать в существующие роли, а не заводить рядом вторую: title 15 → subtitle 15, data 11.5 tabular → figure/captionMuted, section → label (капс с разрядкой), big → readoutLarge, display → textTheme. Три расхождения решаются в typography.dart и только там: (а) кегль строки 14 против 13 — влияет на высоту всех списков и на страж «первый ряд обложек в 1280×900» (section_layout_test); (б) характер показаний — у дизайна Unbounded w300, у evaporate mono w700; (в) плавный кегль героя — только числом по месту, в evaporate это единственные исключения _fontSize (featured_title.dart:23-37). Разрядка заголовков у дизайна отрицательная, у evaporate нарочно положительная (evaporate_theme.dart:141-143). Согласовать с B10 (TODO.md:672-680): ролей должно стать меньше, а не больше.
- **Файлы дизайна:** evaporate_design/lib/design/typography.dart
- **Файлы evaporate:** lib/ui/theme/typography.dart, lib/ui/theme/evaporate_theme.dart, lib/ui/library/featured/featured_title.dart
- **Стражи:** test/guards/theme_structure_test.dart:54-60, 115-129, 138-145, 166-175 (_fontSize, _textStyles, _roleTweaks — храповики), test/ui/shell/section_layout_test.dart (первый ряд обложек в 1280×900), test/support/text_roles.dart

### EvType.ui/dsp/mono — фабрики перевзвешивания: copyWith(fontWeight) под google_fonts начертания не меняет, пакет кладёт fontFamily 'Onest_500' (typography.dart:19-71); EvSegmented перемеряет сегменты по systemFonts после догрузки шрифта

- **Аналог в evaporate:** Вариативные TTF слушаются fontWeight напрямую — fonts_test меряет ширину w800 > w300 у Unbounded и Golos Text (fonts_test.dart:285-313)
- **Решение:** не брать
- **Почему:** Обвязка нужна только пакету google_fonts; с локальными вариативными файлами вес меняется обычным TextStyle(fontWeight:), что и проверяет тест. Слушатель systemFonts тоже лишний — шрифты лежат в сборке и не догружаются.
- **Файлы дизайна:** evaporate_design/lib/design/typography.dart, evaporate_design/lib/widgets/ev_controls.dart
- **Файлы evaporate:** test/ui/theme/fonts_test.dart
- **Стражи:** test/ui/theme/fonts_test.dart:285-313

### Onest через google_fonts ^8.2.1 — сетевая догрузка, секция fonts: закомментирована, GoogleFonts.config нигде не задан (pubspec.yaml:37, 89-100; grep lib/test пуст)

- **Аналог в evaporate:** Golos Text — assets/fonts/GolosText.ttf, вариативный, с OFL-GolosText.txt рядом (pubspec.yaml:98-107; ls assets/fonts); имя зашито в EvaporateTheme.fontFamily и в fonts_test (evaporate_theme.dart:20-23; fonts_test.dart:352)
- **Решение:** оставить evaporate
- **Почему:** Оба — гротески с родной кириллицей; смена семейства не даёт того, ради чего затевается редизайн, а стоит новой зависимости с сетью на первом кадре и правки двух тестов. Если владелец всё же захочет Onest — только бандлом: вариативный TTF + OFL-Onest.txt (font_licenses_test.dart:28-33 требует файл OFL-<имя>.txt с текстом лицензии), правка fontFamily и fonts_test:352, перепроверка ширин в section_layout_test; google_fonts не подключать.
- **Файлы дизайна:** evaporate_design/pubspec.yaml, evaporate_design/lib/design/typography.dart
- **Файлы evaporate:** pubspec.yaml, lib/ui/theme/evaporate_theme.dart, test/tool/font_licenses_test.dart
- **Стражи:** test/ui/theme/fonts_test.dart:351-355, test/tool/font_licenses_test.dart

### Unbounded (дисплей, 300/600/800) и JetBrains Mono (данные, 400/500) через google_fonts (README.md:28-32; typography.dart:74, 120)

- **Аналог в evaporate:** Те же семейства из assets/fonts/Unbounded.ttf и JetBrainsMono.ttf, вариативные (pubspec.yaml:98-107); displayFontFamily/monoFontFamily (evaporate_theme.dart:28-31)
- **Решение:** взять как есть
- **Почему:** Семейства совпадают, файлы уже в сборке с лицензиями. Разница только в начертании: дизайн ставит Unbounded w300 на герое и крупных числах, evaporate — w800; вариативный файл покрывает оба, выбор веса — правка роли в typography.dart, не шрифта.
- **Файлы дизайна:** evaporate_design/lib/design/typography.dart
- **Файлы evaporate:** pubspec.yaml, lib/ui/theme/evaporate_theme.dart
- **Стражи:** test/ui/theme/fonts_test.dart:276-280, 359-364

### EvTheme — единственный ThemeExtension с полями colors/radii/text и доступом context.ev/evc/evr/evt через `!` (theme.dart:11-29, 142-151)

- **Аналог в evaporate:** Пять расширений — EvaporatePalette, EvaporateMotion, HardwareSurfaceTheme, GlassSurfaceTheme, EffectsPalette (evaporate_theme.dart:76) — плюс производные EvaporateTypography/EvaporateButtons; доступ context.colors/text/motion/buttons с запасным dark без расширения (evaporate_theme.dart:11-14; theme_test.dart:203-217)
- **Решение:** оставить evaporate
- **Почему:** Структура закреплена решением 0002 (примитивы → семантика → тема компонента, расширение, а не наследник) и стражами theme_fields_test (lerp собирает каждое поле, values перечисляет все — theme_fields_test.dart:157-167) и theme_structure_test:307-320. Единый мешок дизайна — шаг назад к «шести полям в общем расширении», от чего HardwareSurfaceTheme был разделён на GlassSurfaceTheme (glass_surface_theme.dart:8-11). Значения дизайна переносятся по полям существующих расширений.
- **Файлы дизайна:** evaporate_design/lib/design/theme.dart
- **Файлы evaporate:** lib/ui/theme/evaporate_theme.dart, docs/decisions/0002-theme-in-three-tiers.md
- **Стражи:** test/ui/theme/theme_fields_test.dart, test/guards/theme_structure_test.dart:307-320

### Тени и свечение как геттеры EvTheme: shadowRest 0x8C000000 blur 30 offset 14, shadowLift 0xB3000000 blur 54 offset 26, glow(c, .3, 42), panelFill белый 3 %→0.6 % (theme.dart:32-55; README.md:86-87)

- **Аналог в evaporate:** HardwareSurfaceTheme.shadow 0x8C000000, frameShadowBlur 34 / frameShadowDrop 14, railShadow 22/10 у Арклайта; 0x578A8574 и 12/3 у Картриджа (hardware_surface_theme.dart:84-115); palette.glow (цвет, днём прозрачный — palette.dart:83-85); GlassSurfaceTheme sheenTop/Bottom (glass_surface_theme.dart:37-51)
- **Решение:** адаптировать
- **Почему:** Тень покоя у обоих уже одинакова (0x8C, сдвиг 14; размытие 30 против 34) — брать нечего. Тень поднятого (54/26) и сила ореола (.3/42) — новые поля материала, у которых Картридж обязан иметь своё значение (hardware_surface_theme_test.dart:22-29: схемы различаются в каждом поле) и которые надо вписать в lerp/values/copyWith (theme_fields_test). panelFill — это sheen стекла, поля уже есть.
- **Файлы дизайна:** evaporate_design/lib/design/theme.dart
- **Файлы evaporate:** lib/ui/theme/hardware_surface_theme.dart, lib/ui/theme/glass_surface_theme.dart, lib/ui/theme/palette.dart
- **Стражи:** test/ui/theme/hardware_surface_theme_test.dart:11-44, test/ui/theme/theme_fields_test.dart:157-167

### buildEvTheme: только Brightness.dark, colorScheme(primary hot1, onPrimary #170800, secondary cool, error bad), scrollbarTheme 6/9 px line/ink4 с радиусом r4, textSelectionTheme hot2 / hot1 .32 (theme.dart:101-140)

- **Аналог в evaporate:** EvaporateTheme._build для dark и light: colorScheme(primary: primaryFill — «Material красит им фон кнопки, а не набирает текст», evaporate_theme.dart:106-120), card/input/button/rail/segmented/dialog/snackBar/tooltip темы (75-103); scrollbarTheme и textSelectionTheme не заданы
- **Решение:** адаптировать
- **Почему:** Две недостающие темы компонентов (полоса прокрутки, выделение текста) добавить в _build от токенов палитры, чтобы работали на обеих схемах; числа 6/9 — константы в файле темы (страж туда не смотрит). colorScheme дизайна повторяет уже принятое у evaporate (primary = заливка), брать нечего; Brightness.dark-только — не переносится.
- **Файлы дизайна:** evaporate_design/lib/design/theme.dart
- **Файлы evaporate:** lib/ui/theme/evaporate_theme.dart
- **Стражи:** test/ui/theme/theme_test.dart:161-182 (тема отдаёт палитру), test/guards/theme_structure_test.dart:307-320

### SVG-иконки: 39 контуров на сетке 24, обводка 1.5, скруглённые концы, stroke=currentColor, сплошные только play/pause (build_assets.py:67-71, 98-101; ls design/assets/icons — 39, README.md:18 обещает 34); EvIcon через flutter_svg ^2.3.0 с size по умолчанию 18, цвет из DefaultTextStyle через ColorFilter, а не IconTheme (ev_icon.dart:244-260); размеры по месту — десять разных (12, 13, 14, 15, 16, 17, 18, 19, 22, 24)

- **Аналог в evaporate:** Material Icons: uses-material-design (pubspec.yaml:83), 95 разных значков в 144 местах lib/ui; разделы — grid_view_outlined/download_rounded/save_rounded/settings_rounded (navigation.dart:54-57), главное действие — play_arrow_rounded/stop_circle_outlined/pause_rounded (primary_action.dart:60-63); размеры — шесть ступеней EvaporateIconSize (icon_size.dart:65-84), на клавишах iconSize из тем клавиш (evaporate_theme.dart:187-229)
- **Решение:** адаптировать
- **Почему:** flutter_svg — новая зависимость с решением в docs/decisions и регистраторами плагинов в linux/windows/macos; ColorFilter от DefaultTextStyle идёт мимо IconTheme и тем клавиш, а десять размеров по месту упрутся в _iconSizeHere (theme_structure_test.dart:131-137, список из одной записи). Первым этапом — Material по смыслу (library→grid_view_outlined и т. д., как уже сделано), приборный стиль тонкой обводки даёт семейство *_outlined. Вторым, по желанию, — собрать 39 SVG в иконочный шрифт (IconData, без зависимости в рантайме): цвет через IconTheme, размер — ступенью, стиль дизайна сохраняется.
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_icon.dart, evaporate_design/design/build_assets.py, evaporate_design/pubspec.yaml
- **Файлы evaporate:** lib/ui/theme/icon_size.dart, lib/ui/shell/navigation.dart, lib/ui/library/primary_action.dart, pubspec.yaml
- **Стражи:** test/guards/theme_structure_test.dart:131-137, 177-181 (_iconSizeHere, _iconSizes), test/guards/layering_test.dart (новый пакет), CI: git diff --exit-code linux windows macos (регистраторы плагинов)

### Знак «Отдушина» и 10 логотипов SVG (mark-a-vent, appicon-a…d, mark-mono, favicon, lockup×2), EvMark 36 pt через flutter_svg (build_assets.py:39-64; ev_icon.dart:265-276; README.md:2092-2109)

- **Аналог в evaporate:** assets/branding/app_icon.png 30 pt в TopBarBrand (top_bar_brand.dart:66-67) и генератор иконок tool/make_icon.py (CLAUDE.md, «перерисовать иконки»)
- **Решение:** адаптировать
- **Почему:** Знак в интерфейсе стоит в одном месте и одном размере, для него растр достаточен: новый знак экспортируется PNG в assets/branding через make_icon.py (там же .ico и набор macOS), SVG-рендер в рантайме не нужен. Правило знака «только на тёмной подложке» (README.md:2096) на Картридже требует варианта mark-mono-dark — он в наборе есть.
- **Файлы дизайна:** evaporate_design/design/build_assets.py, evaporate_design/lib/widgets/ev_icon.dart
- **Файлы evaporate:** lib/ui/shell/top_bar_brand.dart, tool/make_icon.py
- **Стражи:** test/guards/theme_structure_test.dart:138-145, 177-181 (top_bar_brand — записи _fontSize/_textStyles/_iconSizes: файл нельзя переименовать, не поправив списки)

### Числа облика по месту в виджетах дизайна вне lib/design: fontSize 158, Duration(milliseconds:) 39, BorderRadius.circular 38, Curves.* 12, withValues(alpha:) 204, Color(0x…) 107 (grep lib без lib/design), вшитые цвета в ev_play_button.dart:325-332, ev_surfaces.dart:391-394, ev_glass.dart:175

- **Аналог в evaporate:** Страж темы: списки _isDark/_radii/раскладки/промежутков пусты, остальные — храповики с числом; цвета только в lib/ui/theme/ (color_palette_test.dart:8-30)
- **Решение:** адаптировать
- **Почему:** Ни один файл дизайна не переносится копированием: каждое число становится ступенью (EvaporateSpacing/Alpha/IconSize), ролью (typography.dart), токеном (context.motion, EvaporateTheme.radius*) или полем темы компонента с двумя экземплярами. Это не косметика, а условие зелёных ворот: первый же непереписанный файл валит четыре стража разом.
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_surfaces.dart, evaporate_design/lib/widgets/ev_play_button.dart, evaporate_design/lib/glass/ev_glass.dart
- **Файлы evaporate:** test/guards/theme_structure_test.dart, test/ui/theme/color_palette_test.dart
- **Стражи:** test/guards/theme_structure_test.dart (все двенадцать проверок), test/ui/theme/color_palette_test.dart:8-30, test/support/text_roles.dart

### Материалы стекла числами: frost blur 22 / sat 1.6 / bright .68 / tintAlpha .62 / rimKey .4; raised 30/.72/.3; lens 6/.42/.62 bevel 13 depth 8; droplet и chip blur 0 / tint .22 (glass_style.dart:100-191); цвет блика кромки — lerp(white, hot2, .28) по месту (ev_glass.dart:175)

- **Аналог в evaporate:** GlassSurfaceTheme — fillOpacity, sheenTop/Bottom, rimOpacity, counterLightOpacity; arclight .9/null/.62/.15/.05, cartridge .94/.98/.72/.32/.16 (glass_surface_theme.dart:13-51); размытие 16 в GlassSurface
- **Решение:** адаптировать
- **Почему:** По линзе облика важно одно: числа материалов — это поля GlassSurfaceTheme (и, при надобности, второго расширения для линзы), с обязательным отличием у Картриджа в каждом поле (hardware_surface_theme_test.dart:33-44); цвет блика — из палитры (glow/primary), не lerp белого по месту. Дизайн тёмный-только, дневные значения материалов придётся подбирать заново.
- **Файлы дизайна:** evaporate_design/lib/glass/glass_style.dart, evaporate_design/lib/glass/ev_glass.dart
- **Файлы evaporate:** lib/ui/theme/glass_surface_theme.dart
- **Стражи:** test/ui/theme/hardware_surface_theme_test.dart:33-44, test/ui/theme/theme_fields_test.dart

### EvAvatarTint hot/cool/arc/ok/rose/sky — оттенки аватаров друзей (tokens.dart:239-243)

- **Аналог в evaporate:** Нет; ближайшее — gameAmbientColors по шести якорям ambientHues для света игры (decor_colors.dart:179-199)
- **Решение:** не брать
- **Почему:** Раздел «Друзья» в объём не входит; двух оттенков (rose, sky) нет ни в одной палитре дизайна — они заведены только «чтобы шесть кружков различались» (tokens.dart:240-242).
- **Файлы дизайна:** evaporate_design/lib/design/tokens.dart
- **Файлы evaporate:** 
- **Стражи:** 

## Конфликты

### Одна тёмная тема с тремя «температурами» против двух самостоятельных схем с WCAG-тестом на каждую

- **Дизайн:** «Тема одна — тёмная, по требованию продукта» (theme.dart:6; README.md:7); облики Magma/Nebula/Cryo — «одинаковая земля, разная температура источника света», переключаются EvSkin в настройках (theme.dart:75-87); buildEvTheme всегда Brightness.dark (theme.dart:109). Светлых значений нет ни для одного токена.
- **Evaporate:** Две схемы — «два самостоятельных облика, а не одна палитра с вывернутой яркостью» (palette.dart:9-13); у dark() и light() один набор из пяти расширений, переживающий ThemeData.lerp (evaporate_theme.dart:49-61, 76; theme_structure_test.dart:307-320); материал и стекло обязаны различаться у схем в каждом поле (hardware_surface_theme_test.dart:22-29, 33-44); акценты схем разные (theme_test.dart:142-151); третья схема = третий экземпляр, а не наследник (docs/decisions/0002).
- **Рекомендация:** Не выбирать между ними: Magma становится новыми значениями ночной схемы (тот же экземпляр EvaporatePalette.dark и arclight-экземпляры остальных четырёх расширений), Картридж остаётся дневной схемой без правок в первом этапе — его контраст уже выверен. Nebula/Cryo в план не включать: это не схемы, а «температура акцента» (меняются hot1/hot2/hotDeep/cool/arc и чернила — tokens.dart:82-116), и если она понадобится, то как отдельное поле Appearance с плоским ключом и как дополнительные экземпляры всех пяти расширений с контрастом под theme_test, а не enum со строками. Совместимо с 0002 (значения меняются, ярусы нет) и со стражем «один набор расширений».

### Onest против Golos Text и google_fonts против локальных ассетов

- **Дизайн:** Интерфейсное семейство — Onest 300–700 через GoogleFonts.onest (README.md:31, 129; typography.dart:2, 95-117); секция fonts в pubspec закомментирована, GoogleFonts.config не задан — шрифты приходят из сети после первого кадра, поэтому EvSegmented перемеряет себя по systemFonts, а вес меняется только повторным вызовом фабрики (typography.dart:19-27).
- **Evaporate:** Три вариативных TTF в assets/fonts с OFL-файлами рядом (pubspec.yaml:98-107); fonts_test грузит их руками и требует, чтобы w800 был шире w300 (fonts_test.dart:285-313), а имена семейств зашиты (fonts_test.dart:351-355); font_licenses_test требует OFL-<имя>.txt у каждого .ttf (font_licenses_test.dart:28-33). Golos Text выбран за одинаковый ритм латиницы и кириллицы в путях и названиях (evaporate_theme.dart:20-23).
- **Рекомендация:** Оставить Golos Text и локальные ассеты; google_fonts не подключать ни в каком варианте (сеть на старте, начертания-подделки, лишняя зависимость под решение). Unbounded и JetBrains Mono совпадают и уже в сборке. Если владелец захочет именно Onest — бандлить вариативный TTF + OFL-Onest.txt, поменять EvaporateTheme.fontFamily и fonts_test:352, перепроверить section_layout_test (ширины строк) — и это отдельный пункт плана, а не часть переноса токенов.

### Потолок радиуса 8 (переключаемый) против трёх корпусных радиусов темы

- **Дизайн:** Шесть радиусов r1..r5,pill с тремя потолками — tight 3/5/7/8/8/8 по умолчанию, soft и full со стадионами 999 — и переключатель EvGeometry «8 px · 24 px · Полный» в настройках; тест закрепляет потолок 8 по умолчанию (tokens.dart:150-204; theme.dart:90-99; widget_test.dart:33-37).
- **Evaporate:** Три константы radiusPanel 6 / radiusControl 4 / radiusChip 3, «малые и одни на обе схемы: разные углы читались бы как два разных приложения» (evaporate_theme.dart:33-38), плюс radiusSelection 12 для подложки выбранного (evaporate_theme.dart:40-47); Radius.circular(<число>) вне темы запрещён с пустым списком нарушителей (theme_structure_test.dart:78-84, 102, 162).
- **Рекомендация:** Взять только значения tight в три существующие константы: radiusChip 3, radiusControl 5, radiusPanel 8 (r4 и r5 у tight равны, герой и панель — одно число); radiusSelection 12 оставить — у дизайна такой подложки нет. Переключатель потолка не заводить: он противоречит «одни на обе схемы», требует поля Appearance и записи в docs/decisions, а по README заметен только на объектах крупнее 16 pt (README.md:76-78). Карточный r3=7 решить вместе с эффектами: обложка сейчас режется radiusControl, а кромка искр считает скругление 8 (portal_outline.dart:22) — при любом новом радиусе плитки эти два числа обязаны совпасть, иначе golden искр поедет.

### SVG-иконки и flutter_svg против Material Icons и стражей зависимостей/значков

- **Дизайн:** 39 контуров на сетке 24, обводка 1.5, только окружности/дуги/прямые, currentColor, сплошные лишь play/pause (build_assets.py:67-101; ev_icon.dart:236-241); рисуются flutter_svg из design/assets с ColorFilter от DefaultTextStyle (ev_icon.dart:253-258); «иконки не перерисовывались — один источник правды» (README.md:598-600); размер — числом по месту, десять разных значений.
- **Evaporate:** Material Icons с uses-material-design (pubspec.yaml:83): 95 разных значков в 144 местах; размер только ступенью EvaporateIconSize (icon_size.dart:57-84), у клавиш — из темы (evaporate_theme.dart:187-229), _iconSizeHere с единственной записью (theme_structure_test.dart:131-137, 177-181); новая зависимость — issue и решение, регистраторы плагинов коммитятся вместе (CLAUDE.md).
- **Рекомендация:** Первый этап — Material Icons, сопоставленные по смыслу с набором дизайна (у разделов и главного действия это уже сделано: navigation.dart:54-57, primary_action.dart:60-63); тонкая обводка дизайна ближе всего к семейству *_outlined. Второй этап, если стиль важен, — иконочный шрифт, собранный из тех же 39 SVG (IconData вместо SvgPicture): цвет наследуется из IconTheme и тем клавиш, размер — ступенью, рантайм без flutter_svg, лицензия — своя. flutter_svg не брать: ColorFilter мимо IconTheme, десять размеров по месту, нативные регистраторы и решение ради одной библиотеки. Знак — PNG через make_icon.py, как сейчас.

### Дизайнерские hex-цвета против порогов контраста 4.5/7

- **Дизайн:** Таблица токенов без проверки контраста (README.md:41-60); ink3 «подписи, минимум 12 px», ink4 «метки, неактивное, ниже 12 px не используется» (tokens.dart:46; README.md:51-52) — при этом роль label набрана 10.5 pt цветом ink4 (typography.dart:120-125), bodySmall и data — ink3 (typography.dart:112-133); playFill кладёт надпись на градиент до hotDeep (tokens.dart:119-124).
- **Evaporate:** theme_test: textPrimary ≥ 7.0 и textSecondary ≥ 4.5 на background/surface/surfaceHigh (theme_test.dart:60-78), primary/accent/danger/warning ≥ 4.5 как текст (80-90), onPrimary на primaryFill и onDanger на dangerFill ≥ 4.5 (95-104), onSelection на selection > 7 (38-43), outline/background в 1.2..6.0 (116-124); «часть палитры отклонена от исходных значений именно им» (CLAUDE.md).
- **Рекомендация:** Расчёт по формуле WCAG (относительная яркость sRGB, (L1+0.05)/(L2+0.05)): ink3 #6E7387 на surface #0E0F16 = 4.06 — не проходит 4.5 (и 7 тем более); ink2 #A8ACBD на void #06060A = 8.96 — проходит и 4.5, и 7. Остальное: ink2 на surface 8.47, на raised 7.97; ink3 на void 4.30, на raised 3.83; ink4 2.2–2.3; ink 17.2; hot1 7.33/7.75/6.90; hot2 11.9; cool 13.1; bad 5.89 (как текст) и 3.24 под белым / 6.00 под #0A0D11 (как заливка); #170800 на hot1 7.51, на hotDeep 3.82; line на void 1.31. Итог для палитры: textPrimary = ink, textSecondary = ink2 (или ink3, поднятый до ≥ #82879D: 5.06 на raised); ink4 текстом не набирать вовсе; primary = primaryFill = hot1; onPrimary тёмный; dangerFill = bad с тёмным onDanger; hotDeep — только в торец/низ градиента, не под надпись. Nebula (ink3 4.14) и Cryo (ink3 4.03) провалили бы тот же тест.

### Моушн: статика с геймплейными таймингами против ThemeExtension с набором still

- **Дизайн:** EvMotion — abstract final class: две кривые и восемь длительностей, среди них hold 620 (защита от случайного запуска, AnimationBehavior.preserve, чтобы «уменьшить движение» не ужал до 31 мс), ritual 2600, breathe 3600 (tokens.dart:210-237; ev_play_button.dart:72-80); просьбу не двигаться каждый виджет проверяет сам (ev_play_button.dart:112, ev_glass.dart:145).
- **Evaporate:** EvaporateMotion — ThemeExtension с одним экземпляром standard и набором still, который context.motion отдаёт при disableAnimations, «проверять просьбу в каждом виджете значило бы однажды забыть» (motion.dart:255-264, 312-322); Duration числом вне темы — храповик из трёх записей (theme_structure_test.dart:147-160); B11 планирует сделать EvaporateMotion abstract final class, как EvaporateSpacing (TODO.md:681-690).
- **Рекомендация:** Ступени оставить evaporate-овские (hover→base, screen→base/slow, popover→base, easeOut = ease побайтно, ease дизайна → enter). Удержание и ритуал — не ступени моторики, а константы поведения: static const в motion.dart вне набора still (файлы темы страж не считает — theme_structure_test.dart:34-37), с AnimationBehavior.preserve в виджете; храповик _durations не трогать. Дыхание — период на часах DecorativeMotion. Проверку disableAnimations по виджетам не переносить — она уже централизована в context.motion и decorationMayRun.

### Типографика: характер и кегль строки

- **Дизайн:** Крупные числа и герой — Unbounded w300 с отрицательной разрядкой и плавным кеглем clamp(34, 5.4vw, 68) (typography.dart:74-80, 138-145; README.md:34); строка — Onest 14/1.5, подписи 12.5 и 11.5, метка 10.5 (typography.dart:105-133).
- **Evaporate:** Показания — JetBrains Mono w700 с табличными цифрами, readout 14 / readoutLarge 21 (typography.dart:99-110); заголовки — Unbounded w800 с положительным разрядом, «у широкого шрифта прижатые буквы слипаются» (evaporate_theme.dart:141-154); строка 13 (typography.dart:33); плавный кегль есть только в исключениях _fontSize (featured_title.dart:23-37); B10 требует сократить 32 роли и убрать полукегли (TODO.md:672-680); section_layout_test держит первый ряд обложек в 1280×900.
- **Рекомендация:** Решать в typography.dart, а не в виджетах: если владелец хочет характер дизайна у крупных чисел — сменить семейство и вес у readoutLarge (Unbounded w300, табличные цифры доступны и там), readout оставить моно; кегль строки 13→14 принимать только после замера высоты страниц под section_layout_test; плавный кегль героя — остаётся исключением featured_title, новых записей в _fontSize не заводить. Разрядку заголовков оставить положительной — это осознанный выбор под Unbounded, у дизайна минус применён к w300, где слипания нет. Всё это делать вместе с B10, чтобы ролей стало меньше, а не появилась вторая шкала.

### Числа облика по месту и вшитые цвета в виджетах дизайна

- **Дизайн:** Вне lib/design: fontSize 158, Duration(milliseconds:) 39, BorderRadius.circular 38, Curves 12, withValues(alpha:) 204, Color(0x…) 107 вхождений; вшитые цвета в кнопке «Играть», тонах полосы, блике стекла (ev_play_button.dart:325-332; ev_surfaces.dart:391-394; ev_glass.dart:175; glass_surface.dart:307-324); EvIcon с десятью размерами по месту.
- **Evaporate:** Двенадцать проверок theme_structure_test с пустыми или храповичными списками (theme_structure_test.dart:46-157, 136-205); Color(...)/Colors. только в lib/ui/theme/ без исключений (color_palette_test.dart:8-30); роль текста правится только цветом (text_roles.dart).
- **Рекомендация:** Считать это условием плана: ни один виджет дизайна не переносится файлом — переписывается на токены с первого дня, а новые цвета (тона полос, ядро кнопки, блик) рождаются полями расширений в lib/ui/theme/ с двумя экземплярами. Оценивать объём каждого этапа по числу таких замен, а не по числу файлов.

## Сохраняемые эффекты

### Искры по краю обложки (portal) — LibraryEffect.portal, в shipped

- **Где живёт:** lib/ui/library/effects/portal/* (portal_sparks.dart, portal_spark_field.dart, portal_outline.dart, portal_atlas.dart, portal_renderer.dart, spark_batch.dart); монтируется в CoverFrame снаружи ClipRRect (cover_frame.dart:35-62) по selected && shows(portal); цвета — AppColors.portalSpark 0xFFFFE79A / portalRim 0xFFFF8A1F «горят своим огнём» вне схем (decor_colors.dart:154-157); режим наложения — EffectsPalette.sparkBlend plus/srcOver (effects_palette.dart:50, 63)
- **Как выживает:** Смена палитры на Magma искры не задевает: их цвета не из палитры, а portalRim #FF8A1F почти совпадает с hot1 #FF7A18 — новая температура корпуса им к лицу без правок. Единственная связь с линзой облика — геометрия: кромка считается со скруглением 8 (portal_outline.dart:22), а плитка режется radiusControl; при переходе на радиусы tight (control 5 или карточка 7/8) число в PortalOutline и радиус ClipRRect обложки должны совпасть, после чего перерисовать эталон test/goldens/portal_sparks_reference.png через PORTAL_PREVIEW — осознанно, отдельным шагом. Файл portal_atlas.dart записан в храповике _alphas (theme_structure_test.dart:202): не переименовывать и не переносить без правки записи.
- **Зависит от:** lib/ui/theme/decor_colors.dart (AppColors.portalSpark/portalRim), lib/ui/theme/effects_palette.dart (sparkBlend), EvaporateTheme.radiusControl и portal_outline.dart:22 (согласованный радиус), test/goldens/portal_sparks_reference.png и portal_sparks_test.dart, test/guards/theme_structure_test.dart:196-205 (_alphas: portal_atlas: 1), DecorativeMotion / decorationMayRun

### Блик и перелив фольги (foil) — LibraryEffect.foil, в shipped

- **Где живёт:** lib/ui/library/effects/foil/foil_surface.dart (foregroundPainter поверх обложки: градиент libraryInkColors с alpha .24·amount и узкий блик AppColors.foilHighlight белый .25·amount), foil_scope.dart, foil_card.dart (часы на DecorationClock), foil_motion.dart; кольцо цветов libraryInkColors «собрано вокруг ночной схемы: золото, сигнальный голубой и коралл» (decor_colors.dart:113-122)
- **Как выживает:** Механика не зависит от токенов, но перелив красится кольцом из шести цветов, подобранным под золотую Арклайт: под Magma (оранжевый, янтарь, циан, фиолет) кольцо стоит пересобрать из hot2/hot1/cool/arc в decor_colors.dart — файл темы, страж цветов туда не смотрит; первый и последний элемент обязаны совпадать (color_palette_test.dart:35-37), и от этого же кольца зависят частицы атмосферы (effects_palette.dart:71-75). Белый блик оставить. Записи храповиков — foil_surface: 2 в _alphas, foil_motion: 1 в _curves (theme_structure_test.dart:187, 200) — привязаны к путям.
- **Зависит от:** lib/ui/theme/decor_colors.dart (libraryInkColors, AppColors.foilHighlight), test/ui/theme/color_palette_test.dart:35-55 (кольцо замкнуто), test/guards/theme_structure_test.dart:186-205 (_curves, _alphas), test/ui/library/library_effects_test.dart (builds == 1, reduced, TickerMode)

### Наклон карточки (cardTilt) — LibraryEffect.cardTilt, в shipped

- **Где живёт:** FoilMotion.perspective: setEntry(3,2,0.0015), rotateX sin(phase)·0.11·amount, rotateY sin(phase+π/3)·0.16·amount, amount = Curves.easeInOut(strength) (foil_motion.dart:17-25); Transform с ключом 'foil-perspective' в FoilCard (foil_card.dart:86-98); монтируется в LibraryGridTile между подъёмом (AnimatedContainer −7) и GameCoverTile (library_grid_tile.dart:106-145)
- **Как выживает:** Чистая геометрия без цвета и радиуса — палитра, шрифты и иконки его не касаются. Из линзы моушна: подъём дизайна −8 за EvMotion.hover 400 ложится на motion.base (380) без новой ступени, а перспектива остаётся внутри FoilCard; сама кривая easeInOut — единственная запись foil_motion: 1 в _curves, её нельзя перевести на токен «не подменив рисунок» (theme_structure_test.dart:183-187). Требование сохраняется: FoilCard стоит вокруг GameCoverTile внутри KeyedSubtree(tileKey), а не снаружи сдвига.
- **Зависит от:** lib/ui/theme/motion.dart (context.motion.base для подъёма), test/guards/theme_structure_test.dart:186-194 (_curves: foil_motion: 1), DecorationClock (lib/ui/widgets/decoration_clock.dart, незакоммиченный B6), test/ui/library/library_effects_test.dart:26-108

### Жидкое искажение обложки (liquidDistortion) — LibraryEffect.liquidDistortion, по умолчанию выключено

- **Где живёт:** Та же FoilMotion: матрица сжатия pulse 0.065 с обратными масштабами и сдвиг 0.035 (foil_motion.dart:26-44), включается флагом distortionEnabled в FoilCard (foil_card.dart:14-23, 39-44); переключатель effects-liquidDistortion-toggle
- **Как выживает:** Без токенов облика; живёт и умирает вместе с foil/cardTilt — сохраняется автоматически, пока FoilCard остаётся в дереве плитки и флаги LibraryEffect с прежними jsonKey не трогаются. Значения по умолчанию (не в shipped) сторожит effect_settings_test поимённо — менять только сознательно.
- **Зависит от:** lib/models/library_effect.dart (jsonKey, shipped), test/ui/settings/effect_settings_test.dart:18-91, lib/ui/library/effects/foil/foil_card.dart

### Капли воды на обложке (drops, assets/shaders/drops.frag) — LibraryEffect.drops, по умолчанию выключено

- **Где живёт:** lib/ui/library/effects/cover_drops.dart: один FragmentProgram на приложение из 'assets/shaders/drops.frag' (cover_drops.dart:37-42; pubspec.yaml:92-95, раздел shaders), обложка — текстура сэмплера, ребёнок в Opacity(0) ради размера; монтируется в CoverFace между FoilSurface и CoverArt (cover_face.dart:56-70) по selected && shows(drops) && coverPath != null; useProgram подменяется в тестах (cover_drops.dart:46-47)
- **Как выживает:** Ни палитра, ни шрифты, ни радиусы шейдер не задевают — он берёт только время, размер и текстуру обложки, а обрезка BoxFit.cover повторена внутри .frag под пропорцию 2:3. Условие выживания — порядок слоёв CoverFace и объявление шейдера в pubspec; любой блик или кромка из дизайна (sheen карточки, кромка 1 px) обязаны лечь выше CoverDrops, иначе шейдер их сотрёт. Покрытие файла тонкое (thinFiles 44 в tool/check_coverage.dart:182): новые ветки — только с тестом.
- **Зависит от:** pubspec.yaml:92-95 (shaders), assets/shaders/drops.frag (WTFPL, условия в шапке), lib/ui/library/cover/cover_face.dart (порядок FoilSurface → CoverDrops → CoverArt), test/ui/library/cover_drops_test.dart (useProgram), tool/check_coverage.dart (thinFiles: cover_drops 44), DecorativeMotion

### Жидкая подложка выбора (liquidSelection) — LibraryEffect.liquidSelection, по умолчанию выключено

- **Где живёт:** lib/ui/widgets/liquid/* (liquid_selection.dart — AnimationController 460 мс, замер цели по GlobalKey; liquid_selection_path.dart — две доли с перемычкой; liquid_painter.dart — плоская заливка; liquid_ink_scope.dart / liquid_selection_ink.dart — перекраска значков и подписей под каплей в onSelection); три места: сетка 'grid-liquid' radiusPanel (library_grid.dart:46-52), обойма 'rail-liquid' radiusChip (navigation_rack.dart:60-67), полки 'shelf-liquid' radiusControl (shelf_tabs.dart:42-49); цвет — colors.selection = railIndicator (palette.dart:94)
- **Как выживает:** Это единственный сохраняемый эффект, который красится палитрой: theme_test закрепляет точные цвета selection (dark 0xFFE9C877, light 0xFF16171A — theme_test.dart:35-37) и onSelection > 7 на нём (38-43), и тот же selection красит сегменты (44-55) и рамку NavTile. Под Magma selection Арклайта становится hot1 #FF7A18 (onSelection #0A0D11 даёт 7.46) или hot2 #FFC24D (12.12) — правится в palette.dart вместе с theme_test.dart:36-37 в одном коммите; LiquidSelectionInk перекрасит значки в onSelection сам. Радиусы капля берёт из констант EvaporateTheme — новые значения tight подхватит без правок; 460 мс — запись в _durations, не трогать. Дизайнерский EvDroplet (стекло ink 7 %) — двойник по роли; оставить LiquidSelection, а стеклянный материал при желании дать ей полями GlassSurfaceTheme.
- **Зависит от:** lib/ui/theme/palette.dart (selection/railIndicator, onSelection), test/ui/theme/theme_test.dart:35-55, EvaporateTheme.radiusPanel/Control/Chip, test/guards/theme_structure_test.dart:147-160 (_durations: liquid_selection: 1), test/ui/widgets/liquid_selection_test.dart (три подложки, перекраска ink в onSelection), decorationMayRun

### Рамка выбора и рост плитки по фокусу (selectionFrame, independent) — LibraryEffect.selectionFrame, по умолчанию выключено

- **Где живёт:** NavTile: AnimatedScale 1.06 и Border.all(color: colors.selection, width 2.5) за motion.instant (nav_tile.dart:34-36, 74-92); флаг isOn(selectionFrame) мимо общего выключателя (game_cover.dart:69; library_effect.dart:65)
- **Как выживает:** Тот же цвет selection, что у капли, — переезжает на hot1/hot2 вместе с ней; длительность — ступень instant, ничего по месту. Двойник в дизайне — EvFocusable (2 px hot2 с отступом 5 только при клавиатурном фокусе): цвет тот же hot2, так что при принятии Magma рамка evaporate и рамка дизайна совпадают по цвету сами; вторую реализацию не заводить.
- **Зависит от:** lib/ui/theme/palette.dart (selection), lib/ui/theme/motion.dart (instant), test/ui/settings/effect_settings_test.dart:284-339 (рамка мимо мастера)

### Волна на странице игры (waves) — LibraryEffect.waves, в shipped

- **Где живёт:** lib/ui/library/effects/game_wave.dart, 26 линий цветами EffectsPalette.waveColors и силой waveStrength (effects_palette.dart:23-27, 42-48, 55-61); монтируется в ShellPanel только для раздела библиотеки (shell_panel.dart:40-44)
- **Как выживает:** Четыре цвета волны у Арклайта — золото, голубой, коралл, песок — это цвета старой палитры: под Magma заменить на hot2/cool/hot1/ink2 в экземпляре arclight; color_palette_test требует четыре непрозрачных, без повторов и не равных картриджным (color_palette_test.dart:57-72). Замыкание build в game_wave.dart стоит в _longClosures с числом 43 — не удлинять.
- **Зависит от:** lib/ui/theme/effects_palette.dart (waveColors, waveStrength), test/ui/theme/color_palette_test.dart:57-72, test/guards/widget_structure_test.dart (_longClosures: game_wave 43)

### Частицы и дневной перламутр атмосферы (particles, ambient) — particles выключены, ambient в shipped

- **Где живёт:** lib/ui/library/effects/library_atmosphere.dart + particle_field.dart; цвет частицы — EffectsPalette.particle(phase, glow): от particleBase (arclight 0xFFE9C877 — старое золото) к кольцу libraryInkColors (effects_palette.dart:49, 62, 71-75); ambientWash только у cartridge (effects_palette.dart:64)
- **Как выживает:** particleBase Арклайта — тот же золотой токен, что и старый primary: при переходе на Magma поставить hot2 или hot1 в экземпляре arclight, кольцо — как у фольги; тест частиц сравнивает свойства, а не числа (color_palette_test.dart:39-54: без свечения — particleBase, с полным — первый цвет кольца), поэтому перекраска проходит без правки теста. Записи library_atmosphere: 2 в _alphas и 40 в _longClosures привязаны к пути файла.
- **Зависит от:** lib/ui/theme/effects_palette.dart (particleBase, ambientWash), lib/ui/theme/decor_colors.dart (libraryInkColors), test/ui/theme/color_palette_test.dart:35-55, test/guards/theme_structure_test.dart:201 и widget_structure_test (_alphas/_longClosures: library_atmosphere)

### Свет выбранной игры на корпусе (ambient, AmbientLight) — LibraryEffect.ambient, в shipped

- **Где живёт:** lib/ui/shell/ambient_light.dart: три радиальных пятна цветами gameAmbientColors(title) по шести якорям ambientHues [8,36,152,202,258,322], «все живут рядом с золотом корпуса» (decor_colors.dart:172-199); сила и виньетка — HardwareSurfaceTheme.ambientStrength 1/0.4 и vignetteOpacity 0.62/0.14 (hardware_surface_theme.dart:92-93, 109-110); без игры — primary/accent/surfaceHigh
- **Как выживает:** Якоря подобраны под золото; оранжевый hot1 Magma лежит между якорями 8 (киноварь) и 36 (янтарь), так что набор остаётся согласованным без правок — а если владелец решит сдвинуть, то только список ambientHues в decor_colors.dart (color_palette_test.dart:98-116 проверяет попадание в якоря с допуском 7°, а не сами числа). Плюм дизайна красится hot1/hot2/cool облика и об игре не знает — если он появится, свет игры должен остаться источником цвета (подать цвета игры в униформы), иначе теряется смысл «цвет приносят игры, а не корпус».
- **Зависит от:** lib/ui/theme/decor_colors.dart (ambientHues, gameAmbientColors), lib/ui/theme/hardware_surface_theme.dart (ambientStrength, vignetteOpacity), test/ui/theme/color_palette_test.dart:98-116

### Пробег света по крупному кадру (heroSweep) — LibraryEffect.heroSweep, в shipped

- **Где живёт:** lib/ui/library/effects/hero_sweep.dart: период 7.5 с, проход 2.4 с, BlendMode.plus, цвет AppColors.artSweep = белый .09 (decor_colors.dart:150-152); монтируется в FeaturedArt (featured_art.dart:37)
- **Как выживает:** Цвет белый и вне схем — палитра не задевает; кривая записана в _curves (hero_sweep: 1). Совпадает по идее со «спекулярной полосой» пункта 8 брендбука (README.md:163), которая в Dart-порте не реализована, — вторую реализацию не заводить.
- **Зависит от:** lib/ui/theme/decor_colors.dart (AppColors.artSweep), test/guards/theme_structure_test.dart:188 (_curves: hero_sweep: 1), DecorativeMotion

## Заметки

- Контраст, посчитанный по формуле WCAG (относительная яркость sRGB с гаммой 2.4, отношение (L1+0.05)/(L2+0.05)) на Dart-скрипте: ink3 #6E7387 на surface #0E0F16 = 4.06 — не проходит ни 4.5, ни 7; ink2 #A8ACBD на void #06060A = 8.96 — проходит оба порога. Оценка читателя ed-core (≈4.1 и ≈2.2 для ink4) подтверждается.
- Полная сводка Magma: ink 17.2/16.2/18.2 на surface/raised/void; ink2 8.47/7.97/8.96; ink3 4.06/3.83/4.30; ink4 2.18/2.31; hot1 7.33/6.90/7.75; hot2 11.9; hotDeep 3.72; cool 13.1; arc 5.61; ok 11.5; warn 11.9; bad 5.89/5.55; #170800 на hot1 7.51, на hotDeep 3.82; белый на bad 3.24, #0A0D11 на bad 6.00; line на void 1.31, на surface 1.24. Кандидаты приглушённого текста, проходящие 4.5 на raised: #82879D 5.06, #868B9F 5.32, #8A8FA3 5.61.
- Дизайн противоречит сам себе в чернилах: «ink4 ниже 12 px не используется» (tokens.dart:46; README.md:52), а роль label — JetBrains Mono 10.5 pt цветом ink4 (typography.dart:120-125). В evaporate такой роли быть не может: label набирается textSecondary с порогом 4.5.
- Пункты действующего плана, с которыми линза облика пересекается и которые лучше делать в том же заходе: B9 (числа мимо стража — высота органа 48/42, кортежи ступеней, TODO.md:660-671), B10 (меньше ролей текста, без полукеглей, TODO.md:672-680), B11 (один способ доступа к теме, EvaporateMotion — abstract final class, TODO.md:681-690). B11 сближает EvaporateMotion с EvMotion дизайна по форме, не по содержанию.
- Новая палитра, новые радиусы и решение по иконкам — это правка облика продукта, а не уборка: по правилам репозитория ей место в docs/decisions следующим номером (0010), с причинами и тем, что отклонено (три температуры, переключатель радиуса, google_fonts, flutter_svg); записи 0001–0009 не переписываются (docs/decisions/README.md:9-22).
- Стражи-храповики, чьи записи привязаны к путям файлов эффектов и облика (theme_structure_test.dart:136-205: _fontSize/_textStyles — cover_title_plate, detail_cover, featured_title, top_bar_brand; _durations — frame_step, liquid_selection, rise_in; _curves — foil_motion, hero_sweep, shots_slideshow, liquid_selection_path, rise_in; _alphas — download_chart, featured_actions, playtime_readout, foil_surface, library_atmosphere, portal_atlas, animated_progress, pulse_dot; _iconSizes — top_bar_brand): переименование или перенос любого из них требует правки записи в том же коммите; пополнять списки нельзя.
- Ступени EvSpace дизайна (4/8/12/16/24/32/28) целиком лежат на шкале EvaporateSpacing и EvaporateLayout.gutter — по отступам конфликта нет вовсе; конфликт только в виджетах дизайна, где числа стоят по месту.
- Кривая easeOut дизайна (.16,1,.3,1) побайтно равна EvaporateMotion.ease (tokens.dart:211; motion.dart:237); тень покоя дизайна (0x8C, blur 30, offset 14) почти равна HardwareSurfaceTheme.arclight (0x8C, 34, 14) — часть облика уже совпадает.
- hot1 #FF7A18 проходит 4.5 как текст на всех трёх подложках, поэтому у Арклайта-Magma primary и primaryFill могут остаться одним значением, как сейчас у золота (palette.dart:135-136); разведение ролей нужно было Картриджу и остаётся у него.
- google_fonts в дизайне действительно сетевой: секция fonts закомментирована (pubspec.yaml:89-100), GoogleFonts.config/allowRuntimeFetching в lib и test не встречаются — на свежей машине без сети интерфейс дизайна рисуется системным шрифтом.
- README дизайна обещает 34 иконки (README.md:18), в design/assets/icons их 39 и в EvIcons ровно 39 констант (ev_icon.dart:280-352); EvIcon читает файл по строке, отсутствующее имя молчит — ещё довод в пользу IconData/шрифта, где имя проверяет компилятор.
- Незакоммиченный B6 (DecorationClock: новый lib/ui/widgets/decoration_clock.dart и правки foil_card, library_atmosphere, decorative_motion, liquid_selection, window_visibility) лежит ровно в файлах сохраняемых эффектов — любой план по облику ложится поверх него; его стоит довести и закоммитить первым шагом.
- Открытые вопросы к владельцу по этой линзе: (1) Magma заменяет Арклайт или живёт третьим экземпляром рядом с ним; (2) допустима ли смена кегля строки 13→14 при страже высоты 1280×900; (3) характер крупных показаний — моно w700 или Unbounded w300; (4) иконки — Material или шрифт из SVG дизайна; (5) радиус обложки — control 5, карточный 7 или панельный 8 (с перерисовкой golden искр).

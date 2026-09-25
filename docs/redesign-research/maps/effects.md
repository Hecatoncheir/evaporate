# Сопоставление, линза: Эффекты и выделение игры: что из evaporate обязано сохраниться (portal, foil/переливы, cardTilt, liquidDistortion, drops, liquidSelection, waves, particles, ambient, heroSweep, shotsBackdrop, coverBackdrop, rise-in, selectionFrame), что дизайн приносит нового (плюм, угли, зерно, параллакс, стекло/линза, капля, кольцо заряда и ритуал, волна/ирис/аберрация, ореол), где две вещи одной роли сливаются, как всё это монтируется в новую раскладку (карточка дизайна вокруг CoverFrame, герой вместо FeaturedGame, Стена «эффекты только у активной»), одни часы вместо двух, настройки (LibraryEffect/EffectPreset против EvEffects/Эко-Полное-Макс), бюджет кадра и golden искр.

## Сопоставления

### Плюм-шейдер (EvEffects.livingBackground, shaders/plume.frag)

- **Аналог в evaporate:** AmbientLight — три радиальных пятна в цветах выбранной игры, без размытия и без кадров (lib/ui/shell/ambient_light.dart:13-15, 48-67); перламутр дневной схемы в LibraryAtmosphere (library_atmosphere.dart:167-183)
- **Решение:** новое
- **Почему:** Аналога нет: плюм — 5 вызовов fbm по 5 октав на пиксель (plume.frag:31-59) и PictureRecorder→toImageSync каждый кадр в масштабе clamp(0.55·factor,0.3,1)·min(dpr,2) (ev_atmosphere.dart:409-435, effects.dart:20-21) — самое дорогое из всего списка. Заводится значением LibraryEffect.plume (jsonKey 'plumeEnabled'), по умолчанию выключен, как единственный шейдерный drops (library_effect.dart:50-54); слой кладётся в AppShell между AmbientLight и ShellLayout (shell.dart:84-88) на DecorativeMotion, а не на своём тикере. Униформы cHot/cHot2/cCool (ev_atmosphere.dart:302-324) кормятся не скином, а gameAmbientColors(title) (decor_colors.dart:84-96): в evaporate цвет корпусу приносят игры, и AmbientLight остаётся подложкой под плюмом. Неподвижный кадр при просьбе не двигаться — t=8 (ev_atmosphere.dart:131-135) выбирает сам художник: DecorativeMotion обнуляет время (decorative_motion.dart:32-37). Шейдер объявляется в pubspec flutter.shaders рядом с drops.frag (pubspec.yaml:92-95); при недоступности — статичный фон (static_backdrop.dart), как у дизайна.
- **Файлы дизайна:** evaporate_design/shaders/plume.frag, evaporate_design/lib/atmosphere/ev_atmosphere.dart:302-324,409-435, evaporate_design/lib/atmosphere/static_backdrop.dart
- **Файлы evaporate:** lib/ui/shell.dart:84-88, lib/ui/shell/ambient_light.dart, lib/ui/widgets/decorative_motion.dart, lib/ui/theme/effects_palette.dart, lib/models/library_effect.dart:89-99, lib/ui/settings/effect_details.dart:64-90, pubspec.yaml:92-95
- **Стражи:** color_palette_test (Color только в lib/ui/theme), theme_fields_test (новые поля EffectsPalette в lerp/values), theme_structure_test _alphas (альфа числом в художнике), effect_settings_test (умолчания поимённо), effect_preset_test (лестница calm⊂standard⊂full), localization_test/arb_usage_test (effectPlume + note в ru/en), tool/check_coverage _reportedNowhere/thinFiles (шейдер в тестах — см. notes)

### Угли (EvEffects.sparks: EvEmberField + paintEvEmbers одним drawAtlas)

- **Аналог в evaporate:** LibraryAtmosphere.particles — ParticleField, 4800 фоновых точек с притяжением к выбранной плитке (particle_field.dart:21-22, library_atmosphere.dart:69-71)
- **Решение:** новое
- **Почему:** Роли разные: частицы evaporate — ровная россыпь, сгущающаяся у карточки (particle_field.dart:3-5); угли — 34…104·factor восходящих искр, screen-смешение, ядро поверх (ember_field.dart:62-63, ember_paint.dart:67-82) — дешевле и частиц, и искр портала. Значение LibraryEffect.embers; рисуются вторым списком в том же _AtmospherePainter LibraryAtmosphere (library_atmosphere.dart:144-208): один RepaintBoundary, одни часы, один флаг enabled. EvEmberField — чистый Dart без Flutter (ember_field.dart:1-2), переносится целиком вместе с burst()/burstFrom() (108-147): их ждут ритуал (ev_launch_ritual.dart:242-251) и «испарение» панелей. Свой срез шага до 64 мс (151-153) лишний: FrameStep уже режет до 1/30 (frame_step.dart:14). Цвета hot/cool — поля EffectsPalette (emberHot/emberCool), днём другие.
- **Файлы дизайна:** evaporate_design/lib/atmosphere/ember_field.dart, evaporate_design/lib/atmosphere/ember_paint.dart
- **Файлы evaporate:** lib/ui/library/effects/library_atmosphere.dart:40-44,144-208, lib/ui/library/effects/particle_field.dart, lib/ui/theme/effects_palette.dart, lib/models/library_effect.dart
- **Стражи:** widget_structure_test _longClosures (library_atmosphere.build: 40 — не удлинять), theme_structure_test _alphas (library_atmosphere: 2), complexity_test (paint ≤60 строк, вложенность ≤3), color_palette_test, effect_settings_test, test/ мирроринг: test/ui/library/effects/ember_field_test

### Плёночное зерно (EvEffects.grain, EvFilmGrain 128×128, overlay 5 %)

- **Аналог в evaporate:** нет
- **Решение:** новое
- **Почему:** Плитка одна на приложение (film_grain.dart:7-11), рисуется одним drawRect с ImageShader и BlendMode.overlay, α 0x0D (ev_atmosphere.dart:388-402) — самое дешёвое из новых. Значение LibraryEffect.grain, последний слой того же атмосферного художника; поверх стекла (glass_surface.dart:312-326 у дизайна) — только если стекло возьмут (см. строку про EvGlass). На светлом Картридже overlay читается грязью — сила зерна полем EffectsPalette.grainAlpha (у cartridge 0), не ветвлением isDark. revision-уведомление о готовности плитки (film_grain.dart:20) заменяется обычным setState по Future.
- **Файлы дизайна:** evaporate_design/lib/atmosphere/film_grain.dart, evaporate_design/lib/atmosphere/ev_atmosphere.dart:388-402
- **Файлы evaporate:** lib/ui/library/effects/library_atmosphere.dart, lib/ui/theme/effects_palette.dart, lib/ui/theme/decor_colors.dart
- **Стражи:** color_palette_test (Color(0x0D000000) → константа в lib/ui/theme), theme_structure_test _alphas, theme_fields_test, effect_settings_test

### Параллакс слоёв героя за курсором (EvHero: evParallaxOffset, глубины 5/14/30, EvPointer)

- **Аналог в evaporate:** ShotsBackdrop → ShotsSlideshow: кадры едут по времени, дрейф 6 % ширины (shots_timing.dart:8-12), курсора не знают; HeroSweep поверх (featured_art.dart:37-45)
- **Решение:** адаптировать
- **Почему:** Дизайн сдвигает три растровых слоя героя на −(p−.5)·depth по X и ×.55 по Y (ev_hero.dart:372-373), кадры идут только пока курсор догоняется (ev_atmosphere.dart:205-207); параллакс включается лишь при effects.parallax && !disableAnimations (ev_hero.dart:116-120). У evaporate слой один — кадр игры или обложка (featured_art.dart:45-63). Слияние: ShotsSlideshow получает ValueListenable<Offset> общего PointerTrail и прибавляет к дрейфу сдвиг кадра (depth 14), затемнения и надпись остаются на месте (depth 0) — два слоя вместо трёх, растра не нужно. Свой флаг LibraryEffect.heroParallax: по одному выключателю на украшение, цена своя. На плитку сетки параллакс не идёт — там FoilCard.tilt (см. conflicts).
- **Файлы дизайна:** evaporate_design/lib/library/ev_hero.dart:116-120,360-383, evaporate_design/lib/atmosphere/ev_pointer.dart
- **Файлы evaporate:** lib/ui/library/shots_backdrop.dart, lib/ui/library/featured/shots_slideshow.dart, lib/ui/library/featured/shots_timing.dart, lib/ui/library/featured/featured_art.dart:37-63, lib/ui/library/library_featured_slot.dart:54-55
- **Стражи:** widget_structure_test _longClosures (shots_slideshow.build: 40), theme_structure_test _curves (shots_slideshow: 1), shots_backdrop_test (кадры по кругу, disableAnimations останавливает), effect_settings_test

### Тепловое марево кадра при заряде «Играть» (EvHeroArtPainter._paintHaze: полосы 1 px, drawAtlas, амплитуда 2,5 px)

- **Аналог в evaporate:** нет
- **Решение:** не брать
- **Почему:** Марево режет растровый слой героя (ui.Image из EvArtCache) на полосы и сдвигает их одним drawAtlas (ev_hero.dart:401-513); у evaporate герой собран из виджетов Image.file/ShotsSlideshow (featured_art.dart:45-63), растра в руках нет. Показывается только 620 мс заряда — heat = min(1, charge/.2) (ev_hero.dart:442) — и без удержания «Играть» (см. строку про кольцо заряда) бессмысленно. Вернуться, когда удержание принято и кадр героя станет ui.Image; тогда флаг общий с удержанием, не отдельный.
- **Файлы дизайна:** evaporate_design/lib/library/ev_hero.dart:401-513
- **Файлы evaporate:** lib/ui/library/featured/featured_art.dart
- **Стражи:** 

### Ореол/свечение выбранного (бренд 06: три тени 34/90/160; EvGameCard: glow hot1 α.3 blur 42 при подъёме; EvWallFeature: hot1 α.24 blur 46)

- **Аналог в evaporate:** Тень плитки AppColors.coverShadow blur 10 (cover_frame.dart:40-48); токен colors.glow — ночью золото, днём прозрачный (palette); кант и тень крупного кадра по схеме (_FeaturedFrame, featured_game.dart:103-129)
- **Решение:** адаптировать
- **Почему:** Свечение под активной плиткой — одна BoxShadow цветом colors.glow в DecoratedBox CoverFrame (cover_frame.dart:37-49): днём токен прозрачен по палитре, ветвления не нужно, размытие — новое поле HardwareSurfaceTheme (tileGlowBlur), обязанное различаться у arclight/cartridge. Три тени бренда (brand.html:583) не брать: три размытия под плиткой, у которой уже 3600 искр по краю. Не флаг: это облик выбранной плитки, как тень; включается тем же active, что и FoilCard (library_grid_tile.dart:58-63).
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_game_card.dart:88-99, evaporate_design/lib/modes/ev_wall.dart:294-332, evaporate_design/design/evaporate-brand.html:583
- **Файлы evaporate:** lib/ui/library/cover/cover_frame.dart:37-49, lib/ui/theme/hardware_surface_theme.dart, lib/ui/theme/palette.dart
- **Стражи:** hardware_surface_theme_test (поле различается у схем), theme_fields_test, theme_structure_test (числа размытия — в тему)

### 3D-наклон обложки (бренд 08: rotateX/Y до 11°, перспектива 700 px, спекулярная полоса)

- **Аналог в evaporate:** FoilCard.tilt → FoilMotion.perspective: setEntry(3,2,0.0015) ≈ перспектива 667 px, rotateX sin·0.11 рад ≈ 6,3°, rotateY sin·0.16 ≈ 9,2° (foil_motion.dart:21-26); спекулярная полоса — узкий блик FoilSurface тем же циклом (foil_surface.dart:50-65)
- **Решение:** оставить evaporate
- **Почему:** В Flutter-переносе дизайна наклона нет вовсе: «единственное, что выходит из плоскости при наведении: −8 px по Y» (ev_game_card.dart:16-17), приём живёт только в бренде (brand.html:588-589). У evaporate он есть и проверен тестом «наклоняется жёстко, не пересобирает картинку» (library_effects_test.dart:26-108). Довести до 11° — правка двух чисел в foil_motion.dart, не перенос.
- **Файлы дизайна:** evaporate_design/design/evaporate-brand.html:588-589
- **Файлы evaporate:** lib/ui/library/effects/foil/foil_card.dart, lib/ui/library/effects/foil/foil_motion.dart:21-26
- **Стражи:** theme_structure_test _curves (foil_motion: 1 — Curves.easeInOut в amount), library_effects_test (builds == 1, identity при уходе выбора)

### Спекуляр: диагональный sheen на поднятой карточке (EvGameCard 137-155) и блик кнопки за 1050 мс при наведении (EvPlayButton _sweep)

- **Аналог в evaporate:** FoilSurface: перелив libraryInkColors + узкий белый блик α .25·amount (foil_surface.dart:37-65); LauncherActionButton keySheen (HardwareSurfaceTheme.keySheen .16/.04)
- **Решение:** сливается
- **Почему:** Sheen карточки — второй блик поверх FoilSurface, причём внутри ClipRRect над обложкой (ev_game_card.dart:101-155), где у evaporate лежат капли и полоса загрузки (cover_face.dart:59-69): не брать, роль закрыта фольгой. Блик кнопки — иная поверхность: LauncherActionButton держит статичный keySheen; бегущий проход за 1050 мс (ev_play_button.dart:87-90) добавляется через DecorativeMotion как часть удержания, отдельного флага не заводить.
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_game_card.dart:137-155, evaporate_design/lib/widgets/ev_play_button.dart:87-90
- **Файлы evaporate:** lib/ui/library/effects/foil/foil_surface.dart, lib/ui/widgets/launcher_action_button.dart, lib/ui/theme/hardware_surface_theme.dart:74
- **Стражи:** theme_structure_test _durations (1050 → ступень EvaporateMotion), theme_structure_test _alphas (foil_surface: 2)

### Капля выбора EvDroplet (Positioned в чужом Stack по Rect, вытягивание/сужение evDropletRect, стекло droplet без чтения фона)

- **Аналог в evaporate:** LiquidSelection: замер цели по GlobalKey сквозь прокрутку, две доли с перемычкой, прыжок дальше 2,5 ширин, NaN-защита, LiquidInkScope для перекраски подписей (liquid_selection.dart:94-148, liquid_selection_path.dart:9-37, liquid_selection_ink.dart:34-61)
- **Решение:** сливается
- **Почему:** Заказчик просит сохранить жидкую подложку — остаётся LiquidSelection: у неё замер (targetKey → getTransformTo viewport, liquid_selection.dart:134-139), правило «перекладка/прокрутка — не смена выделения» (100-118), три места с тестами (library_grid.dart:46-52, navigation_rack.dart:60-67, shelf_tabs.dart:42) и правило decorationMayRun (77). EvDroplet геометрию не измеряет — хозяин считает Rect сам (ev_droplet.dart:28-29, ev_rail.dart:72-84) и ничего не знает о подписях. От дизайна берётся материал: EvGlassStyle.droplet — blur 0, tint ink α .07, кромка rimKey .22 без свечения (glass_style.dart:157-171, ev_droplet.dart:86-89) — как второй режим LiquidPainter (заливка + штрих кромки по готовому Path со светом от PointerTrail), полями нового ThemeExtension с экземплярами arclight/cartridge; плоский colors.selection остаётся по умолчанию. Мёртвый параметр resting (TODO B8) заодно уходит.
- **Файлы дизайна:** evaporate_design/lib/glass/ev_droplet.dart, evaporate_design/lib/glass/glass_style.dart:157-171, evaporate_design/lib/shell/ev_rail.dart:72-84,113-116
- **Файлы evaporate:** lib/ui/widgets/liquid/liquid_selection.dart, lib/ui/widgets/liquid/liquid_painter.dart, lib/ui/widgets/liquid/liquid_selection_path.dart, lib/ui/widgets/liquid/liquid_selection_ink.dart, lib/ui/library/library_grid.dart:46-52
- **Стражи:** liquid_selection_test (геометрия перемычки, три подложки, перекраска в onSelection, NaN), theme_structure_test _durations (liquid_selection: 1), _curves (liquid_selection_path: 3), theme_fields_test (новое расширение), widget_structure_test lonelyShared (liquid/ нужен обойме, полкам и сетке — проходит)

### Рамка фокуса EvFocusable (2 px hot2, отступ 5, только при клавиатурном highlightMode, Stack clip none, звук tap)

- **Аналог в evaporate:** NavTile: рамка 2.5 px colors.selection + AnimatedScale 1.06 по любому фокусу, флаг selectionFrame independent и выключен (nav_tile.dart:34-36, 74-89; library_effect.dart:59-65)
- **Решение:** сливается
- **Почему:** NavTile остаётся: он же InkWell с ensureVisible и onFocusChange → GameSelected (nav_tile.dart:45-57, game_cover.dart:64-66), а рамка сторожится тестом «рамка выбора выключена, пока её не попросят, и переживает общий выключатель» (effect_settings_test.dart:284-339). От EvFocusable берётся одно правило — рамка только при onShowFocusHighlight, то есть когда фокус пришёл с клавиатуры/геймпада (ev_focusable.dart:66-70): это ровно смысл флага «указатель для того, кто ходит без мыши» (library_effect.dart:61-64), и после этого рамку можно включить в shipped. Отступ рамки наружу (Positioned −5, clip none) пересекается с каймой искр 48 — оставить рамку внутри Transform FoilCard, как сейчас. Звук не брать.
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_focusable.dart
- **Файлы evaporate:** lib/ui/library/nav_tile.dart, lib/ui/library/game_cover.dart:54-79, lib/models/library_effect.dart:59-65
- **Стражи:** effect_settings_test (умолчание selectionFrame, независимость от master), reachability_test/input_navigation_test (фокус с геймпада), effect_preset_test (рамка наборам не подчиняется)

### Подъём карточки при наведении/фокусе (EvGameCard: −8 px, EvMotion.hover 400 мс, MouseRegion снаружи сдвига)

- **Аналог в evaporate:** LibraryGridTile: AnimatedContainer −7 по hovered за motion.fast, MouseRegion снаружи (library_grid_tile.dart:106-124)
- **Решение:** оставить evaporate
- **Почему:** То же решение с тем же обоснованием («наведение ловится снаружи сдвига, иначе мигает у нижней кромки» — ev_game_card.dart:60-61 против комментария library_grid_tile.dart:121-123); тест читает подъём из AnimatedContainer.transform (library_grid_test.dart:318-345). Разница −7/−8 и 200/400 мс — вкус, правится числом/ступенью, не переносом. Подъём по фокусу (lifted = hover || focus, ev_game_card.dart:59) у evaporate заменён ростом 1.06 в NavTile.
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_game_card.dart:59-72
- **Файлы evaporate:** lib/ui/library/library_grid_tile.dart:106-145
- **Стражи:** library_grid_test (подъём под курсором), theme_structure_test _durations

### Стекло EvGlass (frost blur 22 / lens blur 6 / chip, цветовая матрица saturate/brightness, свет кромки вершинами от курсора, hover-свечение, нажатие ×1.035, BackdropGroup)

- **Аналог в evaporate:** GlassSurface: BackdropFilter blur 16 + GlassSurfaceTheme (fillOpacity, sheenTop/Bottom, rim, counterLight; arclight/cartridge) (glass_surface_theme.dart:23-35); ShellPanel — заливка shellOpacity без размытия (shell_panel.dart:28-39); AmbientLight намеренно без BackdropFilter на окно (ambient_light.dart:13-15)
- **Решение:** адаптировать
- **Почему:** Числа материалов (glass_style.dart:100-190) ложатся полями GlassSurfaceTheme (blurSigma, saturation, brightness) с разными значениями у схем, а не новым виджетом; выключатель «стекло читает фон» — LibraryEffect.glass: без него заливка ×1.7 (ev_glass.dart:~158-163). Свет кромки от курсора — только у interactive-поверхностей: у дизайна каждое стекло перерисовывается на каждом шаге курсора через listener в attach (glass_surface.dart:240-243), и при рейле+полосах+чипах это десятки markNeedsPaint на движение — перерисовка идёт по PointerTrail и только при decorationMayRun. BackdropGroup для полос каркаса — взять: один снимок фона на все стёкла оболочки.
- **Файлы дизайна:** evaporate_design/lib/glass/ev_glass.dart, evaporate_design/lib/glass/glass_style.dart, evaporate_design/lib/glass/glass_surface.dart:225-260
- **Файлы evaporate:** lib/ui/widgets/glass_surface.dart, lib/ui/theme/glass_surface_theme.dart, lib/ui/shell/shell_panel.dart
- **Стражи:** hardware_surface_theme_test (каждое поле GlassSurfaceTheme различается у схем), theme_fields_test, theme_structure_test (_durations 120/240 мс нажатия, _alphas, Curves.easeOut), widget_structure_test (один публичный виджет на файл; EvGlass — 300+ строк), theme_test (контраст подписей на размытом светлом фоне Картриджа)

### Преломление у кромки стекла (EvEffects.refraction, glass_lens.frag через ImageFilter.shader, только Impeller)

- **Аналог в evaporate:** нет
- **Решение:** не брать
- **Почему:** Линза работает только там, где ui.ImageFilter.isShaderFilterSupported (glass_lens.dart:22-38); в тестах движок Skia — стекло матовое (glass_test.dart:90-94), на Linux в CI под xvfb тоже. Под любым OpacityLayer < 255, ColorFilter/ImageFilter/ShaderMask/BackdropFilter слой гасит линзу (glass_lens.dart:293-304) — то есть под RiseIn всхода, проявлением FadeIndexedStack и над каплями. Облик, различный по системам и по кадрам, — отдельное решение в docs/decisions после стекла; в этот план не входит.
- **Файлы дизайна:** evaporate_design/lib/glass/glass_lens.dart, evaporate_design/shaders/glass_lens.frag
- **Файлы evaporate:** 
- **Стражи:** docs/decisions (новое решение)

### Кольцо заряда и удержание «Играть» 620 мс (EvPlayButton: контроллер с AnimationBehavior.preserve, Space/Enter держат заряд, _ChargeRingPainter — дуга extractPath по RRect с inset −11, MaskFilter blur 3; кольца 18/26 с в бренде)

- **Аналог в evaporate:** LauncherActionButton (ход клавиши, keySheen, торец depth); главное действие мгновенно по нажатию/кнопке X геймпада через primaryActionFor/dispatchPrimaryAction (lib/ui/library/primary_action.dart)
- **Решение:** адаптировать
- **Почему:** Удержание — поведение ввода, а не украшение: настройка holdToPlay ложится не в LibraryEffect, а полем AppSettings (часть startup или новая часть launch), и её слушают все четыре места главного действия. AnimationBehavior.preserve обязателен — иначе при disableAnimations 620 мс станут 31 (ev_play_button.dart:72-80). Кольцо (_ChargeRingPainter, 365-422) — единственная видимая часть удержания, рисуется поверх LauncherActionButton; с геймпада NavAction.primaryAction — дискретное событие (input_scope.dart), удержание там надо заводить в GamepadService отдельно (open question). Медленные кольца бренда (18/26 с) — только в ритуале (ritual_timeline.dart:43-44).
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_play_button.dart:60-130,365-422, evaporate_design/lib/design/effects.dart:162-169
- **Файлы evaporate:** lib/ui/widgets/launcher_action_button.dart, lib/ui/library/primary_action.dart, lib/ui/library/featured/featured_actions.dart, lib/input/input_scope.dart, lib/models/app_settings.dart
- **Стражи:** theme_structure_test (_durations 620/160/1050 → EvaporateMotion.hold; Curves; MaskFilter числом), model_roundtrip_test (новый плоский ключ настроек), game_page_effects_test (LauncherActionButton срабатывает с клавиатуры один раз), primary_action_test, localization (УДЕРЖАТЬ → ARB)

### Ритуал запуска (showEvLaunchRitual: PopupRoute, opaque до удара, 6 стадий за 2600 мс, выброс EvEmberField.burst, onStrike/onDone по времени, без отмены)

- **Аналог в evaporate:** нет; запуск — GameLaunchRequested → busy(launchKey) → beforeLaunch (снимок сейвов) → Process.start → статус running, ошибка приходит Notice
- **Решение:** новое
- **Почему:** Значение LibraryEffect.launchRitual, выключено по умолчанию; при выключенном или disableAnimations — краткое затемнение 900 мс (ritual_timeline.dart:29-32, ev_launch_ritual.dart:37). Стадии не по таймеру: ход ведёт LibraryState — isBusy(launchKey) даёт «подготовка/снимок», статус running — удар (strike), Notice с ошибкой — прерывание с уходом затемнения, которого у дизайна нет (barrierDismissible false, onDone только по _end: ev_launch_ritual.dart:105, 279-283). Непрозрачный маршрут гасит все украшения под собой (ModalRoute.isCurrentOf в decorationMayRun, window_visibility.dart:29) — это желаемо; искры ритуала — тот же EvEmberField со своим DecorativeMotion внутри маршрута; PortalSparks после возврата не сбрасывается, часы продолжают время. Звук не брать.
- **Файлы дизайна:** evaporate_design/lib/launch/ev_launch_ritual.dart, evaporate_design/lib/launch/ritual_timeline.dart:17-45, evaporate_design/lib/launch/ritual_core.dart
- **Файлы evaporate:** lib/bloc/library/library_bloc.dart, lib/bloc/library/library_state.dart, lib/ui/library/primary_action.dart, lib/ui/widgets/window_visibility.dart:25-29
- **Стражи:** theme_structure_test (_durations 300/500/900/1000/4020, Curves.ease), widget_structure_test (файлы дизайна с несколькими виджетами и методами-виджетами), complexity_test, localization (стадии → ARB), check_coverage (новые файлы без тестов), layering (ритуал знает блок, блок не знает ритуал)

### Ударная волна, ирис и хроматическая аберрация (внутри ритуала: shock 900 мс до 1.9·longestSide, iris 1000 мс, аберрация ±2.4 px только на вспышке)

- **Аналог в evaporate:** нет
- **Решение:** новое
- **Почему:** Части одного украшения — без отдельного флага, живут под launchRitual. Кадр как функция времени (EvRitualFrame.at, ritual_timeline.dart:47-57) переносится как есть на DecorativeMotion; аберрация — два цветных дубля текста только на кадрах flash (brand.html:597, «постоянная утомляет»), под disableAnimations не рисуется (brief-режим без вспышки: ev_launch_ritual.dart:22-26).
- **Файлы дизайна:** evaporate_design/lib/launch/ritual_timeline.dart, evaporate_design/lib/launch/ev_launch_ritual.dart:300-446, evaporate_design/design/evaporate-brand.html:593-598
- **Файлы evaporate:** 
- **Стражи:** theme_structure_test, complexity_test

### Дым (бренд 03: два слоя размытого шума screen) и подповерхностное рассеивание (бренд 07)

- **Аналог в evaporate:** нет
- **Решение:** не брать
- **Почему:** Оба приёма есть только в HTML-бренде (brand.html:572-586); во Flutter-переносе дизайна их нет (lib/atmosphere/ содержит плюм, угли, зерно — README.md:719-722). Дым поверх плюма и AmbientLight — третий фоновый слой с размытием, бюджет не позволяет.
- **Файлы дизайна:** evaporate_design/design/evaporate-brand.html:572-586
- **Файлы evaporate:** 
- **Стражи:** 

### Уровень эффектов Эко/Полное/Макс (EvEffectsQuality: factor .5/1/1.6 → плотность углей, разрешение плюма, blurScale .55/1/1.15, линза не на Эко) и «30 к/с в фоне» (throttleInBackground)

- **Аналог в evaporate:** EffectPreset off/calm/standard/full — наборы булевых флагов лестницей, «выключено» трогает только общий выключатель (effect_preset.dart:21-58); качества нет; в фоне — полная частота, гасится только hidden/paused/detached (window_visibility.dart:12-15)
- **Решение:** адаптировать
- **Почему:** Качество — множитель, а не подмножество, и в лестницу наборов не ложится: новое поле Appearance.effectQuality (enum eco/full/max, плоский ключ 'effectQuality', умолчание full, клампинг незнакомого при чтении, как у themeMode) — его читают плюм (масштаб кадра), угли (countFor, ember_field.dart:62-63) и стекло (blurScale). EffectPreset остаётся про «что включено», качество — про «насколько дорого». throttleInBackground не брать: спорит с решением «inactive — окно видно, за загрузкой следят из соседнего окна» (window_visibility.dart:3-11), а ограничение частоты, если понадобится, делается в FrameStep одним местом.
- **Файлы дизайна:** evaporate_design/lib/design/effects.dart:5-39,171-177, evaporate_design/lib/settings/settings_catalog.dart:459-490
- **Файлы evaporate:** lib/models/appearance.dart, lib/models/effect_preset.dart, lib/ui/settings/effects_card.dart, lib/ui/widgets/frame_step.dart
- **Стражи:** model_roundtrip_test (плоская запись, прежние ключи), effect_preset_test (набор не трогает ничего, кроме украшений — качество отдельно), effect_settings_test, settings_layout_test (украшения выбираются набором), localization (Эко/Полное/Макс → ARB, не подписи enum)

### Модель настроек украшений EvEffects (ChangeNotifier, десять флагов, все включены, EvEffectsScope, reset(), не сохраняется)

- **Аналог в evaporate:** Appearance.effects: Set<LibraryEffect> с jsonKey на диске, isOn/shows (appearance.dart:60-63), shipped (library_effect.dart:89-99), запись только SettingsPatched, переключатели по LibraryEffect.values с ключами effects-<name>-toggle (effect_details.dart:43-59)
- **Решение:** не брать
- **Почему:** Новое состояние — блок (prefer_bloc на воротах), ChangeNotifier/InheritedNotifier не переезжают. Соответствие флагов: livingBackground → LibraryEffect.plume; sparks → embers; parallax → heroParallax; grain → grain; glass → glass; refraction → не берётся; ritual → launchRitual; holdToPlay → поле AppSettings (не украшение); quality → Appearance.effectQuality; throttleInBackground → не берётся. Каждое новое значение = строка в enum с jsonKey, решение о shipped, две ARB-подписи (switch _title исчерпывающий, effect_details.dart:64-79), строка в effect_settings_test:18-45. «Сбросить» = EffectPreset.standard, уже есть.
- **Файлы дизайна:** evaporate_design/lib/design/effects.dart:43-190, evaporate_design/lib/main.dart:308-321
- **Файлы evaporate:** lib/models/library_effect.dart, lib/models/appearance.dart, lib/ui/settings/effect_details.dart, lib/ui/settings/effect_preset_picker.dart
- **Стражи:** bloc lint prefer_bloc, effect_settings_test, effect_preset_test, arb_usage_test/localization_test, layering_test (модель без Flutter)

### Часы атмосферы EvAtmosphere (свой Ticker, AppLifecycleListener, Stopwatch, Timer.periodic 33 мс на inactive, шаг ≤0.1 с, wanted = scope && !reduced && TickerMode && visible && (фон||искры||параллакс догоняет))

- **Аналог в evaporate:** DecorationClock (миксин: wantsFrames/onFrame/syncClock, _LifecycleHook, FrameStep 1/60…1/30) + одно правило decorationMayRun (окно видно, !disableAnimations, TickerMode, маршрут текущий) (decoration_clock.dart:19-84, window_visibility.dart:25-29)
- **Решение:** не брать
- **Почему:** Правило у обоих почти одно (ev_atmosphere.dart:152-165 против window_visibility.dart:25-29), но evaporate только что свёл все копии в миксин (незакоммиченный B6) и прямо отверг AppLifecycleListener (decoration_clock.dart:86-89) и гашение по inactive (window_visibility.dart:3-11). Атмосфера дизайна переносится как художник на DecorationClock/DecorativeMotion: wantsFrames = plume || embers || pointer.settling; «параллакс догоняет» (ev_atmosphere.dart:205-207) — то же wantsFrames у PointerTrail. Тесты «без ограничения неактивное окно на полной частоте» (atmosphere_test.dart:199) и evaporate «ушедший фокус окна не гасит фон» (library_effects_test.dart:560-565) сходятся.
- **Файлы дизайна:** evaporate_design/lib/atmosphere/ev_atmosphere.dart:56-233
- **Файлы evaporate:** lib/ui/widgets/decoration_clock.dart, lib/ui/widgets/window_visibility.dart, lib/ui/widgets/decorative_motion.dart, lib/ui/widgets/frame_step.dart
- **Стражи:** library_effects_test («скрытый раздел, свёрнутое окно, просьба не двигаться и настройка гасят часы»), game_page_effects_test (ровно один DecorativeMotion на странице игры), theme_structure_test _durations (Timer 33 мс числом)

### Сглаженный курсор окна EvPointer (доли окна, 5,5 %/кадр при 60 Гц, settleDistance, один источник для плюма, параллакса и света стёкол)

- **Аналог в evaporate:** Курсор на каждом украшении свой: WaveTrail.smoothed в художнике волны (game_wave.dart:16-19, 120-124), field.pointer у частиц через MouseRegion (library_atmosphere.dart:84-90)
- **Решение:** новое
- **Почему:** Три новых потребителя (плюм, параллакс героя, свет кромки капли/стекла) и два старых просят одно и то же: один PointerTrail (ValueListenable<Offset> в долях окна + settling) в оболочке, кормится Listener(translucent) внутри InterfaceScale — координаты уже логические, масштаб не расходится. Шаги делает DecorativeMotion оболочки с wantsFrames = settling; у геймпада курсора нет — свет стоит слева сверху, как у дизайна (glass_surface.dart:35-49). GameWave и частицы переезжают на него по мере правок, не сразу.
- **Файлы дизайна:** evaporate_design/lib/atmosphere/ev_pointer.dart, evaporate_design/lib/atmosphere/ev_atmosphere.dart:224-244
- **Файлы evaporate:** lib/ui/shell.dart, lib/ui/library/effects/game_wave.dart:16-19,55-64, lib/ui/library/effects/library_atmosphere.dart:84-90
- **Стражи:** widget_structure_test lonelyShared (класть в lib/ui/shell, пока потребитель один; в widgets — при втором), check_coverage (новый файл — с тестом), game_wave_test (WaveTrail переживает пересборку)

### Режим Стена: «эффекты только у активной плитки» (EvWallTile: подъём −4, имя по наведению; EvWallFeature: рамка hot1 .5 + свечение; сетка minmax(146) с зазором 11; выбор в WallPage._selected)

- **Аналог в evaporate:** Инвариант уже есть: горит одна плитка — hovered ?? selected (library_grid_tile.dart:56-63), искры и капли только у selected (game_cover.dart:72-78, cover_face.dart:62-64), одна цель у капли и атмосферы (library_grid_controller.dart:33-34); тесты «ровно одна анимирующая FoilCardState», «одна PortalSparks.enabled» (library_effects_test.dart:474-479, effect_settings_test.dart:228-249)
- **Решение:** адаптировать
- **Почему:** Стена — другой делегат и «большая плитка» = FeaturedGame внутри сетки, но плитка — та же LibraryGridTile: цепочка FoilCard→NavTile→CoverFrame→CoverFace не меняется, «только у активной» получается даром. Обязательно: выбор из NavigationBloc.selectedGameId, а не локальный _selected (wall_page.dart:34-36); ключ плитки controller.tileKey на KeyedSubtree (library_grid_tile.dart:125-127); зазор не 11, а ≥ каймы искр: halo 48 (portal_spark_field.dart:15) при промежутке 11 кладёт искры на соседей — либо gap ≥ 28/32, как в сетке (library_grid.dart:91-92), либо у мелких плиток портал выключен и горит только большая (что и рисует README.md:2119). Раскладка Positioned.fromRect — вместо GridView, значит layoutFor/scrollTo (library_grid.dart:103-124) и возврат фокуса переписываются вместе.
- **Файлы дизайна:** evaporate_design/lib/modes/ev_wall.dart, evaporate_design/lib/screens/wall_page.dart:34-46, evaporate_design/design/README.md:2114-2119
- **Файлы evaporate:** lib/ui/library/library_grid.dart, lib/ui/library/library_grid_tile.dart, lib/ui/library/library_grid_controller.dart, lib/bloc/navigation/navigation_state.dart
- **Стражи:** library_grid_test (layoutFor сходится, возврат фокуса, наведение выбирает), effect_settings_test (одна PortalSparks), portal_sparks_test golden (не задевается, пока PortalSparks внутри не менялся), bloc lint (вид библиотеки — блок, не ValueNotifier)

### Пульт: размытый кадр выбранной игры фоном (blur 34 + saturate 1.35, scale 1.18, opacity .5, AnimatedSwitcher 500 мс, виньетка), пять обложек в PopupRoute

- **Аналог в evaporate:** CoverBackdrop: та же обложка размытием 28, dstIn до 0.55 высоты, cacheWidth 480, затемнение scrimOpacity (cover_backdrop.dart:39-83)
- **Решение:** адаптировать
- **Почему:** Один и тот же приём — обложка игры размытым фоном; CoverBackdrop уже решает цену (расшифровка 480 точек, одна на открытие) и бережёт контраст затемнением по схеме. Для Пульта — тот же виджет с параметрами «во всю высоту, без растворения, с виньеткой», а не второй ImageFiltered с числами по месту (ev_pult.dart:240-262). Пульт как PopupRoute останавливает все украшения под собой (decorationMayRun по маршруту) — верно; искрам вокруг центральной обложки нужен свой PortalSparks внутри маршрута с DecorativeMotion.
- **Файлы дизайна:** evaporate_design/lib/modes/ev_pult.dart:220-283
- **Файлы evaporate:** lib/ui/library/detail/cover_backdrop.dart, lib/ui/library/cover/decode_width.dart
- **Стражи:** cover_backdrop_test (тает к середине, приглушён), theme_structure_test (_durations 500 мс, opacity .5, матрица числом → тема), widget_structure_test (_PultBackdrop приватный ≤40 строк)

### Обложка карточки: AspectRatio 3/4, процедурная EvCover (palette+seed), кромка 1 px ink .16, EvCoverBadge-линза

- **Аналог в evaporate:** CoverFrame: AspectRatio 2/3, ClipRRect radiusControl (cover_frame.dart:50-53); CoverArt = Image.file с decodeWidth поверх CoverTitlePlate; CoverStatusBadge/CoverProgressStrip поверх (cover_face.dart:59-69)
- **Решение:** оставить evaporate
- **Почему:** На 2:3 держатся кромка искр PortalOutline и golden (обложка 120×180 в portal_sparks_test.dart:352-358), контракт BoxFit.cover в drops.frag (106-115), делегат сетки childAspectRatio 2/3 (library_grid.dart:90). Процедурная EvCover не нужна: обложки настоящие, а капли без coverPath не идут (cover_drops.dart:78-81) — запасная подложка остаётся CoverTitlePlate. Карточка дизайна становится обёрткой ВОКРУГ CoverFrame (рамка, свечение, название под обложкой), а не заменой CoverFace.
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_game_card.dart:81-136, evaporate_design/lib/art/ev_art.dart
- **Файлы evaporate:** lib/ui/library/cover/cover_frame.dart, lib/ui/library/cover/cover_face.dart, lib/ui/library/cover/cover_art.dart, assets/shaders/drops.frag:102-115
- **Стражи:** portal_sparks_test golden, cover_drops_test, semantics_test (подпись внутри плитки под MergeSemantics — название под обложкой снаружи Semantics удвоит объявление)

### Герой EvHero (высота clamp(340, 52vh, 520), три растровых слоя, _GradePainter виньетка, тело с eyebrow/чипами/CTA) вместо FeaturedGame

- **Аналог в evaporate:** FeaturedGame 238/128 px, компакт ниже 760, нет ниже 520 (library_featured_slot.dart:25-28), _FeaturedFrame кант+тень по схеме, слои: HeroSweep(ShotsBackdrop(cover|asset) + три затемнения) (featured_art.dart:37-73)
- **Решение:** адаптировать
- **Почему:** Раскладка героя — чужая линза, здесь важно одно: HeroSweep и ShotsBackdrop монтируются в слой кадра нового героя ровно как в FeaturedArt (HeroSweep снаружи Stack, ShotsBackdrop первым ребёнком, затемнения после), флаги shows(heroSweep)/shows(shotsBackdrop) остаются (library_featured_slot.dart:54-55); параллакс приходит внутрь ShotsSlideshow. Высота героя ограничена стражем «первый ряд обложек виден в 1280×900» (section_layout_test) — 520 px дизайна туда не влезают.
- **Файлы дизайна:** evaporate_design/lib/library/ev_hero.dart:122-179, evaporate_design/lib/library/library_layout.dart:49-83
- **Файлы evaporate:** lib/ui/library/featured_game.dart, lib/ui/library/featured/featured_art.dart, lib/ui/library/library_featured_slot.dart
- **Стражи:** section_layout_test (первый ряд обложек в 1280×900), library_grid_test (compact ниже 760, нет ниже 420), widget_structure_test _longClosures (featured_game.build: 30), theme_structure_test _alphas (featured_actions, playtime_readout)

### Капли в EvSegmented (замер сегментов GlobalKey после кадра, слушатель systemFonts) и в EvRail (Rect из dropletRect по номеру кнопки)

- **Аналог в evaporate:** LiquidSelection 'rail-liquid' в NavigationRack по GlobalKey клавиш (navigation_rack.dart:60-67), 'shelf-liquid' во вкладках полок (shelf_tabs.dart:42); сегменты настроек — Material SegmentedButton
- **Решение:** оставить evaporate
- **Почему:** Оба места дизайна — частные случаи LiquidSelection: она сама меряет GlobalKey после кадра и при SizeChangedLayoutNotification (liquid_selection.dart:85-92, 165-172), слушатель systemFonts не нужен — шрифты у evaporate вложены. Если рейл станет вертикальным, targetKey по AppSection не меняется. Сегменты настроек капли не получают: там SegmentedButton темы, и заводить третье выделение незачем.
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_controls.dart:408-482, evaporate_design/lib/shell/ev_rail.dart:72-116
- **Файлы evaporate:** lib/ui/shell/navigation_rack.dart:60-67, lib/ui/library/toolbar/shelf_tabs.dart:42-49
- **Стражи:** liquid_selection_test (подложка живёт в обойме, фильтрах и сетке), widget_structure_test _longClosures (navigation_rack.build: 49)

## Конфликты

### Часы украшений и политика неактивного окна

- **Дизайн:** EvAtmosphere держит свой Ticker, AppLifecycleListener, Stopwatch и Timer.periodic 33 мс; на inactive при throttleInBackground — 30 к/с таймером, hidden/paused/detached — стоп, reduced motion — один кадр t=8 (ev_atmosphere.dart:56-64, 106-111, 131-135, 152-197). Тест «в неактивном окне 30 к/с» (atmosphere_test.dart:172).
- **Evaporate:** Один миксин DecorationClock с FrameStep и одно правило decorationMayRun: inactive считается видимым — «замершие искры выглядят зависшим приложением, когда за загрузкой следят из соседнего окна»; AppLifecycleListener отвергнут — «проверяет порядок переходов утверждениями» (window_visibility.dart:3-15, decoration_clock.dart:86-89). Тест «ушедший фокус окна не гасит фон» (library_effects_test.dart:560-565).
- **Рекомендация:** Одни часы — DecorationClock/DecorativeMotion для всех новых художников; throttleInBackground не берём. Если батарея в inactive станет вопросом, частота режется в FrameStep (frame_step.dart:10) одним изменением для всех, а не таймером у одного украшения. Неподвижный кадр при просьбе не двигаться выбирает художник (плюм — t=8), время часов остаётся 0 (decorative_motion.dart:32-37); B6 коммитится первым, иначе план ложится на незакоммиченный дифф (git status: decoration_clock.dart untracked).

### Капля выбора: EvDroplet против LiquidSelection

- **Дизайн:** EvDroplet — Positioned в чужом Stack по Rect, который хозяин считает сам (ev_rail.dart:72-84); в полёте вытягивается по движению и сужается поперёк до 20 % (ev_droplet.dart:110-141); материал — стекло droplet: blur 0, tint ink 7 %, кромка со светом от курсора (glass_style.dart:157-171, ev_droplet.dart:86-89); четыре места: рейл, нижняя панель, палитра, сегменты.
- **Evaporate:** LiquidSelection меряет цель по GlobalKey сквозь прокрутку (liquid_selection.dart:126-148), едет только при смене identity с живым прежним контекстом (100-118), контур — две доли с вогнутой перемычкой, дальше 2,5 ширин — прыжок (liquid_selection_path.dart:9-37), подписи перекрашиваются через LiquidInkScope (liquid_selection_ink.dart:34-61), плоский colors.selection; три места с тестами; выключена по умолчанию (library_effect.dart:89-99).
- **Рекомендация:** LiquidSelection остаётся единственной каплей (заказчик просит именно жидкую подложку). От дизайна — материал как второй режим LiquidPainter (заливка + штрих кромки по готовому Path, свет от PointerTrail), поля нового ThemeExtension с экземплярами arclight/cartridge. Растяжение evDropletRect не брать: у перемычки-метабола та же роль. Включать ли liquidSelection в shipped — решение владельца (правка effect_settings_test и лестницы наборов).

### Рамка фокуса: EvFocusable против NavTile.selectionFrame

- **Дизайн:** 2 px hot2 с отступом 5, Stack clipBehavior none, рисуется только при onShowFocusHighlight (клавиатурная навигация), нажатие звучит (ev_focusable.dart:51-56, 66-92).
- **Evaporate:** NavTile: рамка 2.5 px colors.selection по любому фокусу + AnimatedScale 1.06, InkWell с ensureVisible и onFocusChange → GameSelected (nav_tile.dart:34-36, 45-57, 74-89); флаг independent, выключен, сторожится тестом (effect_settings_test.dart:284-339).
- **Рекомендация:** NavTile остаётся, берётся правило «только при клавиатурном highlightMode» — оно и есть смысл флага «указатель для того, кто ходит без мыши» (library_effect.dart:59-64); после этого рамку можно включить по умолчанию. Рамка внутри Transform FoilCard, не снаружи: отступ −5 с clip none спорил бы с каймой искр 48. Звук — вне плана.

### Наклон плитки против параллакса обложки

- **Дизайн:** «Обложка карточки — два слоя с параллаксом за курсором, как у героя» (README.md:363), листа игры — тоже (ev_game_sheet.dart:368-403); бренд обещает наклон до 11° с перспективой 700 (brand.html:588-589), но во Flutter-карточке наклона нет (ev_game_card.dart:16-17).
- **Evaporate:** FoilCard уже наклоняет плитку под курсором (rotateX 0.11, rotateY 0.16, перспектива 0.0015 — foil_motion.dart:21-26) и рисует перелив с бликом тем же циклом (foil_surface.dart:37-65); горит одна плитка (library_grid_tile.dart:56-63).
- **Рекомендация:** Два движения одной обложки за одним курсором дадут двойной сдвиг. Плитка — только FoilCard (tilt/foil/distortion); параллакс — только герой (ShotsSlideshow с PointerTrail) и, если страница игры получит кадр дизайна, её фон. Довести углы до бренда — числа в foil_motion.dart.

### Кто «активная» плитка: наведение выбирает или только поднимает

- **Дизайн:** Наведение поднимает карточку (lifted = hover || focus), выбор — по нажатию; в Стене выбранная хранится локально в WallPage._selected и герой не следует за курсором (ev_game_card.dart:59, wall_page.dart:34-46).
- **Evaporate:** Наведение шлёт GameSelected, крупный кадр идёт за выбором, чтобы до его клавиш можно было дойти рукой; горит hovered ?? selected, искры/капли/капля — только у selected (library_grid_tile.dart:14-22, 56-77; library_grid_controller.dart:33-34); тесты library_grid_test.dart:288-345.
- **Рекомендация:** Оставить модель evaporate: выбор в NavigationBloc, наведение выбирает, а «эффекты только у активной» получается из существующего инварианта. Любой новый вид (Стена, полки) регистрирует плитки через controller.tileKey и передаёт selected из блока — иначе капля, атмосфера и искры теряют цель молча.

### Настройки украшений: два словаря и качество

- **Дизайн:** EvEffects — десять булевых полей + EvEffectsQuality (eco .5 / full 1 / max 1.6, blurScale .55/1/1.15, линза не на Эко), все включены по умолчанию, ChangeNotifier без записи на диск (effects.dart:7-55).
- **Evaporate:** LibraryEffect — 14 значений с jsonKey и набором shipped; EffectPreset off/calm/standard/full — лестница подмножеств, «выключено» трогает только общий выключатель; умолчания поимённо в effect_settings_test.dart:18-45; запись SettingsPatched; переключатели строятся по LibraryEffect.values с исчерпывающим switch подписей (effect_details.dart:43-79).
- **Рекомендация:** Каждый флаг дизайна → значение LibraryEffect (plume, embers, grain, heroParallax, glass, launchRitual); качество → Appearance.effectQuality (enum, плоский ключ, умолчание full); holdToPlay → поле AppSettings, не украшение; refraction и throttle не берутся. Предложение по shipped: embers, grain (cartridge grainAlpha 0), glass, heroParallax — да; plume, launchRitual — нет (шейдер каждый кадр и модальный маршрут — как drops). Каждое изменение shipped — строка в effect_settings_test и проверка лестницы в effect_preset_test.

### Пропорции и слои обложки плитки

- **Дизайн:** AspectRatio 3/4, всё внутри одного ClipRRect: EvCover, кромка 1 px, бейдж-линза, EvBar, sheen (ev_game_card.dart:81-157); зазор Стены 11 (ev_wall.dart:24-56).
- **Evaporate:** AspectRatio 2/3 внутри ClipRRect, PortalSparks СНАРУЖИ выреза с каймой 48 и Clip.none (cover_frame.dart:35-62, portal_sparks.dart:51-63), капли под FoilSurface и под значками (cover_face.dart:59-69); golden снят на обложке 120×180 и требует over == 0, around в (500, 6000), closeIn > 2·farOut (portal_sparks_test.dart:352-488); сетка 215·scale, 2/3, просветы 28/32 (library_grid.dart:87-93).
- **Рекомендация:** 2:3 и порядок слоёв не трогать; карточка дизайна — обёртка вокруг CoverFrame (рамка, свечение, подпись под обложкой), никаких слоёв между FoilSurface и CoverArt. Промежуток любого нового вида ≥ 28, либо у мелких плиток Стены портал выключен, а горит большая. Golden не переснимать: он меряет только PortalSparks на чёрном, новые слои в него не попадают.

### Цвета украшений: скин против игры и схемы

- **Дизайн:** Плюм, угли, свечения и свет кромки красятся hot1/hot2/cool выбранного облика (ev_atmosphere.dart:302-324, ember_paint.dart:63, ev_glass.dart keyLight lerp(white, hot2, .28)); тема одна, тёмная.
- **Evaporate:** Искры портала горят своим огнём одинаково на обеих схемах (decor_colors.dart:51-54), фольга — libraryInkColors + белый блик (35), волна/частицы/режим наложения — EffectsPalette по схеме (effects_palette.dart:41-65), свет корпуса — от названия игры по шести якорям (decor_colors.dart:76-96); Color(...) допустим только в lib/ui/theme (color_palette_test).
- **Рекомендация:** Портал и фольгу не перекрашивать. Плюм берёт цвета от gameAmbientColors(title) — так он продолжает роль AmbientLight; угли/зерно/свечение — новые поля EffectsPalette с двумя экземплярами (у cartridge: другой ember-цвет, grainAlpha 0, sparkBlend уже srcOver). Ни одного isDark и ни одного литерала цвета вне темы.

### Ритуал запуска против настоящего запуска

- **Дизайн:** Шесть стадий за 2600 мс по таймеру, удар и ирис по времени, маршрут непрозрачен до удара, отмены нет — barrierDismissible false, onDone только по _end (ev_launch_ritual.dart:75-82, 105, 226-236, 279-283); стадии — выдуманные данные.
- **Evaporate:** Запуск — GameLaunchRequested под busyWhile(launchKey): сперва beforeLaunch (снимок сейвов непредсказуемой длины), потом Process.start, статус running; ошибка приходит Notice и показывается только AppShell; повтор при busy игнорируется (CLAUDE.md, lib/bloc/library/library_bloc.dart).
- **Рекомендация:** Ритуал ведёт состояние блока: isBusy(launchKey) — стадии «подготовка/снимок», статус running — удар, Notice с isError — прерывание с уходом затемнения; фиксированные 2600 мс — только нижняя граница длительности. Выключен по умолчанию; при disableAnimations — brief 900 мс без вспышки (ritual_timeline.dart:29-32). Искры ритуала — тот же EvEmberField в своём DecorativeMotion внутри маршрута.

### Стекло на BackdropFilter и бюджет кадра

- **Дизайн:** frost blur 22 (raised 30) с матрицей saturate 1.6/brightness .68, рейл+полосы+чипы читают фон, каждое стекло перерисовывается на каждом шаге курсора (glass_style.dart:100-114, glass_surface.dart:240-243), нажатие Transform.scale ×1.035.
- **Evaporate:** AmbientLight нарочно без BackdropFilter на окно — «стоил бы кадров на каждой перерисовке» (ambient_light.dart:13-15); стекло только на панелях — GlassSurface blur 16 с токенами GlassSurfaceTheme; под ним уже идут искры (до 3600), капли-шейдер, частицы 4800, кадры героя; Linux в CI — Skia под xvfb без GPU, --smoke обязан дожить до кадра.
- **Рекомендация:** Стекло каркаса — за флагом LibraryEffect.glass и BackdropGroup (один снимок фона на полосы); свет кромки — только у interactive-поверхностей и только при decorationMayRun; линзу не брать. Порядок дороговизны для пресетов и умолчаний: плюм (toImageSync + fbm) > стекло ×N > капли (одна плитка) ≈ частицы 4800 > портал 3600 > угли ≤166 > фольга/наклон (одна плитка) > зерно > капля выбора.

### Шейдеры в тестах и тонкий cover_drops.dart

- **Дизайн:** atmosphere_test.dart грузит настоящий plume.frag в setUpAll под flutter_test и проверяет, что он собирается (atmosphere_test.dart:46-52), на sdk ^3.13.3 (pubspec.yaml:22).
- **Evaporate:** «Настоящий шейдер в тестах не собрать — он компилируется при сборке приложения, а прогон тестов её не делает» (cover_drops.dart:44-45); тесты подменяют useProgram и проверяют только отказы (cover_drops_test.dart:10-13); файл в thinFiles с 44 (check_coverage.dart:182).
- **Рекомендация:** Проверить на 3.47.4 первым шагом: если flutter test собирает .frag из pubspec shaders (у дизайна — собирает), то _DropsPainter и плюм тестируются по-настоящему, cover_drops.dart уходит из thinFiles, а новые шейдерные файлы не попадают в _reportedNowhere. Если нет — плюм получает такой же useProgram.

### Смена раздела и линза/часы под маршрутами

- **Дизайн:** Разделы меняются AnimatedSwitcher с FadeTransition+MatrixTransition (ev_shell.dart:436-449), ритуал и Пульт — PopupRoute; линза гаснет под любым OpacityLayer < 255 (glass_lens.dart:293-304).
- **Evaporate:** FadeIndexedStack держит всех детей и раздаёт TickerMode ровно текущему (fade_indexed_stack.dart:78-86) — на этом стоят decorationMayRun, GameDropTarget и WatchWhileShown; страница игры — не маршрут, а замена тела LibraryPage (library_page.dart:130).
- **Рекомендация:** FadeIndexedStack остаётся; ритуал и Пульт — маршруты (украшения под ними встают по ModalRoute.isCurrentOf — желаемо); страница игры остаётся внутри раздела, иначе возврат фокуса на плитку и CoverBackdrop под всей страницей переписываются. Это ещё один довод не брать линзу: под RiseIn и проявлением стека она матовая половину времени.

## Сохраняемые эффекты

### Искры по краю обложки (portal)

- **Где живёт:** lib/ui/library/effects/portal/{portal_sparks, portal_spark_field, portal_painter, portal_renderer, portal_atlas, portal_outline, spark_batch, portal_spark}.dart; монтируется в CoverFrame снаружи DecoratedBox/ClipRRect (cover_frame.dart:35-36), внутри AnimatedScale NavTile; enabled = selected && shows(portal) (game_cover.dart:77); поле искр живёт в State и переживает пересборку (portal_sparks.dart:20-36); слой Positioned −48 под child в Stack expand с Clip.none (51-78); цвета portalRim/portalSpark (decor_colors.dart:51-54), blend из EffectsPalette.sparkBlend (72).
- **Как выживает:** Карточка дизайна становится обёрткой ВОКРУГ CoverFrame (рамка/свечение/подпись), а не заменой: её ClipRRect на всём (ev_game_card.dart:101) срезал бы кайму 48. От родителя нужно: Stack без обрезки и свободное место ≥ halo вокруг плитки (сетка 28/32 — library_grid.dart:91-92; Стена gap 11 — мало), размер плитки 2:3, selected из NavigationBloc, EffectsPalette через тему, часы DecorativeMotion. В герое искр нет и не будет — только у плитки. Golden portal_sparks_reference.png не переснимать: не менять PortalOutline.corner 8, halo 48, maxCount/rate, цвета и порядок «искры под обложкой» (portal_sparks_test.dart:352-488: over == 0, around ∈ (500,6000), closeIn > 2·farOut).
- **Зависит от:** DecorativeMotion/DecorationClock, EffectsPalette.sparkBlend (plus/srcOver), AppColors.portalRim/portalSpark, PortalAtlas.image (toImageSync один на приложение), NavigationBloc.selectedGameId, порядок NavTile(AnimatedScale) → CoverFrame(PortalSparks → ClipRRect), test/goldens/portal_sparks_reference.png, effect_settings_test: ровно одна PortalSparks.enabled, следует за GameSelected (228-249)

### Фольга/блик (foil)

- **Где живёт:** FoilCard (foil_card.dart) на DecorationClock: wantsFrames = enabled && (active || strength > 0) (44); FoilMotion (ChangeNotifier) раздаётся FoilScope; FoilSurface — foregroundPainter поверх обложки в CoverFace (cover_face.dart:59), под значком состояния и полосой загрузки; узкий блик AppColors.foilHighlight α .25·amount тем же циклом, что перспектива (foil_surface.dart:50-65); при reduced/выключенных украшениях strength = active ? 1 : 0 — подсветка выбранной остаётся указателем (foil_card.dart:55-64).
- **Как выживает:** FoilCard остаётся сразу под KeyedSubtree(tileKey) и над GameCoverTile (library_grid_tile.dart:125-140); подъём карточки (AnimatedContainer) — снаружи FoilCard, как сейчас. Родитель отдаёт active = hovered ?? selected, enabled = libraryEffects и три isOn-флага; дизайнерская карточка не кладёт своих слоёв между FoilSurface и CoverArt (sheen ev_game_card.dart:137-155 — не брать). Для героя фольга не включается.
- **Зависит от:** DecorationClock, libraryInkColors, AppColors.foilHighlight, MediaQuery.disableAnimations (strength без анимации), LibraryGridController.hoveredId, library_effects_test («наклоняется жёстко», builds == 1, ровно одна FoilCardState анимирует: 474-479), theme_structure _alphas (foil_surface: 2), _curves (foil_motion: 1)

### Переливы (голографический градиент фольги)

- **Где живёт:** Тот же _FoilPainter: LinearGradient из libraryInkColors с α .24·amount, TileMode.mirror и GradientRotation sin(phase+.6)·.45, сдвиг по sin(phase) (foil_surface.dart:36-49); фаза 2π/7 с (foil_card.dart:73).
- **Как выживает:** Живёт вместе с блоком foil — отдельного флага нет и не нужно; при переносе цветов в EffectsPalette (если день захочет другой набор) берётся полем, а не ветвлением. Ничто из дизайна на эту роль не претендует.
- **Зависит от:** FoilMotion.phase/amount, libraryInkColors (decor_colors.dart:12-19), FoilScope

### Наклон карточки (cardTilt)

- **Где живёт:** FoilMotion.perspective: setEntry(3,2,0.0015), rotateX sin(phase)·0.11·amount, rotateY sin(phase+π/3)·0.16·amount (foil_motion.dart:18-26); Transform с key 'foil-perspective' и alignment center (foil_card.dart:92-96); tilt выключается при reduced (foil_card.dart:55-64).
- **Как выживает:** Transform остаётся снаружи ClipRRect и внутри AnimatedContainer подъёма; параллакс дизайна на плитку не идёт (конфликт «наклон против параллакса»); увеличить до 11° бренда — правка чисел 0.11/0.16. Свечение/тень новой карточки должны лежать в том же поддереве Transform, иначе тень не наклонится вместе с обложкой.
- **Зависит от:** FoilCard/DecorationClock, test 'foil-perspective' (library_effects_test), theme_structure _curves (foil_motion: 1)

### Жидкое искажение обложки (liquidDistortion)

- **Где живёт:** FoilMotion.distortion: сжатие pulse·0.065 с обратным масштабом по осям и сдвиг pulse·0.035 (foil_motion.dart:27-42); флаг distortionEnabled в FoilCard, выключено по умолчанию (library_effect.dart:26-27, 89-99); тест «искажение живёт само по себе» (effect_settings_test.dart:99-153).
- **Как выживает:** Переезжает вместе с FoilCard без правок; отдельного места в новой раскладке не требует.
- **Зависит от:** FoilCard, effect_settings_test

### Шейдер капель (drops, assets/shaders/drops.frag)

- **Где живёт:** CoverDrops внутри FoilSurface в CoverFace: enabled = selected && dropsEnabled, coverPath из game.details (cover_face.dart:62-66); FragmentProgram один на приложение, useProgram для тестов (cover_drops.dart:39-47); обложка декодируется целиком в ui.Image, поколение отбрасывает поздний ответ (75-111); ребёнок в Opacity(0) ради размера (143); униформы iTime, iResolution(w,h,1), iTextureSize, sampler 0 (166-173); шейдер повторяет BoxFit.cover и clamp (drops.frag:106-115); pubspec shaders (92-95); thinFiles 44 (check_coverage.dart:182).
- **Как выживает:** Слой обложки в новой карточке — CoverFace, не EvCover: без coverPath капель нет (78-81), процедурная подложка их не получит. Пропорция плитки 2:3 и BoxFit.cover в CoverArt — контракт с шейдером. Это Paint.shader, а не ImageFilter.shader — работает и на Skia, и под Impeller, в отличие от линзы дизайна. От родителя: selected, флаг shows(drops), часы DecorativeMotion. Если на 3.47.4 flutter test собирает .frag (см. notes), _DropsPainter получает настоящий тест и файл уходит из thinFiles.
- **Зависит от:** DecorativeMotion, CoverArt BoxFit.cover 2:3, game.details.coverPath, pubspec flutter.shaders, cover_drops_test (отказы), check_coverage thinFiles

### Жидкая подложка выбора (liquidSelection)

- **Где живёт:** LiquidSelection над GridView с key 'grid-liquid', targetKey = controller.targetKey(selectedId), radiusPanel, padding gap (library_grid.dart:46-52); 'rail-liquid' в NavigationRack (navigation_rack.dart:60-67), 'shelf-liquid' в ShelfTabs; замер цели по GlobalKey через getTransformTo viewport после кадра и по ScrollNotification (liquid_selection.dart:85-148); контур — liquidSelectionPath; подписи через LiquidInkScope/LiquidSelectionInk; правило decorationMayRun (77); выключена по умолчанию.
- **Как выживает:** Любая новая раскладка плиток (Стена с Positioned.fromRect, горизонтальные полки) обязана: обернуть свой прокручиваемый/позиционированный слой одной LiquidSelection (свой viewport на каждую прокрутку), поставить на плитку KeyedSubtree(controller.tileKey(id)) выше FoilCard (library_grid_tile.dart:125-127) и подавать targetKey из hovered ?? selected. Материал капли дизайна (glass droplet) — опция LiquidPainter, геометрия и замер не меняются. Вертикальный рейл — та же LiquidSelection по GlobalKey клавиш.
- **Зависит от:** LibraryGridController.tileKey/targetKey, decorationMayRun, colors.selection, EvaporateTheme.radiusPanel/Chip/Control, liquid_selection_test (три подложки, перекраска в onSelection, NaN), theme_structure _durations (liquid_selection: 1), _curves (liquid_selection_path: 3)

### Волны (waves)

- **Где живёт:** GameWave в ShellPanel вокруг ShellSections, key 'library-wave', enabled = section == library && shows(waves) (shell_panel.dart:40-44); 26 линий, курсор через MouseRegion → WaveTrail.smoothed вне художника (game_wave.dart:16-19, 55-64, 117-124); цвета/сила из EffectsPalette.waveColors/waveStrength; ключи 'detail-wave-motion'/'detail-wave-paint'; лежит под всеми разделами, включая страницу игры.
- **Как выживает:** Если панель разделов заменяется стеклянным каркасом дизайна, GameWave оборачивает хост раздела с тем же условием и ключом; MouseRegion ему нужен во всю область раздела; при появлении PointerTrail WaveTrail переезжает на него без смены облика. Тест game_page_effects_test требует ровно один DecorativeMotion на странице игры (190-193) — плюм оболочки должен стоять выше ShellPanel, а не внутри раздела.
- **Зависит от:** DecorativeMotion, EffectsPalette.waveColors/waveStrength, AppColors.waveHighlight, NavigationBloc.section, widget_structure _longClosures (game_wave.build: 43), game_wave_test, game_page_effects_test, library_effects_test:467

### Частицы (particles)

- **Где живёт:** LibraryAtmosphere вокруг всей страницы библиотеки (library_body.dart:67-71): enabled = libraryEffects, particlesEnabled = isOn(particles), targetKey = grid.targetKey(selectedId); ParticleField 4800 + до 2000 рождённых (particle_field.dart:21-22); прямоугольник плитки ищется через globalToLocal на каждом кадре (library_atmosphere.dart:54-74); курсор только при clockRunning (84-90); painter key 'library-atmosphere-paint'; выключены по умолчанию.
- **Как выживает:** LibraryAtmosphere остаётся внешней обёрткой всего раздела библиотеки (герой + полки + сетка) — так цель находится через globalToLocal в любой раскладке; угли и зерно дизайна ложатся в тот же _AtmospherePainter вторым и третьим списком (одни часы, один RepaintBoundary). Публичные targetRect/targetIdentity уходят по TODO B7 (636-647) — план не должен опираться на них в новых тестах.
- **Зависит от:** DecorationClock, EffectsPalette.particle(phase, glow)/ambientWash, LibraryGridController.targetKey, library_effects_test (цель за карточкой, скрытый раздел гасит часы), widget_structure _longClosures (library_atmosphere.build: 40), theme_structure _alphas (: 2)

### Свет выбранной игры (ambient light)

- **Где живёт:** AmbientLight в AppShell.body вокруг ShellLayout (shell.dart:84-88): три _AmbientWash с α .38/.32/.42 × HardwareSurfaceTheme.ambientStrength (1/0.4), AnimatedContainer motion.slow, виньетка vignetteOpacity (.62/.14), цвета gameAmbientColors(title) по шести якорям (ambient_light.dart:48-82, 110-127; decor_colors.dart:76-96); enabled = shows(ambient) (shell.dart:43-45); дневной перламутр — в LibraryAtmosphere по EffectsPalette.ambientWash.
- **Как выживает:** Остаётся подложкой под всем: плюм (если включён) рисуется поверх него и берёт те же цвета игры; стеклянные полосы каркаса дизайна читают его как фон через BackdropGroup — так свет корпуса становится тем, что видно сквозь стекло. ShellPanel остаётся неплотной (shellOpacity), иначе единственный цвет в окне гаснет (shell_panel.dart:12-15).
- **Зависит от:** HardwareSurfaceTheme.ambientStrength/vignetteOpacity, gameAmbientColors/ambientHues, LibraryBloc.gameById(selectedId).title, context.motion.slow

### Пробег света по крупному кадру (hero sweep)

- **Где живёт:** HeroSweep оборачивает Stack FeaturedArt (featured_art.dart:37); период 7.5 с, проход 2.4 с, полоса 30 % ширины, BlendMode.plus, поворот −0.26, цвет AppColors.artSweep (hero_sweep.dart:45-84); enabled = shows(heroSweep) (library_featured_slot.dart:54).
- **Как выживает:** В герое дизайна оборачивает слой кадра ровно так же — снаружи Stack с кадром и затемнениями, под телом героя (eyebrow/название/CTA), чтобы полоса не шла по тексту. Флаг и ключи не меняются; спекулярная полоса бренда на карточках — не его роль.
- **Зависит от:** DecorativeMotion, AppColors.artSweep, theme_structure _curves (hero_sweep: 1), effect_settings_test

### Кадры из игры под крупной обложкой (shots backdrop)

- **Где живёт:** ShotsBackdrop(shots, enabled, fallback) → DecorativeMotion → ShotsSlideshow (shots_backdrop.dart:24-48); без кадров возвращает fallback — Image.file обложки с decodeWidth по ширине окна или asset orbit_fall_hero.png (featured_art.dart:28-63); hold 9 с, fade 1.6 с, drift 0.06 (shots_timing.dart:8-12); enabled = shows(shotsBackdrop).
- **Как выживает:** В герое дизайна заменяет три процедурных слоя EvHeroArtPainter; параллакс дизайна входит внутрь ShotsSlideshow как сдвиг кадра по PointerTrail (свой флаг heroParallax), дрейф по времени остаётся. Первый ребёнок Stack, поверх — затемнения heroShade*.
- **Зависит от:** DecorativeMotion, game.details.shotPaths/coverPath, decodeWidth, shots_backdrop_test (по кругу, disableAnimations останавливает), widget_structure _longClosures (shots_slideshow.build: 40), theme_structure _curves (shots_slideshow: 1)

### Обложка фоном страницы игры (cover backdrop)

- **Где живёт:** CoverBackdrop в Positioned.fill под всей GamePage, включая клавишу возврата (game_page.dart:27-29), по isOn(coverBackdrop), а не shows (20-22); blur 28, ShaderMask dstIn до fadeAt 0.55, cacheWidth blurredDecodeWidth 480, затемнение background × scrimOpacity (cover_backdrop.dart:39-83).
- **Как выживает:** Если страница игры получает облик листа дизайна, CoverBackdrop остаётся под ним тем же виджетом (страница — не маршрут, library_page.dart:130); для Пульта — тот же виджет с полной высотой и виньеткой вместо второго ImageFiltered дизайна. Расшифровка одна на открытие — параллакс листа (ev_game_sheet.dart:368-403) на него не вешать.
- **Зависит от:** HardwareSurfaceTheme.scrimOpacity, blurredDecodeWidth, cover_backdrop_test (тает к середине, приглушён, без обложки не падает)

### Всход полки и проявления (rise-in / interfaceAnimations)

- **Где живёт:** RiseIn вокруг плитки: задержка staggerAt(index) только для index < staggerLimit (library_grid_tile.dart:109-117), интервалом внутри одной анимации, не таймером (rise_in.dart:11-13, 59-65); FadeIndexedStack проявляет раздел и раздаёт TickerMode (fade_indexed_stack.dart:78-86); шаг EvaporateMotion.stagger 55 мс, staggerLimit 12, still при disableAnimations (motion.dart:61-79).
- **Как выживает:** В горизонтальных полках/Стене RiseIn остаётся на плитке с индексом по порядку раскладки; переход разделов дизайна (_PageTransition с AnimatedSwitcher, ev_shell.dart:436-449) не берётся — FadeIndexedStack держит детей и TickerMode, на которых стоят decorationMayRun и приёмник броска. Проявление/подъём 10 px дизайна можно добавить в FadeIndexedStack ступенями motion, если понадобится.
- **Зависит от:** context.motion (still при disableAnimations), EvaporateMotion.enter, theme_structure _durations (rise_in: 1), _curves (rise_in: 1), library_grid_test (State RiseIn тот же после смены полки)

### Рамка выбора под фокусом (selection frame)

- **Где живёт:** NavTile.showFocusBorder → AnimatedContainer с Border 2.5 colors.selection по _focused + AnimatedScale 1.06 (nav_tile.dart:34-36, 74-91); флаг isOn(selectionFrame) мимо общего выключателя, independent (game_cover.dart:69, library_effect.dart:59-65); выключен по умолчанию; тест находит AnimatedContainer с непрозрачной рамкой внутри GameCoverTile (effect_settings_test.dart:284-339).
- **Как выживает:** NavTile остаётся внутри новой карточки как фокусируемая оправа; рамка — по правилу EvFocusable «только при клавиатурном highlightMode», после чего её можно включать по умолчанию; рамка внутри Transform FoilCard, не снаружи (кайма искр). Рамка дизайна EvFocusable не переносится.
- **Зависит от:** FocusManager.highlightMode, colors.selection, effect_settings_test, effect_preset_test (рамка наборам не подчиняется), reachability_test

## Заметки

- Порядок: B6 (DecorationClock) лежит незакоммиченным — lib/ui/widgets/decoration_clock.dart untracked, правлены foil_card, library_atmosphere, decorative_motion, liquid_selection, window_visibility (git status). Довести и закоммитить до первого шага плана: все новые художники встают на этот миксин.
- TODO B7 (636-647) помечает/убирает крючки targetRect/targetIdentity, isAnimating, perspective, positionOf/tailOf, на которые опираются library_effects_test и portal_sparks_test; B8 (648-659) снимает мёртвый LiquidSelection.resting; B9 (660-673) — числа мимо стража. Правки эффектов по этому плану делать вместе с B7–B9 в тех же файлах, а не дважды.
- Стражи, которые зацепит перенос: theme_structure_test храповики _durations (liquid_selection: 1, frame_step: 1, rise_in: 1), _curves (foil_motion: 1, hero_sweep: 1, shots_slideshow: 1, liquid_selection_path: 3, rise_in: 1), _alphas (foil_surface: 2, library_atmosphere: 2, portal_atlas: 1) (386-444) и widget_structure_test _longClosures (game_wave 43, library_atmosphere 40, portal_sparks 30, shots_slideshow 40, library_grid 30, featured_game 30) (365-381) — записи по пути с числом: файлы эффектов не переименовывать и не переносить, новые компоненты импортируют их на месте.
- Golden test/goldens/portal_sparks_reference.png сравнивает только PortalSparks на чёрном фоне 120×180 + кайма 48 (portal_sparks_test.dart:352-488); новые слои (плюм, зерно, свечение, стекло) в него не попадают. Переснимать придётся только при правке PortalOutline.corner, halo, maxCount/rate, цветов portalRim/portalSpark, пропорции 2:3 или порядка «искры под обложкой» — план этого не требует.
- Шейдер в тестах: evaporate уверяет, что .frag в прогоне не собрать (cover_drops.dart:44-45), а atmosphere_test.dart дизайна грузит настоящий plume.frag в setUpAll (46-52) на sdk ^3.13.3 против ^3.13.2 у evaporate. Проверить на 3.47.4 первым делом: если собирается, капли и плюм получают настоящие тесты, cover_drops.dart (thinFiles 44) утолщается, useProgram становится ненужным.
- Бюджет кадра по убыванию: плюм (PictureRecorder→toImageSync каждый кадр, 5 fbm×5 октав на пиксель, ev_atmosphere.dart:409-435) > стекло BackdropFilter blur 22 на каждой полосе/чипе + перерисовка света на каждом шаге курсора (glass_surface.dart:240-243) > капли-шейдер на одной плитке ≈ частицы 4800 > портал до 3600 искр drawRawAtlas > угли ≤166 drawAtlas > фольга/наклон одной плитки > зерно (один drawRect) > капля выбора (один Path). Linux в CI — Skia под xvfb без GPU, --smoke обязан дожить до кадра: умолчания держать консервативными (плюм, ритуал — выключены).
- Соответствие флагов EvEffects → evaporate: livingBackground→LibraryEffect.plume; sparks→embers; parallax→heroParallax; grain→grain; glass→glass; refraction→не берётся (Impeller-only, гаснет под Opacity); ritual→launchRitual; holdToPlay→поле AppSettings (поведение ввода, не украшение); quality→Appearance.effectQuality (enum eco/full/max, плоский ключ); throttleInBackground→не берётся. Каждое новое значение: enum + jsonKey, решение о shipped, effectX/effectXNote в app_ru.arb и app_en.arb (switch _title исчерпывающий — effect_details.dart:64-79), строка в effect_settings_test:18-45, проверка лестницы в effect_preset_test.
- Предложение по shipped (решение владельца): embers, grain (cartridge grainAlpha 0), glass, heroParallax — включить; plume, launchRitual — выключить; liquidSelection и selectionFrame — включить только после слияния с материалом капли и правилом клавиатурного фокуса. Дизайн включает всё (effects.dart:44-55), но у него нет ни Картриджа, ни CI под xvfb.
- Курсор: один PointerTrail в оболочке (в долях окна, settling → wantsFrames) кормит плюм, параллакс героя, свет кромки капли/стекла; GameWave.WaveTrail и field.pointer частиц переезжают на него постепенно. С геймпада курсора нет — свет стоит слева сверху, параллакс не двигается: это нормально, как у дизайна (glass_surface.dart:35-49).
- Звук (EvSoundScope в EvFocusable/EvGameCard/EvPlayButton, flutter_soloud) — вне этой линзы и вне плана; при переносе виджетов вызовы вычищаются.
- Ответы, которые нужны от владельца до правок: удержание «Играть» на геймпаде (NavAction.primaryAction — дискретный, input_scope) — заводить ли удержание в GamepadService; включать ли liquidSelection по умолчанию; допускается ли BackdropFilter на полосах каркаса при живом AmbientLight (ambient_light.dart:13-15 отвергал его на окно целиком, полосы — меньше).

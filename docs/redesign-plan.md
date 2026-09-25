# План обновления интерфейса Evaporate по образцу evaporate_design

Каждая фаза — отдельный коммит с зелёными воротами (`dart tool/gate.dart`), не длиннее двух дней. Одна работа лежит ровно в одной фазе: хеджей «если предыдущая не сделала» нет, порядок строгий. Факты сверены по коду evaporate (`main`, HEAD `169cf63` плюс незакоммиченный B6) и evaporate_design; проба шейдера `redesign-research/probe/shader_probe_test.md` прогнана и зелёная.

## Цель и границы

Взять из evaporate_design облик — палитру Magma, каркас (рейл слева, полоса сверху, подсказки снизу), раскладки героя, строки задачи, ленты снимков, колонки настроек — и новые украшения (угли, зерно, стекло полос, параллакс, плюм, удержание «Играть», ритуал), **сохранив функциональность Evaporate целиком и выделение выбранной игры как оно есть**: `portal`, `foil` с переливами, `cardTilt`, `liquidDistortion`, `drops`, `liquidSelection`, `selectionFrame`, `waves`, `particles`, `ambient`, `heroSweep`, `shotsBackdrop`, `coverBackdrop`, `interfaceAnimations`.

Порядок слоёв плитки `LibraryGridTile → FoilCard → GameCoverTile/NavTile → CoverFrame(PortalSparks) → CoverFace(FoilSurface → CoverDrops → CoverArt)` не меняется. Дизайн трогает плитку в двух местах, оба снаружи искр и не над каплями: радиус выреза (Ф2) и ореол под искрами — один `DecoratedBox` между `NavTile` и `PortalSparks` (Ф7).

Данные, блоки, сервисы, `.evsave`, `library.json`, `settings.json` (плоская запись, прежние ключи) не меняются; новых зависимостей нет. Не входят: друзья, профиль, оверлей, звук, палитра команд, режимы Стена/Терминал/Пульт, сценарий первого запуска, дайджест, линза стекла, третья схема, разделы настроек дизайна без движка под ними («Чего в плане нет намеренно»).

## Допущения

Принято планировщиком; владелец может решить иначе — рядом записано, что тогда меняется.

1. **Схем две.** Magma — новые значения `EvaporatePalette.dark` и `arclight`-экземпляров расширений; Картридж получает свои значения новых полей. Иначе: третий экземпляр каждого расширения, третье значение `AppThemeMode`, `theme_test` и `hardware_surface_theme_test` на тройку — отдельная фаза после Ф2, L.
2. **Шрифты из ассетов**, `google_fonts` не подключается; Onest — только бандлом с `OFL-Onest.txt` (Ф19).
3. **Радиусы — tight в существующие константы** (`radiusChip` 3, `radiusControl` 5, `radiusPanel` 8), `radiusSelection` 12 остаётся, потолка нет. Обложка режется `radiusPanel` 8 = `PortalOutline.corner` (`portal_outline.dart:22`); golden искр не переснимается — эталон снят на `PortalSparks` с голым `ColoredBox` (`portal_sparks_test.dart:372-378`). Иначе (5): шов между кромкой искр и углом остаётся, golden не задет.
4. **Иконки — Material `*_outlined`**, `flutter_svg` не берётся; шрифт из 39 SVG и новый знак — Ф19 по решению владельца.
5. **Каркас — геометрия дизайна, содержимое Evaporate:** рейл 76, полоса 58, подсказки 32, экран под полосами (как у `EvShell`; исполнено иначе — разделы стоят между полосами, под ними только фон панели, см. 0012); в полосе `WindowDragArea` и клавиши окна, в строке `EngineReadout` и `ButtonHints`; четыре раздела, `LiquidSelection` в рейле, `FadeIndexedStack`. Стекло полос — фазой за каркасом, за флагом.
6. **Библиотека — вертикальная сетка с вкладками-полками**; герой — `FeaturedGame` 238/128 с телом из дизайна; `Shelf.recent` — выборка; наведение по-прежнему выбирает игру.
7. **Страница игры остаётся страницей**; берутся липкая полоса действий и две колонки.
8. **Загрузки** — приборы на истории `DownloadHistoryBloc`; **Сохранения** — показания, устройства из `deviceName`, лента-нить при ленивом `SliverList`; **Настройки** — колонка с якорями над теми же карточками.
9. **Эффекты:** все evaporate-овские сохраняются; новые `LibraryEffect` — `embers`, `grain`, `glass`, `heroParallax` (в `shipped`), `plume`, `launchRitual` (выключены). Качество — `Appearance.effectQuality` (eco/full/max, плоский ключ). Удержание «Играть» — **плоское поле `AppSettings.holdToPlay`**, выключено, одновременно на геймпаде; не в `StartupSettings` (тот «читается ровно один раз, на старте», `startup_settings.dart:8-9`). Один курсор `PointerTrail`; одни часы `DecorationClock`/`decorationMayRun`.
10. Не берутся: друзья, профиль друга, оверлей, звук, скелет и полоса сценария, дайджест; «Профиль» — не раздел.
11. **Порядок:** B6 коммитится первым. B12 — с каркасом (Ф4), B13 — со страницей игры (Ф8), B14/B15 закрываются в настройках (Ф11), B10/B11 — с типографикой (Ф12). **Уточнение к «B7–B9 с эффектами»:** B7 — в Ф3; B8 и B9 закрываются там, где открывается файл («B8/B9, часть»; итог — Ф11 и Ф4), иначе файлы эффектов откроются дважды.

## Принципы

- **Ворота зелёные после каждой фазы.** Не сдаётся за два дня — делится. Коммит по команде владельца.
- **Ни одного числа облика по месту.** Число дизайна становится ступенью (`EvaporateSpacing`, `EvaporateAlpha`, `EvaporateIconSize`), ролью, токеном (`context.motion`, `EvaporateTheme.radius*`, `EvaporateLayout`) или полем расширения с экземплярами `arclight`/`cartridge`; новое число раскладки учит `_layoutHere` в той же фазе. `Color(...)` — только в `lib/ui/theme/`. Файлы дизайна не копируются — переписываются.
- **Эффекты не трогаются в той цепочке, где живут.** Файлы с записями в `_curves`/`_alphas`/`_durations`/`_longClosures` не переименовываются, их `build` не удлиняются. Между `FoilSurface` и `CoverArt` — ничего; обрезки над `PortalSparks` — никакой; просвет сетки ≥ каймы 48.
- **Храповики только убывают:** новая запись запрещена, исправленное вычёркивается тем же коммитом, переименованный файл правит путь в записи.
- **Одни часы.** Новое украшение — `DecorationClock` или `DecorativeMotion`, правило — `decorationMayRun`; своих `Ticker`/`Timer`/`AppLifecycleListener` нет. Держатся инварианты: одна `PortalSparks.enabled`, одна анимирующая `FoilCardState`, один `DecorativeMotion` на странице игры (`game_page_effects_test.dart:191`) и ни одного у голой клавиши (`:66`).
- **Новое украшение — значение `LibraryEffect` с `jsonKey`,** решение о `shipped`, пара ключей ARB, строка в `effect_settings_test`, лестница в `effect_preset_test`; `EffectPreset.full` включает всё.
- **Выбор — в `NavigationBloc`;** новый вид плиток регистрирует `controller.tileKey` и подаёт `targetKey` из `hovered ?? selected`.
- **Новое состояние — блок**; настройки — только `SettingsPatched(patch)`; частые события — `FrequentEvent`.
- **Каждый новый файл — с тестом** зеркалом в `test/` (`_reportedNowhere` и `thinFiles` не пополняются); переписанный тонкий файл дорастает и уходит из `thinFiles`.
- **Все строки — в `app_ru.arb` + `app_en.arb`;** удалённый виджет уносит ключи. Переименование класса или пути — с правкой документов тем же коммитом (`docs_names_test`).
- **Решения не дописываются задним числом**; имена дизайн-системы в записях — без обратных кавычек (`docs_names_test` требует CamelCase-имя в кавычках в коде evaporate).
- **Честность данных:** показание, которого нет у движка или блока, не рисуется.
- **Файл открывается один раз.** Единственное исключение — `info_section.dart` (Ф8 раскладка, Ф11 `InfoRow → SettingRow`).

## Карта украшений

| Украшение | Живёт | Держит | Фазы | Как переживает |
|---|---|---|---|---|
| portal | `effects/portal/*`; `CoverFrame` снаружи `ClipRRect` | `portal_sparks_test` (golden: `over == 0`), `_longClosures` portal_sparks: 30 | Ф2 (вырез 8), Ф7 (ореол) | Вырез = `PortalOutline.corner`; ореол — `DecoratedBox` снаружи `PortalSparks` |
| foil, переливы | `effects/foil/*`; `FoilSurface` в `CoverFace` | `library_effects_test` (`builds == 1`, одна `FoilCardState`), `_curves` foil_motion: 1, `_alphas` foil_surface: 2 | Ф1 (кольцо), Ф3 (B7) | Кольцо `libraryInkColors` под Magma; sheen не берётся |
| cardTilt | `FoilMotion.perspective` | те же | — | Два числа в `foil_motion.dart`; параллакс на плитку не идёт |
| liquidDistortion | `FoilMotion.distortion` | `effect_settings_test` | — | Едет с `FoilCard` |
| drops | `effects/cover_drops.dart` между `FoilSurface` и `CoverArt` | `cover_drops_test`; `thinFiles` cover_drops: 44 | Ф3 (шейдер в тесте) | Порядок слоёв и 2:3 не меняются |
| liquidSelection | `widgets/liquid/*`; 'grid-liquid', 'rail-liquid', 'shelf-liquid' | `liquid_selection_test`, `_durations` liquid_selection: 1, `_curves` liquid_selection_path: 3 | Ф3 (B8), Ф4 (рейл), Ф6 (четвёртая вкладка) | Замер по `GlobalKey` не меняется; материал капли дизайна не берётся |
| selectionFrame | `NavTile.showFocusBorder`; `independent` | `effect_settings_test`, `effect_preset_test` | Ф2 (радиус `NavTile`), Ф7 | Механика фокуса не меняется |
| waves | `effects/game_wave.dart`; хост раздела, key 'library-wave' | `game_wave_test`, `library_effects_test:467`, `_longClosures` game_wave: 43 | Ф1 (цвета), Ф3 (`PointerTrail`), Ф4 (хост) | Условие и ключ едут с хостом |
| particles | `library_atmosphere.dart` + `particle_field.dart` | `library_effects_test`, `_longClosures` library_atmosphere: 40, `_alphas`: 2 | Ф3 (B7, курсор), Ф13 (угли/зерно) | Тот же художник, один `RepaintBoundary` |
| ambient | `shell/ambient_light.dart` вокруг `ShellLayout` | `color_palette_test` (`ambientHues`), `hardware_surface_theme_test` | Ф5 (стекло читает), Ф15 (плюм поверх) | Подложка под всем |
| heroSweep | `effects/hero_sweep.dart` вокруг `Stack` в `FeaturedArt` | `_curves` hero_sweep: 1 | Ф6 | Снаружи `Stack` кадра, под текстом |
| shotsBackdrop | `shots_backdrop.dart` → `DecorativeMotion` → `ShotsSlideshow` | `shots_backdrop_test`, `_longClosures` shots_slideshow: 40, `_curves`: 1 | Ф14 | Сдвиг входит в кадр |
| coverBackdrop | `detail/cover_backdrop.dart` под `GamePage` | `cover_backdrop_test` | Ф8 | Фон под липкой полосой |
| interfaceAnimations | `rise_in.dart`; `FadeIndexedStack` | `library_grid_test`, `_durations`/`_curves` rise_in: 1 | Ф3 (B8), Ф4 (сдвиг в стеке) | `FadeIndexedStack` остаётся |

## Фазы

### Ф0. B6 доводится до зелёных ворот и коммитится

**Цель.** В дереве незакоммичен B6: новый `lib/ui/widgets/decoration_clock.dart` и правки `foil_card`, `library_atmosphere`, `decorative_motion`, `liquid_selection`, `window_visibility` (`decorationMayRun`), `library_effects_test`, `CLAUDE.md`, `TODO.md` — ровно файлы сохраняемых эффектов. **Что видит человек.** Ничего нового.

**Шаги.**
- Убедиться, что тест «фон, построенный при скрытом окне, часов не пускает» (`library_effects_test.dart:118`) падает без правки: `git stash push -- lib/` → **только** `flutter test test/ui/library/library_effects_test.dart` → `git stash pop`. Ворота гонять нельзя: нетрекнутый `decoration_clock.dart` импортирует `decorationMayRun`, которого на HEAD нет.
- После `pop` — `dart tool/gate.dart`. Локально Flutter 3.47.5, CI — 3.47.4; при предупреждении о версии сверить `dart format` на CI-версии.
- `decoration_clock.dart` не в `_reportedNowhere`, ≥ 50 %; три потребителя — `lonelyShared` проходит.

**Готово, когда** ворота зелёные, `git status` чист, B6 — `[x]`. **Объём.** S. **TODO.** B6.

### Ф1. Решение 0010 и палитра Magma как значения ночной схемы

**Цель.** Сменить облик ночной схемы без третьего экземпляра и ветвлений. **Что видит человек.** Ночная схема оранжево-чернильная: корпус `#06060A`, оранжевое главное действие, циан на показаниях; искры, фольга, капли — в своих цветах; Картридж прежний.

**Шаги.**
- `docs/decisions/0010-magma-as-night-scheme.md` (**новый**): две схемы, Magma — значения; радиусы tight в константы и обложка на `radiusPanel` (делается в Ф2); отклонены Nebula/Cryo, потолок радиуса, `google_fonts`, `flutter_svg`, `ink3`/`ink4` как текст. Строка в реестре. Имена дизайн-системы — без обратных кавычек.
- `lib/ui/theme/palette.dart`, `dark` (образец `evaporate_design/lib/design/tokens.dart`, `EvColors.magma`):

  | Поле | Было | Станет | Контраст (`look.md`) |
  |---|---|---|---|
  | background / railBackground | 0xFF06080B / 0xFF080B0F | 0xFF06060A / 0xFF0A0B11 | — |
  | surface / surfaceHigh | 0xFF0D1116 / 0xFF18202A | 0xFF0E0F16 / 0xFF15161F | — |
  | outline | 0xFF26303B | 0xFF22242F | 1.31 к background ∈ (1.2, 6.0) |
  | textPrimary | 0xFFECE6D8 | 0xFFF2F3F7 | 17.2 / 16.2 / 18.2 ≥ 7 |
  | textSecondary | 0xFF9BA6B2 | 0xFFA8ACBD | 8.47 / 7.97 / 8.96 ≥ 4.5 |
  | primary = primaryFill | 0xFFE9C877 | 0xFFFF7A18 | 7.33 / 6.90 / 7.75 |
  | onPrimary | 0xFF0A0D11 | 0xFF170800 | 7.51 на hot1 |
  | accent = accentFill | 0xFF49B7E0 | 0xFF5EE7FF | 13.1 |
  | warning | 0xFFF2A93B | 0xFFFFC24D | 11.9 |
  | danger = dangerFill / onDanger | 0xFFE96A5C | 0xFFFF4D5E / 0xFF0A0D11 | 5.89; 6.00 на заливке |
  | glow / depth | золото / прозрачный | 0xFFFFC24D / 0xFFC93A05 | материал |
  | selection (= railIndicator) / onSelection | 0xFFE9C877 | 0xFFFFC24D / 0xFF0A0D11 | 12.1 (hot1 дал бы 7.46, но сливается с `portalRim`) |

  `ink3`/`ink4` не заводятся (4.06 и 2.2). Комментарии `palette.dart:11,83,126` («золото») переписать.
- `theme_test.dart:37` — точный `dark.selection` тем же коммитом; `library_effects_test.dart:112` пришпиливает `EffectsPalette.arclight.particleBase` — новое hot2 там же.
- `decor_colors.dart`: кольцо `libraryInkColors` вокруг hot2/hot1/cool/arc (первый = последний, `color_palette_test`); `heroEyebrow` → hot2; `heroShadeStrong/Middle/Clear`, `heroPanel` (строки 39–45; читает `featured_art.dart:87-112`) пересчитать от новых `06060A`/`0E0F16` с теми же альфами, иначе герой останется сине-чёрным. `portalSpark`, `portalRim`, `foilHighlight`, `artSweep`, `ambientHues` не трогать.
- `effects_palette.dart`, `arclight`: `waveColors` → hot2/cool/hot1/ink2 (четыре непрозрачных без повторов, ≠ cartridge), `particleBase` → hot2. Комментарии про золото в `typography.dart:83`, `CLAUDE.md` («Оформление»), `README.md:479`, `README.en.md`.

**Стражи.** `theme_test`, `color_palette_test`, `library_effects_test`, `liquid_selection_test` (перекраска в `onSelection`), `docs_names_test`; golden не задет. Превью `LIQUID_PREVIEW`/`PORTAL_PREVIEW` глазами.

**Готово, когда** ворота зелёные, превью в PR, 0010 в реестре. **Объём.** S–M: 3 файла темы, 2 теста, 4 документа. **Решения.** 0010.

### Ф2. Радиусы tight, тени, стекло как поля темы, тема клавиши запуска (+B8, B9 часть)

**Цель.** Довести токены до дизайна там, где виджеты возьмут их сами; каждое новое поле темы получает читателя здесь же. **Что видит человек.** Углы 8/5, обложка режется 8 — угол совпал с кромкой искр; «Играть» с градиентом hot2→hot1 и тёмным торцом, «Скачать» — холодная заливка; тень кадра глубже; стекло карточек и ленты размыто сильнее, заливка тоньше.

**Шаги.**
- `evaporate_theme.dart:36-38`: `radiusPanel` 6 → 8, `radiusControl` 4 → 5. `_railTheme` (`:87,239`) настраивает `NavigationRail`, которого в `lib` нет, — убрать (B8).
- Плитка: `cover_frame.dart:34` — `ClipRRect` и подложка тени на `radiusPanel`; `nav_tile.dart:62` — радиус чернил и рамки на `radiusPanel`. Искры не меняются.
- `hardware_surface_theme.dart:97-98,113-114`: `frameShadowBlur`/`frameShadowDrop` arclight → 54/26 (образец `evaporate_design/lib/design/theme.dart:37-43`). `tileGlowBlur` сюда **не** заводится — читатель появляется в Ф7.
- `glass_surface_theme.dart`: новые `blurSigma`, `saturation`, `brightness` (arclight 22 / 1.6 / 0.68 по `frost`, `glass_style.dart:99-103`; cartridge 12 / 1.1 / 1.0 — дневных значений в дизайне нет, назначены планировщиком); `fillOpacity` arclight 0.9 → 0.62, cartridge 0.94 → 0.72 — иначе сквозь стекло ничего не проступит. Каждое поле — в `lerp`, `copyWith`, `values`.
- Читатели стекла: `glass_surface.dart` — `static const blur = 16.0` (`:26`) уходит; `radius = 24` в умолчаниях (`:13,35,80`) → обязательный параметр (B8, B9); фильтр собирает статика `GlassSurface.filterOf(theme)` — `ImageFilter.compose(outer: blur(blurSigma), inner: ColorFilter.matrix(…))`. `sliver_glass_clip.dart:104` строит фильтр той же статикой; `snapshot_history.dart:93` передаёт тему вместо `GlassSurface.blur`, `_GlassSliver.radius = 24` уходит (B8).
- `lib/ui/theme/launcher_button_theme.dart` (**новый** `ThemeExtension` `LauncherButtonTheme`, `arclight`/`cartridge`): заливка запуска (arclight — градиент hot2→hot1→hotDeep, `playFill` `tokens.dart:119`; cartridge — плоский `primaryFill`), заливка загрузки (arclight — градиент в тонах `accent` по `_coolFill`, `ev_play_button.dart:322-325`; cartridge — `accentFill`), ядро, прозрачности ореола покоя/подсветки (сегодня `lit ? 0.34 : 0.18` по месту, `launcher_action_button.dart:143`), `ringInset` 11 и `ringBlur` 3 кольца заряда (читатель — Ф16). `EvaporateTheme._build`: расширение обеим схемам; `scrollbarTheme`, `textSelectionTheme` от токенов (образец `theme.dart:121-133`).
- `launcher_action_button.dart`: заливка, ядро и ореол из темы; параметр `tone: LauncherTone {launch, download}` (**новый** `enum` там же) — тон передают `featured_actions.dart:32`, `play_actions.dart:31` (launch), `download_start_actions.dart:31` (download). `enabled ? 1 : 0.45` (`:58`) → ближайшая ступень `EvaporateAlpha` (B9). Размер 48×≥112 и одно срабатывание не меняются.

**Стражи.** `theme_fields_test.dart:22-28` — `'LauncherButtonTheme'` в `containsAll`; `hardware_surface_theme_test` — новое расширение смешивается по всем полям, поля стекла различаются у схем; `theme_structure_test:307-320`; `theme_test` (`onPrimary` на `primaryFill`; hotDeep в торце, не под надписью); `game_page_effects_test:50-51`; `sliver_glass_clip_test` («подложка под картой размыта», «скругляется вся карта») и `snapshot_history_test` — с темой вместо статики; `portal_sparks_test` без правки эталона. **Новый** `test/ui/library/cover_frame_test.dart`: в углу между вырезом 8 и кромкой 8 тёмных пикселей нет сверх допуска.

**Готово, когда** ворота зелёные; `_radii` пуст; `grep GlassSurface.blur lib` и `grep NavigationRailThemeData lib` пусты. **Объём.** M: 5 файлов темы (1 новый), 2 плитки, 4 виджета, 3 потребителя клавиши, 5 тестов (1 новый). **TODO.** B8, часть (`_railTheme`, радиусы 24); B9, часть (`launcher_action_button:58,143`). **Решения.** — (радиусы в 0010).

### Ф3. Фундамент эффектов: шейдер в тестах, PointerTrail, качество, B7, B8 часть; решение 0011

**Цель.** То, что нужно нескольким новым украшениям сразу, — до первого из них. **Что видит человек.** Переключатель «Качество: эко / полное / макс» в «Живой библиотеке»; поведение прежнее.

**Шаги.**
- **Шейдер в тестах — факт.** `flutter test` собирает `assets/shaders/drops.frag` из `pubspec` (проба на 3.47.5; CI 3.47.4 — «Риски»). Первым коммитом — в `cover_drops_test.dart` группа с настоящей программой в `setUpAll` (образец `evaporate_design/test/atmosphere_test.dart:45-52`): `useProgram(Future.value(program))`; чтение обложки (`cover_drops.dart:85`) под `tester.runAsync`; затем фиксированное число `pump`, **не** `pumpAndSettle` — тикер `DecorativeMotion(enabled: true)` не остановится. Ожидание: `CustomPaint` с ключом `'cover-drops'`, снимок `RepaintBoundary` не чёрный. `useProgram` остаётся для отказов; комментарий `cover_drops.dart:44-45` правится; `thinFiles` `cover_drops.dart: 44` уходит.
- `lib/ui/widgets/pointer_trail.dart` (**новый**): `PointerTrail` — `ValueListenable<Offset>` в долях окна + `settling` + `hasInput`; `PointerTrailScope` — `InheritedWidget` со `State` на миксине `DecorationClock` (`wantsFrames = settling`; **не** `DecorativeMotion` — `game_page_effects_test:191` считает их по дереву) и `Listener(translucent)` в `AppShell` (внутри `InterfaceScale`). Образец — `ev_pointer.dart`; без курсора `Offset(0.5, 0.4)` (`:13`), при `disableAnimations` — `jumpTo` в центр. Потребители переезжают здесь же: `GameWave` читает `PointerTrail.of` и переводит доли окна в доли своей области; `WaveTrail` (`game_wave.dart:16-19`), `MouseRegion` волны и `@visibleForTesting this.trail` упраздняются, `_longClosures` `game_wave: 43` уменьшается; `game_wave_test` подаёт указатель через `PointerTrail`. У частиц `Offset? pointer` — локальные пиксели, `null` = «курсора не было» (`particle_field.dart:29`): `null` — пока `!hasInput`. Три потребителя — `lonelyShared` доволен. Тест `test/ui/widgets/pointer_trail_test.dart` (**новый**).
- `lib/models/effect_quality.dart` (**новый**, чистый Dart): `EffectQuality {eco, full, max}`, `factor` 0.5/1/1.6, `blurScale` 0.55/1/1.15 (`evaporate_design/lib/design/effects.dart`); `Appearance.effectQuality`, ключ `'effectQuality'`, незнакомое → `full`; `model_roundtrip_test`. Сегменты в `effects_card.dart` (ключ `'effects-quality'`), ARB `effectQuality*`. `EffectPreset` качество не трогает.
- B7: `@visibleForTesting` на крючках; `targetRect/targetIdentity` (`library_atmosphere.dart:34-35`) убрать; рендерер портала — на `field.tailOf` (`portal_spark_field.dart:111`; `portal_renderer.dart:83-84`). Тест `library_effects_test.dart:473-514` переводится на `state.field.card`.
- B8, часть: `LiquidSelection.resting` и мёртвая ветка `liquid_painter.dart:27-31`, умолчание `radius = 18` (B9); `RiseIn.offset = 18` (`rise_in.dart:20`) — умолчание снимается (записи `rise_in: 1` не задеты).
- `docs/decisions/0011-effects-one-dictionary-one-clock.md` (**новый**): новые украшения — значения `LibraryEffect`; качество — множитель полем облика; часы — только `DecorationClock`, `inactive` — полная частота; шейдеры собираются в тестах; `BackdropFilter` допущен на полосах, не на окне (Ф5); плюм вне `shipped` и красится игрой (Ф15); отклонены набор эффектов прототипа, throttle в фоне, линза, звук. О ритуале — ни слова: у него своя запись (Ф17).

**Стражи.** `layering_test` (`effect_quality.dart` без Flutter); `_reportedNowhere`; `_durations` (у `PointerTrail` нет `Duration` числом); `_longClosures` library_atmosphere: 40 не растёт, game_wave: 43 уменьшается; `docs_names_test`; `bloc_lint`; `cover_drops_test`, `library_effects_test`, `game_wave_test`, `portal_sparks_test`, `liquid_selection_test`, `effect_settings_test` (качество по умолчанию `full`).

**Готово, когда** ворота зелёные на трёх системах; `cover_drops` вне `thinFiles`; `grep WaveTrail lib test` пуст; 0011 в реестре. **Объём.** M: 2 новых файла кода, модель, карточка, 5 файлов эффектов, 6 тестов. **TODO.** B7; B8, часть; B9, часть. **Решения.** 0011.

### Ф4. Каркас: рейл 76, полоса 58, подсказки 32, экран под полосами (+B12, B9 остаток, B8 и B14 часть); решение 0012

*Исполнено с отступлением, записанным в 0012:* разделы стоят **между** рейкой и строкой подсказок, а не под ними — прокрутка, догоняя фокус со стрелок и геймпада, ставила выбранное под рейку. Под полосы уходит только фон панели (волна, свет игр). Рейка и строка подсказок лежат у краёв `ShellPanel`, обойма — соседом слева в `Row` `ShellLayout`. Клавиша обоймы получила свой размер `railKey` 48×44, поэтому высот из `controlHeight` в Ф4c пять, а не шесть.

**Цель.** Геометрия дизайна на содержимом Evaporate без стекла (Ф5); содержимое лежит **под** полосами с первого дня — иначе стеклу в Ф5 нечего читать, а `shell_layout.dart` открывался бы дважды. **Что видит человек.** Слева вертикальная обойма со знаком и каплей; сверху полоса «EVAPORATE / БИБЛИОТЕКА», поиск, тема, клавиши окна; снизу подсказки и показания движка; содержимое при прокрутке уходит под полосы.

**Шаги.**
- `layout.dart`: `railWidth` 76 (**новая**), `topBarHeight` 64 → 58, `footerHeight` 40 → `hintsHeight` 32, `railHeight` уходит; `controlHeight` 48, `controlHeightCompact` 42 (**новые**, B9). Образец — `EvSpace`, `tokens.dart:269-275`. Комментарий к `wellInset` (`:62-66`, «`RackFit.chrome`») и фраза `CLAUDE.md` о `RackFit` — тем же коммитом (`docs_names_test`).
- `shell_layout.dart` — `Stack` по образцу `evaporate_design/lib/shell/ev_shell.dart:262-300`: `Positioned.fill(left: railWidth)` с `ShellPanel`, поверх — `NavigationRack`, `TopBar`, `HintsBar`. Занятое место `ShellPanel` отдаёт разделам через `MediaQuery.padding` (top 58, bottom 32 или 0 ниже `_shortHeight` 520 — строка подсказок прячется, как прятался подвал); `_compactWidth` 980 по-прежнему решает только поля 6/10; рейл при минимуме 900 всегда вертикальный. Инвариант `WindowChrome.edge` 4 < `compactInset` 6 ≤ `wideInset` 10 сохраняется.
- Разделы читают отступ (по строке): `library_body.dart` — верх колонки; `library_grid.dart:78-81` — низ сетки; `downloads_page.dart`, `settings_page.dart`, `saves_page.dart` — поля прокрутки; `game_page.dart:33` и `game_detail.dart` — верх и низ. Прокручиваемое уходит под полосы, непрокручиваемое стоит ниже них.
- `navigation_rack.dart`: колонка `NavigationKey` 48×44 (образец `ev_rail.dart:45-68`), значок без подписи, `LiquidSelection(key 'rail-liquid', targetKey: targets[section])`, `QueueBadge`, `Semantics(label, selected)`. `RackFit` уходит. Знак `_AppMark` переезжает из `top_bar_brand.dart` в файл рейла с записью `_iconSizes` (`theme_structure_test:419`); умолчание `_AppMark.size = 28` снимается (B8). Надпись «EVAPORATE» (`top_bar_brand.dart:36-44`, `fontSize: 11` по месту) уходит в крошку ролью `label`, записи `_fontSize` (`:383`) и `_textStyles` (`:409`) вычёркиваются. Боковая подсказка — **публичный** `RailTooltip` (`lib/ui/shell/rail_tooltip.dart`, **новый**, с тестом): образец `_SideTooltip` (`ev_rail.dart:390-480`) — `StatefulWidget` ~90 строк, а 0009 допускает приватный ≤ 40 и без `State`. Янтарная черта 3×22 (`ev_rail.dart:213-237`) не берётся — «Чего нет».
- `top_bar.dart`: `Stack[WindowDragArea('window-drag-region'), Row[крошка, Spacer, TopBarActions]]`; имя раздела в крошке — **отдельным `Text`** (`section_layout_test.dart:66-76` ищет `find.text(name)` целым виджетом), `reason` теста правится. Образец — `ev_top_bar.dart`. `theme_cycle_action.dart:41` — `select` по `themeMode` вместо `watch` (B14, часть).
- `app_footer.dart` → `hints_bar.dart` (`HintsBar`): `ButtonHints` (чип клавиши ролью `keycap`) + `EngineReadout`; копирайт не возвращается. Образец — `ev_hints_bar.dart`.
- `fade_indexed_stack.dart`: сдвиг на `EvaporateSpacing.cluster` рядом с проявлением на ступенях `context.motion` (образец `_PageTransition`, `ev_shell.dart:416-448`; рост с 0.994 не берём); умолчание `duration` снимается (B8); `TickerMode` детям — как был.
- B12: `ConceptTopBar` → `TopBar`, `ConceptNavigation` → `RackNavigation` (`navigation.dart` → `rack_navigation.dart`), `ConceptLibraryHeading` → `LibraryHeading`, `game_cover.dart` → `game_cover_tile.dart`, `toolbar.dart` → `library_toolbar.dart`, `window_frame.dart` → `app_window_frame.dart`; ключ `'concept-navigation'` → `'navigation-rack'`; пять ключей ARB (`app_ru.arb:1350-1354`): `concept*Label` → `section*Label`, `conceptFeaturedContinue` → `featuredContinue`; `railIndicator` → `selection`; карточки настроек в `settings/cards/` — `about_card`, `effects_card` (`LibraryEffectsCard` → `library_effects_card.dart`), `log_card`, `proxy_settings_card` и **две без суффикса**: `gamepad_settings.dart` → `cards/gamepad_settings_card.dart`, `notification_settings.dart` → `cards/notification_settings_card.dart`; тесты — в `test/ui/settings/cards/` (**новая**). Словарь шести слов в `CLAUDE.md`. Третье слово подписи (`SectionTitle`) — Ф9.
- B9, остаток: высота органа из `controlHeight`/`controlHeightCompact` в шести файлах (`featured_actions.dart:45`, `library_search_field.dart:30`, `launcher_action_button.dart:83`, `shelf_button.dart:31`, `navigation_key.dart:91`, `add_game_menu_button.dart:34`); кортеж `(6.0, 8.0) : (8.0, 10.0)` в `featured_game.dart:52` → ступени; `spacing:`/`runSpacing:` числом (25 строк) → `EvaporateSpacing`; стражу — **своя** регулярка `_wrapSpacingHere` (**новая**, свой список, «ловит / не ловит»), регулярка на прозрачность в условии (`? 0.34 : 0.18`) и на радиус в умолчании (`this.radius = 24`) — файлы чисты после Ф2–Ф3, списки пусты.
- Клавиши 1–4 **не** заводятся (вопрос владельцу).

**Стражи.** `app_shell_test` (обойма при 820×620) → рейл слева, четыре раздела `bySemanticsLabel`; `concept_shell_test.dart:57-75` → по ключам клавиш и `dx` с центром `'navigation-rack'`, файл → `shell_test.dart`; `rail_quit_test.dart:72,77` → старт по ключу клавиши, `dpadUp` до верха рейла, потом `dpadRight` по полосе; `window_frame_test` — (100, 32) в полосе 58; `display_scale_test` («на предельном масштабе в наименьшее окно всё ещё помещается навигация»: 900×578 при 1.25 — рейл и полоса влезают, подсказки ниже 520 спрятаны); `reachability_test` («диктор слышит, какой раздел открыт»); `game_page_effects_test:50-51` (48 = `controlHeight`); `liquid_selection_test:284-297`; `section_layout_test`; `_longClosures`: `navigation_rack: 49` уходит, `top_action: 29` — укоротить или оставить, `log_card` → путь `cards/`; `_layoutHere` учится `width: 76` и `height: 58|32`; `docs_names_test`, `arb_usage_test`, `localization_test`; новые файлы с тестами в `test/ui/shell/`.

**Готово, когда** ворота зелёные; `WINDOW_FRAME_PREVIEW` при 900×620 и 1280×900 — первый ряд обложек виден; геймпадом от любого раздела доходится до выхода; `grep -rn Concept lib test` пусто; `RackFit` не упоминается; шесть карточек в `cards/`. **Объём.** L: ~14 файлов `lib/ui/shell` (3 новых), `layout.dart`, 6 файлов отступов, 8 переименований, шесть карточек, 7 файлов высот + файлы `spacing:`, ~12 тестов, документы. **TODO.** B12 (кроме «третьего слова»); B9 закрыт; B8, часть (`_AppMark.size`, `FadeIndexedStack.duration`); B14, часть (`theme_cycle_action`). **Решения.** `docs/decisions/0012-shell-rail-and-glass.md` (**новый**) + строка в реестре: рейл слева, экран под полосами через `MediaQuery.padding`, `FadeIndexedStack` остаётся, стекло полос за флагом при живом `AmbientLight` (Ф5); отклонены `AnimatedSwitcher` разделов, шесть разделов, системный заголовок, минимум 1280×720, вторая метка раздела.

### Ф5. Стекло полос каркаса через BackdropGroup

*Исполнено с тремя отступлениями.* `GlassSurface` новых параметров не получил: с кантом по краям и множителем размытия их стало бы девять при храповике в семь, поэтому `ShellGlass` собирает стекло из статик `GlassSurface` (`groupedFilterOf`, `decorationOf` с `rim` и `opaque`), как `GlassSliver`. Без стекла фильтр не уходит из дерева, а выключается (`enabled`): иначе смена настройки пересобирала бы полосы; страж проверяет выключенный фильтр, а не его отсутствие. Обойма рисуется после панели (`Stack` вместо `Row` в `ShellLayout`): снимок берётся на первом стекле группы, и рейка иначе не увидела бы волны панели.

**Цель.** Три полосы читают то, что под ними, сквозь матовое стекло одним снимком фона. Сегодня полосы стеклом не пользуются (`BoxDecoration`); поля стекла и `fillOpacity` 0.62 уже в теме (Ф2), под рейкой и строкой подсказок — фон панели (Ф4, 0012), `effectQuality` в облике (Ф3). **Что видит человек.** Рейл, полоса и строка подсказок — матовое стекло: сквозь рейку и строку проступают волна и свет игр панели, сквозь обойму — свет корпуса; край содержимого не проступает — разделы стоят между полосами (0012). При выключенном «Стекле» — плотная заливка.

**Шаги.**
- `glass_surface.dart`: параметры `grouped` и `blur: bool` (образец `ev_glass.dart:197-218`). При `grouped` — `BackdropFilter.grouped(filterConfig: ImageFilterConfig.compose(outer: ImageFilterConfig(colorFilter), inner: ImageFilterConfig.blur(…, bounded: true)))`: общий снимок берут только фильтры, созданные `grouped`. При `blur: false` — `DecoratedBox` с заливкой из **нового** поля темы `opaqueFillOpacity` (arclight 0.9, cartridge 0.94 — прежние `fillOpacity`; множитель ×1.7 образца — число облика вне темы). Умолчания `grouped: false`, `blur: true` — прежние потребители облика не меняют; блок `GlassSurface` не читает.
- `lib/ui/shell/shell_glass.dart` (**новый**, `ShellGlass`): единственное место, знающее флаг и качество — `select<SettingsBloc>` (`shows(LibraryEffect.glass)`, `effectQuality.blurScale`) → `GlassSurface(grouped: true, …)`. В `lib/ui/shell`: три полосы одной папки. Свет кромки от курсора не берётся; статический свет «слева сверху» дизайна — это уже `rimOpacity` и `counterLightOpacity` темы. `EvScrollEdge`, `glowCorner`, hover-свечение и нажатие ×1.035 — «Чего нет».
- `top_bar.dart`, `hints_bar.dart`, `navigation_rack.dart`: `BoxDecoration` → `ShellGlass`; `shell_layout.dart`: `BackdropGroup` — общий предок `Row` (обойма слева, `ShellPanel` с рейкой и строкой подсказок у своих краёв, 0012); `ShellPanel` остаётся неплотной.
- `library_effect.dart`: `glass('glassEnabled')` в `shipped`; `effect_details.dart` (исчерпывающий `switch`); ARB `effectGlass`, `effectGlassNote`.

**Стражи.** **Новый** `test/ui/shell/shell_glass_test.dart`: без стекла `BackdropFilter` в полосах нет; три полосы делят один `BackdropKey`; `ShellGlass` без `SettingsBloc` не собирается, `GlassSurface` — собирается. `effect_settings_test`, `effect_preset_test`; `hardware_surface_theme_test`, `theme_fields_test` (`opaqueFillOpacity`); `library_effects_test` (`inactive` не меняется); `window_frame_test` — второй снимок `WINDOW_FRAME_PREVIEW` в `EvaporateTheme.light()` (подписи на стекле Картриджа глазами: `theme_test` на размытой подложке не меряет); `theme_structure_test`; `widget_structure_test`.

**Готово, когда** ворота зелёные; `--smoke` на трёх системах; на слабой машине прокрутка сетки при стекле ≥ 30 к/с (руками); при провале `glass` уходит из `shipped` одной строкой. **Объём.** M: 8 файлов `lib` (1 новый), два ARB, 5 тестов (1 новый). **Решения.** — (стекло за флагом записано в 0012).

### Ф6. Библиотека: тело героя, полка «Продолжить», пустая полка с тремя входами

*Исполнено с отступлениями.* Точка сохранения в 238 точек под названием в две строки не влезает — уходит на страницу игры (Ф8), как план и допускает; описание из кадра ушло, как у прототипа в низком кадре. Строка причины (облик `EvCtaNote`) встаёт на место чипов, когда главная клавиша погашена, — вместе с чипами кадр не вмещал её. Ключ вкладки — `tabRecent`, рядом с `tabAll` и соседями, а не `shelfRecent`. Бросок в пустой полке — подсказка, а не зона-клавиша: приёмник уже стоит вокруг полки. Замыкание `LibraryBody` не выросло от `onScan`, но и не укоротилось (28). Вторая клавиша кадра стала гибкой: в наименьшей ширине надписи она переполняла ряд. `section_layout_test` мерит настоящими шрифтами (`loadAppFonts`): служебный набирает панель вдвое шире, и четвёртая вкладка переносила её там, где у человека она стоит строкой.

**Цель.** Раскладка дизайна внутри существующих высот героя. **Что видит человек.** В крупном кадре: метка → название → чипы (статус, размер, наиграно; у идущей игры — чип «идёт» без таймера) → клавиши → точка сохранения; вкладка «Продолжить»; пустая библиотека предлагает скан, magnet и бросок.

**Шаги.**
- `featured_poster.dart`: раскладка по `evaporate_design/lib/library/ev_hero.dart:245-341` (`_body`), чипы — `TonedChip`; высоты 238/128 и порог 520 не меняются; затемнения `featured_art.dart:87-112` — при надобности. Семь состояний дизайна (`hero_state.dart:10-32`) → шесть `GameStatus`; CTA решает `primaryActionFor`; из `hero_cta.dart` берётся облик `EvCtaNote`; `EvInstallBox` не нужен; `EvRunningPill` с таймером идёт на страницу игры (Ф8) — в герое чип без секунд, иначе перестройка `FeaturedGame` каждую секунду упёрлась бы в `_longClosures` и `builds == 1`. «Точка сохранения» — образец `EvSavePointCard` (`ev_return_widgets.dart:18-81`): из последнего `SaveSnapshot` игры (`createdAt`, `sizeBytes`, `deviceName`) через `select` по `SavesBloc`, только в полном режиме и если влезает в 238, иначе — на странице игры (Ф8).
- `PlaytimeReadout` (`Positioned(right: 22, bottom: 22)` в `featured_game.dart:84-88`) убирается — наигранное ушло в чип: `_longClosures` `featured_game: 30` убывает, `_alphas` `playtime_readout: 1` уходит с файлом. `FeaturedCompactBar` как есть.
- `shelf.dart`: `Shelf.recent` (игры с `play.lastPlayed`, свежие сверху) — **выборка**: `library_grid_test.dart:65` «полки делят библиотеку без остатка» правится тем же коммитом; новый тест «„Продолжить“ упорядочена по последнему запуску». `ShelfTabs` — вкладка, `'shelf-liquid'` — четыре цели; ARB `shelfRecent`.
- `library_empty_state.dart`: три входа по образцу `EvLibraryEmpty` (`ev_first_run_widgets.dart:17-24`), без дышащего знака на своём контроллере (`:122-148`). «Найти установленные» — не диалог из пустой полки: `ScanSession` и `_scanning` держит `library_page.dart:228-250`, приёмник броска гаснет на время поиска (`library_body.dart:82-83`); `LibraryEmptyState` получает `onScan` — тот же колбэк, что у `LibraryToolbar`. «Указать источник» — `showAddGameDialog`; бросок — `GameDropTarget` уже вокруг; ветка «поиск ничего не нашёл» остаётся.
- `library_body.dart`: `onScan` вниз — +1 строка в замыкании `LayoutBuilder` при храповике `LibraryBody.build: 28` (`widget_structure_test:373`). Ветка `games.isEmpty ? … : …` выносится в приватный `_LibraryShelf` (≤ 40 строк); замыкание короче 28, число правится.

**Стражи.** `library_grid_test` (compact при 760, нет при 420, наведение выбирает, полки), `section_layout_test`, `primary_action_test`, `semantics_test`; новый тест пустой полки (три входа зовут колбэки; `onScan` доходит до страницы); `_roleTweaks` `featured_poster: 1` уходит, если файл без `copyWith(height)`; `_longClosures` `featured_game`, `library_body` — числа вниз; `arb_usage_test`.

**Готово, когда** ворота зелёные; при 1280×900 первый ряд обложек виден; «Продолжить» по убыванию `lastPlayed`; наигранное в кадре один раз; пустая полка запускает тот же поиск, что панель, и бросок на время поиска не ловится. **Объём.** M–L: 7 файлов `lib` (`playtime_readout` удаляется), модель, 4 теста, два храповика, ARB.

### Ф7. Плитка: бейдж, полоса и ореол снаружи цепочки эффектов

*Исполнено с уточнениями.* Ореол — доля `EvaporateAlpha.ghost` от прозрачности самого `glow` (у прототипа 0.3): полный янтарь `glow` заливал бы соседей, а ступень поверх пустого дневного цвета дала бы тёмное пятно. Бейдж — скруглённая плашка ступенью `radiusChip`, тёмная и тронутая тоном, а не кружок; запущенная игра получила `primary`, установленная осталась `accent` — прежде обе были одного цвета. Полоса загрузки — в цвете состояния задачи: идёт — `accentFill`, пауза — `warning`, сбой — `dangerFill`, очередь — приглушённый белый. Снимки превью размытия теней не показывают: тестовый движок рисует тень без размытия, поэтому ореол проверяется тестом дерева, а не картинкой.

**Цель.** Облик дизайна плитке, не касаясь порядка слоёв искр, фольги и капель. **Что видит человек.** Бейдж — полупрозрачная плашка в тоне смысла, полоса загрузки 3 px в цвете смысла, оранжевое свечение под выбранной плиткой в кайме, вокруг искр.

**Шаги.**
- `hardware_surface_theme.dart`: поле `tileGlowBlur` (arclight 42, cartridge 18; днём `glow` прозрачен, а число обязано различаться — `hardware_surface_theme_test:33-44`), в `values`, `copyWith`, `lerp`. Образец — `glow`, `theme.dart:43-48` дизайна.
- `cover_status_badge.dart`, `cover_progress_strip.dart`: облик по `EvCoverBadge`/`EvBar` (`ev_game_card.dart:190-224`, `ev_surfaces.dart:357-444`); тона — `primary`/`accent`/`warning`/`danger`. **Только облик**: `EvCoverBadge` — стекло с `BackdropFilter` над каплями на каждой плитке, не берём; бейдж остаётся значком без текста. Оба в `Stack` `CoverFace` **выше** `CoverDrops` — так и сегодня.
- `cover_frame.dart`: ореол — **новый `DecoratedBox` вокруг `PortalSparks`**, `BoxShadow(color: colors.glow, blurRadius: hardware.tileGlowBlur)` по `selected`. `PortalSparks` рисует искры первым слоем `Stack`, `child` поверх; существующий `DecoratedBox` тени лежит **внутри** и ложился бы поверх искр, а внешний красит decoration до `child` — ореол под искрами. Внутри `Transform` `FoilCard`; `portal_sparks.dart` не трогается; параметров у `CoverFrame` не прибавляется. Sheen дизайна не берётся. Просветы 28/32 не уменьшаются.
- `nav_tile.dart`: рамка и рост 1.06 без нового правила — «только с клавиатуры» на десктопе пусто: мышь `FocusHighlightMode` не переключает, `InkWell` фокус по клику не берёт. Наклон до 11° — только по решению владельца.

**Стражи.** `effect_settings_test` (одна `PortalSparks.enabled`), `semantics_test`, `library_grid_test`, `portal_sparks_test` (golden не задет), `cover_drops_test`; `_alphas` — ореол через `colors.glow` без `withValues(alpha:)`; `hardware_surface_theme_test`, `theme_fields_test`; `cover_frame_test` (Ф2) дополняется: «выбранная плитка светится, невыбранная нет», «`DecoratedBox` ореола — предок `PortalSparks`, не потомок».

**Готово, когда** ворота зелёные; `PORTAL_PREVIEW` — искры без обрезки; `cover_frame_test` подтверждает ореол и его место. **Объём.** S: 4 файла `lib`, 3 теста.

### Ф8. Страница игры: липкая полоса действий, две колонки, таймер идущей игры (+B13, B14 и B15 часть)

**Цель.** Раскладка листа дизайна на странице внутри раздела. **Что видит человек.** Шапка с обложкой фоном, под ней липкая полоса «Играть / действия» постоянной высоты (у идущей игры — таймер), тело в две колонки от 900: слева описание, ход загрузки, предупреждение, файлы, сведения; справа 300 — пути сохранений, снимки (с точкой сохранения, если герой её не вместил), Steam и удаление.

**Шаги.**
- `game_detail.dart`: `ListView` (`:38`) → `CustomScrollView`: `SliverToBoxAdapter(DetailHeader | DownloadingHeader)` → `SliverPersistentHeader(pinned, ActionBar)` → две колонки. 940 (`:37`) → `EvaporateLayout.detailMaxWidth`, правая колонка — `detailSideWidth` 300 (обе **новые**); `_layoutHere` учится `maxWidth: 940` и `width: 300` после проверки, что других вхождений нет. Образцы — `ev_game_sheet.dart` (`_SheetBar` `:657`, `_SheetBarDelegate` `:930`, `:303`) и `sheet_blocks.dart` (`EvSheetBody` `:23`, порог 900 `:57`, колонка 300 `:72`); без достижений, друзей, истории сессий, «Глава 5». «Проверить целостность» из `_Verbs` (`sheet_blocks.dart:800-813`) — вопрос владельцу.
- `ActionPanel` (`action_panel.dart:26-73`) делится: в полосу — `PrimaryActions` + `SteamActions` одной строкой; `DownloadActivity`, `TaskStats`, `InlineWarning` (`:63-69`) — в левую колонку виджетом `lib/ui/library/detail/download_status.dart` (**новый**). `Card` полосы → `GlassSurface`. `game_actions_test:109` («в узком окне ряд действий переносится») меняется: полоса прячет подписи клавиш Steam. Делегат — `lib/ui/library/detail/action_bar.dart` (**новый**: `ActionBar`, `ActionBarDelegate`).
- Таймер идущей игры — по образцу `EvRunningPill` (`hero_cta.dart:130`) на настоящих данных: `GameLauncher.elapsedFor` (`game_launcher.dart:66`) через `context.read<LibraryBloc>().launcher` (`library_bloc.dart:244`, геттер с `ignore`). `RunningGameActions` (`thinFiles`: 0) получает приватный `_RunningTimer` (≤ 40 строк) на `Stream.periodic` в секунду: это данные, не украшение, часы `DecorationClock` ему не по чину; перестраивается только текст. Файл уходит из `thinFiles`.
- `sliver_side_by_side.dart` → `lib/ui/widgets/` (второй потребитель): сегодня фиксирована **левая** колонка (`:12-17`), на сохранениях узкая слева (430); виджет получает `leftWidth?`/`rightWidth?` (ровно одна), тест переезжает в `test/ui/widgets/` со случаем «правая узкая».
- `game_page.dart`: `CoverBackdrop` под всей страницей, включая полосу. `game_page_effects_test.dart:173` — переменная `GAME_PAGE_WIDTH` рядом с `GAME_PAGE_PREVIEW` (`:149`).
- B13: `library_page.dart:119-127` — `_forgetGone`, `_repairSelection`, `_restoreFocusOnClose`, `_grabSearchFocus` из `build` в три слушателя: `BlocListener<NavigationBloc>` (`listenWhen` по `openedGameId`, `selectedGameId`, `searchFocusSeq`), `BlocListener<LibraryBloc>` на состав игр, `BlocBuilder(bloc: _view)` вместо `_view.stream.listen` (`:67-69`) — потеря выбора приходит и от поиска (`:121`).
- B14, часть: `save_paths_section.dart:63`, `snapshots_section.dart:33` — `select` по части `SavesState` вместо `watch`. B15, часть: `L.of(context)` ×12 в `info_section.dart` и ×8 в `snapshots_section.dart` → `final l`. `snapshot_summary.dart` — Ф10.

**Стражи.** `game_actions_test`, `game_page_back_test`, `game_page_effects_test` (один `DecorativeMotion`, `GAME_PAGE_WIDTH`), `semantics_test`, `input_navigation_test`, `downloading_header_test`, `sliver_side_by_side_test`, `snapshot_tile_test`, `saves_section_test`; **новый** `action_bar_test.dart`: полоса остаётся при прокрутке, высота не зависит от задачи и ошибки, контраст надписей на Картридже (`theme_test` под размытой обложкой не меряет); **новый** тест таймера. `complexity_test`, `widget_structure_test`; `thinFiles` `running_game_actions: 0` уходит.

**Готово, когда** ворота зелёные; `GAME_PAGE_PREVIEW` при 940 и 1280; полоса одной высоты у установленной, качающейся, идущей и упавшей игры; `library_page.dart` не сравнивает состояние в `build`. **Объём.** L: 8 файлов `lib` (2 новых, 1 переезд), `layout.dart`, `theme_structure_test`, 8 тестов (2 новых). **TODO.** B13; B14, часть; B15, часть.

### Ф9. Загрузки: приборы на настоящей истории, строка задачи, очередь пунктиром (+B12 «третье слово», B8 и B15 часть)

**Цель.** Приборная доска без единого выдуманного прибора; карточка задачи — строка из дизайна. **Что видит человек.** Панель показаний (приём крупнее), под ней минута суммарного графика; строки задач: обложка 40×52 (у задачи без игры — плашка со значком), имя, путь, клавиши (пауза, папка, отмена), четыре показания, полоса, «скачано / всего · осталось»; очередь пунктиром; пустой подраздел — значок и строка; отказ движка и ошибка задачи — две `InlineWarning`.

| Место | Было | Стало | Данные |
|---|---|---|---|
| Показания | `DownloadsReadout` (`ReadoutPanel`) | остаётся; первая графа крупнее — облик | `EngineStats`, `holdingSlots`, `maxConcurrent` |
| График суммы | — | `EngineRateChart` (новый) | `DownloadHistories.total` (новый геттер) |
| Строка | `TaskCard`: `TaskHeader`, `DownloadActivity`, `TaskStats` | раскладка `ev_torrent_row.dart:78-116` | `DownloadTask`, история по `task.id` |
| Очередь | `QueuedCard` рамкой | пунктир по `EvQueueRow` (`ev_torrent_row.dart:387`) | как было |
| Пусто | `QueueHint` текстом | облик `EvNothing` (`ev_surfaces.dart:448`) без действия | как было |
| Подпись подраздела | `SectionTitle` | `SectionCardHeader` в облике `EvSectionHeader` (`ev_surfaces.dart:599-633`: счётчик и линия) | — |
| Отказ движка | `EngineFailure` | `InlineWarning(engine.message ?? l.engineStopped, danger: true)` | `EngineStatus` |
| Ошибка задачи | `Text(task.errorMessage!)` | `InlineWarning(…, danger: true)` | `DownloadTask.errorMessage` |

**Шаги.**
- `download_history_state.dart` (`DownloadHistories`): геттер `total` — сумма по слотам, выровненная **с конца** (истории разной длины); тест в `test/bloc/download_history/`. Ни «пика за час», ни тепловой карты, ни кольца долей.
- `download_chart.dart`: `_SpeedChartPainter` → `speed_chart_painter.dart` (новый) с переводом двух `withValues(alpha:)` на `EvaporateAlpha` тем же коммитом — запись `download_chart.dart: 2` уходит. API `DownloadChart(task, height)` не меняется (`downloading_header_test`). `engine_rate_chart.dart` (новый) на том же художнике поверх `histories.total`; `engine_rate_chart_test` (новый). В `downloads_status_bar.dart` второго публичного виджета нет.
- `downloads_status_bar.dart`: `EngineFailure` → `InlineWarning`, ключ `engineStopped` читает замена; `engine_failure.dart` удаляется, запись `thinFiles` вычёркивается. `ReadoutPanel.wrapBelow` — умолчание снимается (B8; `readout_panel.dart:13`); первая графа крупнее — ролью `readoutLarge`, без плавного кегля `EvBigNumber`.
- `task_card.dart`, `task_header.dart`: строка по образцу; обложка — `CoverArt(game:, underStrip:)`; у чужой раздачи (`gameForTask` → `null`) — плашка со значком; `task.dir` ролью `path`. `task_actions.dart`: клавиша «папка» — новое событие `LibraryBloc` `FolderOpenRequested(path)` с `task.dir` (`GameFolderOpenRequested` берёт `installDir`, а он пишется по завершении); у `LibraryBloc` уже есть `FileManager` и `Notice`. Клавиши только у задач с игрой.
- `queued_card.dart`: пунктир — приватный `_DashedBorderPainter` (цвет `outline`, `radiusControl`); `queue_hint.dart` — значок + строка. `TaskStats`, `DownloadActivity` из строки уходят; файлы остаются, если их зовёт `download_status.dart` (Ф8), иначе удаляются с тестами.
- `section_title.dart` удаляется: `available_games.dart:31`, `queue_column.dart:65,75` берут `SectionCardHeader` (третий потребитель), который получает облик `EvSectionHeader` — счётчик и линию — видно и в карточках настроек, и в ленте снимков. Слов для подписи остаётся два, о разном: `SectionHeading` — раздел с меткой, `SectionCardHeader` — подраздел или карточка (B12 закрыт).
- B15, часть: `downloads_page.dart:40,64` — `queued.length` не передаётся виджету, у которого есть `downloads`; `QueueColumn.build` сложностью 15 — рамка приёма (`DragTarget`) и содержимое врозь; замыкания короче 25 — записи `DownloadsPage.build: 36`, `QueueColumn.build: 38` уходят; `fromLTRB(a, b, a, b)` → `symmetric` в `available_games.dart`, `queue_column.dart:30`.

**Стражи.** `download_cancel_test`, `queue_keys_test`, `hidden_page_test`, `engine_state_color_test`, `downloading_header_test`, `download_chart_test`, `available_games_test`, `snapshot_history_test` (облик `SectionCardHeader`); `task_stats_test`, `download_activity_test` — по судьбе виджетов; новые — сумма историй, `engine_rate_chart_test`, строка с путём и без игры, открытие папки, пунктир очереди; `theme_structure_test`, `arb_usage_test`, `widget_structure_test` (`_longClosures` −2), `complexity_test`.

**Готово, когда** ворота зелёные; при `FakeDownloadEngine` с двумя задачами график суммы равен сумме графиков (тест); строка чужой раздачи без клавиш и обложки; `grep SectionTitle lib` пуст. **Объём.** L: 13 файлов `lib` (2 новых, 2 удаления), событие в `library_event.dart`/`library_edits.dart`, `section_card_header.dart`; тестов ≥ 7; если тесно — строка задачи отдельным коммитом. **TODO.** B12 закрыт; B8, часть (`wrapBelow`, `PulseDot.size = 8`); B15, часть.

### Ф10. Сохранения: показания, устройства из снимков, лента-нить

**Цель.** Две панели сверху и лента на нити — на данных, которые есть; блоки не меняются. **Что видит человек.** Показания как сейчас; рядом панель «Устройства» того же корпуса: имя, платформа, «последний снимок тогда-то», «это устройство»; лента с точками на нити, чипами устройства и происхождения, `note` вместо «где остановился» — и на странице игры тоже.

| Место | Было | Стало | Данные |
|---|---|---|---|
| Шапка | `SavesReadout` | + `DevicesPanel` (**новый**) в облике корпуса `readout_panel.dart` | `entriesOf`, `syncPackages`, `deviceName`/`platform`/`createdAt`; `currentDeviceName()` (`format.dart:70-81`) |
| Колонки | `SliverSideBySide` (из `widgets/` после Ф8) | то же | — |
| Строка | `HoverBuilder` + `InsetTile` + `SnapshotSummary` | `SnapshotRow` на нити; подсветка и правило корзины сохраняются | `origin/note/createdAt/deviceName/sizeBytes` |

`ReadoutPanel` для устройств не годится: графа — «подпись/показание», а устройства — список строк с четырьмя полями.

**Шаги.**
- `lib/ui/saves/devices_panel.dart` (**новый**) и чистая `devicesOf(entries, packages)` там же; `test/ui/saves/devices_panel_test.dart` (**новый**: два `deviceName` → две строки; пакет с третьим — третья; текущее помечено). Без «в сети/офлайн». Ставится в `saves_page.dart:62-75`.
- `snapshot_row.dart`: нить и точка. Образец — `ev_thread.dart`, `ev_timeline.dart`, **но не устройство `EvThread`** (один `CustomPaint` над `Column`): у нас `SliverList.builder` (`snapshot_history.dart:57-61`), нить рисуется построчно, растворение — у первой и последней строки. Художник — приватный `_SnapshotThreadPainter` там же. Подсветка под курсором и красная корзина только под курсором (`snapshot_row.dart:14-16, 51-54`) остаются на `HoverBuilder`. `fromLTRB` (`:24`) → `symmetric` (B15).
- `snapshot_summary.dart`: показывать `note`. Второй потребитель — `SnapshotTile` на странице игры (`snapshot_tile.dart:48`): изменение видно на двух экранах. ARB: «устройства», «это устройство», «пакетов» с ICU plural.
- `thinFiles` на 0 % (`sync_folder_contents`, `sync_package_row`, `pick_game_dialog`, `bulk_outcome_group`, `bulk_report_view`): что переписывается — получает тест и вычёркивается; что нет — не трогается.
- Обход папки синхронизации при открытии раздела — не здесь: на старте `syncPackages` пуст (`saves_bulk.dart:97-118`), устройства из пакетов появятся после «Проверить» (`sync_folder_card.dart:40`). Вопрос владельцу.

**Стражи.** `saves_page_test` (смысл граф не подменять; дополняется устройствами), `snapshot_history_test` (`built ∈ [1, 40]`), `sliver_glass_clip_test`, `bulk_transfer_dialog_test`, `snapshot_tile_test`, `saves_section_test` (`note` в обоих местах); `_alphas` — растворение нити через `EvaporateAlpha`; `widget_structure_test`; `localization_test`.

**Готово, когда** ворота зелёные; второе устройство появляется после «Проверить» или импорта его пакета; `note` виден в ленте и на странице. **Объём.** M: 4 файла `lib` (1 новый), 2 ARB, `check_coverage.dart`; 5 тестов (1 новый). **TODO.** B15, часть.

### Ф11. Настройки: колонка навигации с якорями (+B14, B15, B8 закрываются)

**Цель.** Колонка дизайна над теми же 12 карточками, без каталога данных. **Что видит человек.** От 880 слева липкая колонка с пунктами и версией; нажатие прокручивает к карточке, подсветка идёт за прокруткой; ниже 880 колонка над телом.

**Шаги.**
- `lib/ui/settings/settings_nav_column.dart` (**новый**): `GlobalKey` на карточку, `Scrollable.ensureVisible`, слежение по `ScrollController` отдельной функцией; `EvaporateLayout.settingsNavWidth` 212 и `settingsNarrow` 880 (**новые**). Образцы — `evaporate_design/lib/screens/settings_page.dart` (колонка, `_spy`, `_go`), `ev_settings_widgets.dart` (`EvSettingsNavItem` `:484`, `EvSettingsHeader` `:591`).
- **Обход фокуса.** `_ListTraversal` (`settings_page.dart:93-103`) стоит на всей странице: «вниз» = `next`. В `Row` пункты колонки попали бы в ту же сортировку вперемешку с органами карточек — колонка становится своей `FocusTraversalGroup`: спуск проходит пункты, потом карточки; `_ListTraversal` остаётся приватным. Окажется иначе — вынести в `list_traversal.dart` (**новый**, с тестом).
- `settings_page.dart`: `SingleChildScrollView` остаётся (все карточки в дереве — `settings_navigation_test`), порядок прежний; `LayoutBuilder` — `Row` или `Column`.
- B14: `select` по части (`s.appearance`, `s.saves`, `s.startup`, `s.gamepad`, `s.systemNotifications`, `s.limits`) вместо `watch<SettingsBloc>()` в десяти файлах (`appearance_card`, `download_settings_card`, `save_settings_card`, `speed_limits_settings`, `window_startup_card`, `gamepad_settings_card`, `notification_settings_card`, `library_effects_card`, `effect_preset_picker`, `effect_details`); `about_card`/`about_actions` смотрят `UpdateBloc` — не в счёте. Закрыт.
- B15: `lib/ui/widgets/setting_row.dart` (**новый**) — `SettingRow(label, child, {labelWidth = EvaporateLayout.settingLabelWidth})` вместо девяти копий `SizedBox(width: settingLabelWidth)` и вместо `InfoRow` (`info_row.dart` удаляется; пять потребителей — `files_section`, `info_section`, `about_card`, `engine_info_card`, `gamepad_status_row` — переходят на `SettingRow(label, child: Text(value))`; ширина подписи одна, 220; `trailing` — B8). В `widgets/` законно: `settings/` и `library/detail/`. Расширение `context.patchSettings((s) => …)` там же вместо семи помощников и четырёх `store.add` в дереве; `gamepad_settings_card.dart:98-104` — патч от `current`, не `store.state`; `CaptureButtonDialogState` → приватный, `cancelButton` наружу статикой виджета; остаток `fromLTRB → symmetric` (`section_heading.dart:27`, `readout_cell.dart:32`, `watched_folders.dart:42`, `toolbar`, `featured_compact_bar`). Закрыт.
- Поиск по настройкам — не здесь.

**Стражи.** `settings_navigation_test` (окно 800×600 по умолчанию — ниже 880, колонка над карточками добавляет ~12 остановок при бюджете 80; широкая раскладка — свой случай через `harness.pump` 1600×1100), `settings_layout_test`, `reachability_test`, `effect_settings_test`, `display_scale_test`, `game_actions_test` («папка игры в „Подробностях“» — `SettingRow` вместо `InfoRow`); **новый** `settings_nav_column_test.dart`. `_layoutHere` учится `212` и порогу `<\s*880\b|>=?\s*880\b`, `passes` не задеты; `lonelyShared` у `setting_row.dart` — две папки; `_longClosures` `cards/log_card.dart: 41` не растёт; `thinFiles` не тоньше.

**Готово, когда** ворота зелёные; стрелками доходится до «Проверить обновления» в узком и широком окне; `grep 'watch<SettingsBloc>' lib/ui` и `grep InfoRow lib` пусты; `_layoutHere` ловит 212 и 880. **Объём.** M–L: 2 новых файла `lib`, 1 удаление, `settings_page.dart`, `layout.dart`, 10 карточек, 5 потребителей `InfoRow`, `theme_structure_test`, 3 теста (1 новый). **TODO.** B14, B15, B8 закрыты.

### Ф12. Типографика и доступ к теме (B10, B11)

**Цель.** Влить шкалу дизайна в существующие роли, не заводя второй; моторику сделать обычным классом. **Что видит человек.** Крупные показания — по решению владельца Unbounded w300 или моно w700; ролей меньше, полукеглей нет.

**Шаги.**
- `typography.dart`, B10: `small` (11.5) → `caption` (12); `pathSmall` → `path` (12), `log` от `path`; `note` (12.5) → `captionMuted` (12). Употреблений: `note` 12, `captionMuted` 10, `small` 5, `pathSmall` 2. Таблица «когда какую» в шапке; ролей сегодня 30 — цель ≤ 27.
- Соответствия дизайна (`evaporate_design/lib/design/typography.dart`): `title` 15 → `subtitle`, `data` → `figure`, `big` → `readoutLarge`; `label` (моно 9 w700 ls 1.4) и `section` (Unbounded 13 w600) — вопрос владельцу: от `label` производны `statusLabel` и `badge`, а `sectionLabel` для `SectionHeading` — новая роль против B10. Кегль строки 13 → 14 — только после замера под `section_layout_test`. Разрядка заголовков остаётся положительной.
- B11, моторика: `EvaporateMotion` остаётся `final class` с `standard` и `still` (15 мест, включая `staggerAt`), перестаёт `extends ThemeExtension`: уходят `copyWith`/`lerp`, из `extensions:` (`evaporate_theme.dart:76`) — `EvaporateMotion.standard`; `context.motion` без `Theme.of`. `EvaporateMotion.exit` — ноль употреблений — убрать (B8), фраза о трёх кривых в `CLAUDE.md` → две.
- B11, доступ: геттеры `context.surface` / `context.glass` / `context.effects` (новые) в файлах трёх расширений, 18 вхождений `.of` в 14 файлах; `navigation_key.dart:103` → `context.text.label`.
- Тесты: `theme_fields_test.dart:22-28` — убрать `'EvaporateMotion'`; `motion_test.dart:33-38` — снять «переход между наборами» (`lerp`). `motion.dart` в `_reportedNowhere` не вносится: `staggerAt` и геттер исполняемы.

**Стражи.** `fonts_test`, `section_layout_test`, `theme_structure_test` (`_roleTweaks`, `_textStyles`, `_fontSize` не растут; «один набор расширений» проходит), `theme_fields_test`, `motion_test`.

**Готово, когда** ворота зелёные; ролей ≤ 27, полукеглей нет; `grep -rn 'HardwareSurfaceTheme\.of\|GlassSurfaceTheme\.of\|EffectsPalette\.of' lib/ui --exclude-dir=theme` пуст; `EvaporateMotion` не в `extensions:`. **Объём.** M: 6 файлов темы, ~40 мест, 3 теста. **TODO.** B10, B11. **Решения.** — (0002 не задето; строка в `CLAUDE.md`).

### Ф13. Эффекты: угли и зерно в атмосфере библиотеки

**Цель.** Два самых дешёвых украшения дизайна — в тот же художник, что частицы; зерно — слой атмосферы, не окна; художник рисует `painter:`, то есть **под** сеткой (`library_atmosphere.dart:106-131`), так и остаётся. **Что видит человек.** Восходящие тёплые искры и лёгкое зерно на фоне библиотеки, между обложками; днём зерна нет.

**Шаги.**
- `lib/ui/library/effects/ember_field.dart` (**новый**): симуляция из `evaporate_design/lib/atmosphere/ember_field.dart` целиком (с `burst`/`burstFrom` — их ждёт Ф17), без своего среза шага (`FrameStep.maxStep` уже 1/30); `countFor(width, quality)` = `(width/17).clamp(34,104) · factor`. Тест `test/ui/library/ember_field_test.dart` (**новый**).
- `ember_paint.dart` (**новый**): `drawAtlas` по образцу, `paintEmbers(canvas, field, palette)`. Цвета образца зашиты (`:23`, `:80`) — становятся `AppColors.emberGlow*`/`emberCore` в `decor_colors.dart`; альфы — поля темы; `withValues(alpha: число)` в новом файле — запрещённая запись `_alphas`.
- `film_grain.dart` (**новый**): плитка 128×128 один раз на приложение, `ImageShader` + `BlendMode.overlay` (`ev_atmosphere.dart:388-401`); `paintGrain(canvas, rect, image, alpha)` там же — `paint` художника уже 39 строк при потолке 60.
- `effects_palette.dart`: `emberHot`, `emberCool`, `emberAlpha`, `grainAlpha` (cartridge 0). Различие `grainAlpha` держит только тест «зерно не рисуется на Картридже» — он обязателен.
- `library_atmosphere.dart`: угли вторым списком, зерно последним; `wantsFrames` = particles || embers || (ambient && ambientWash). Замыкание `LayoutBuilder` (`:93-133`) ровно 40 при храповике 40: россыпь флагов → одно значение `AtmosphereLook` (**новый**, в том же файле), сборка художника — в метод `_painter`; запись `_longClosures` вычёркивается. `library_body.dart:67-72`: `look: AtmosphereLook.of(effects, quality)` вместо трёх флагов — параметров четыре (иначе 8 > `wideWidgets` 7); замыкание `LibraryBody.build` короче — число (после Ф6) правится снова.
- `LibraryEffect.embers('embersEnabled')`, `grain('grainEnabled')` в `shipped`; `effect_details.dart`; ARB ×4; `effect_settings_test`, `effect_preset_test` (в `standard`, `full`, не в `calm`).

**Стражи.** `library_effects_test` — угли по флагу, гаснут при скрытом окне, `builds == 1`, прогон с углями и зерном (иначе новые файлы в `_reportedNowhere`); зерно не на Картридже; `_alphas` `library_atmosphere: 2` не растёт; `_longClosures` теряет `library_atmosphere`, `library_body` убывает; `_wideWidgets` пуст; `complexity_test`; `color_palette_test`; `theme_fields_test`.

**Готово, когда** ворота зелёные; `--smoke` на Linux под `xvfb` при `shipped`; при `eco` углей вдвое меньше. **Объём.** M: 3 новых файла, 5 правок, модель, два ARB, 1 новый тест + 4 правленых. **Решения.** — (0011).

### Ф14. Эффект: параллакс кадров героя за курсором

**Цель.** Кадр героя едет за курсором внутри `ShotFrame`, той же `FractionalTranslation`, что несёт дрейф; `PointerTrail` уже в `AppShell` (Ф3), независим от волн. **Что видит человек.** Кадры под названием сдвигаются на глубину `parallaxDepth`; текст и рамка стоят; при просьбе не двигаться — нет.

**Шаги.**
- `PointerTrail.of(context)` доезжает до подложки **областью**, не параметрами: цепочка `LibraryBody → … → ShotsBackdrop` — пять слоёв, у `FeaturedGame` шесть параметров при пределе семи.
- `shots_timing.dart`: `parallaxDepth` **долей ширины**, как `drift` (0.06). Файл в `_reportedNowhere`.
- `shot_frame.dart`: запас масштаба растёт на размах параллакса (`+ parallaxDepth * 2`); сдвиг — в **ту же** `FractionalTranslation` (`_shiftOf` в `shots_backdrop_test` читает первую над картинкой); параметр `pointer: ValueListenable<Offset>?`, `ShotFrame` оборачивает картинку своим `ValueListenableBuilder` — обновляется кадр, не подложка.
- `shots_slideshow.dart`: замыкание `builder` — строки 23–62, ровно 40 при храповике `ShotsSlideshow.build: 40`; область читается **в `build` до** `ValueListenableBuilder` и передаётся полем — замыкание не растёт; при нехватке восемь строк комментариев замыкания уходят в doc-комментарий. `_curves` `shots_slideshow: 1` — одна кривая.
- `library_featured_slot.dart`: `shotsEnabled` дополняется `shows(LibraryEffect.heroParallax)`; при выключенном — `pointer: null`. `LibraryEffect.heroParallax('heroParallaxEnabled')` в `shipped`; ARB; `effect_settings_test`, `effect_preset_test`. На плитку параллакс не идёт (`FoilMotion.tilt`). Образец — `ev_hero.dart:116-120,360-383`.

**Стражи.** `shots_backdrop_test` — «кадр сдвигается за курсором», «при `disableAnimations` стоит», «без области работает как прежде»; `_longClosures` 40, `_curves` 1, `_wideWidgets` пусто не растут.

**Готово, когда** ворота зелёные; `effect_settings_test` знает `heroParallax`. **Объём.** M: 5 файлов `lib`, модель, 2 ARB, 3 теста.

### Ф15. Эффект: плюм-шейдер в цветах выбранной игры (выключен по умолчанию)

**Цель.** Самое дорогое украшение дизайна — за флагом, вне `shipped`, в цветах игры, на общих часах, с курсором из `PointerTrail`. **Что видит человек.** При включении — пар в оттенках выбранной игры под всей оболочкой; курсор чуть сдвигает течение.

**Шаги.**
- `assets/shaders/plume.frag` (**новый**) из `evaporate_design/shaders/plume.frag`; `pubspec.yaml` `shaders:`. Шапка — о происхождении (прототип того же владельца), не лицензионная.
- `lib/ui/shell/plume_backdrop.dart` (**новый**): `State` на миксине `DecorationClock`, `wantsFrames => enabled && program != null` — **не** `DecorativeMotion` (ровно один на странице игры). Программа статикой с `useProgram`, как у `CoverDrops`; при недоступной — ничего (под ним `AmbientLight`). Место — `AppShell` между `AmbientLight` и `ShellLayout`.
- Униформы (`plume.frag:11-15`): `uRes` (0–1), `uT` (2), `uM` (3–4, y снизу вверх), `cHot`, `cHot2`, `cCool` (5–13). Функция `plumeUniforms(…) → List<double>` (**новая**, образец `setPlumeUniforms`, `ev_atmosphere.dart:302-324`). Цвета — `gameAmbientColors(title)` (`decor_colors.dart:84-96`). `uM` — `PointerTrail`. Масштаб кадра — `(0.55 · factor).clamp(0.3, 1.0) · min(dpr, 2)` (`effects.dart:19-21` дизайна). Просьба не двигаться: `t = 8`, курсор в центре (`ev_atmosphere.dart:132-134`); часы стоят по `decorationMayRun`.
- `LibraryEffect.plume('plumeEnabled')` **вне** `shipped` (`toImageSync` каждый кадр; Linux в CI — Skia под `xvfb`); в `full` автоматически. ARB.
- `test/ui/shell/plume_backdrop_test.dart` (**новый**) с настоящей программой: не рисует без флага; стоит при скрытом окне; переживает отказ программы; при «не двигаться» — `t = 8` и центр; `plumeUniforms` в 5–13 совпадает с `gameAmbientColors`. Новая группа в `game_page_effects_test`: при включённом плюме `DecorativeMotion` на странице игры по-прежнему 1.

**Стражи.** `_reportedNowhere`/`thinFiles` — новый файл ≥ 50 %; `color_palette_test`; `effect_settings_test` (плюм выключен), `effect_preset_test`; `widget_structure_test`; `theme_structure_test` (0.55/0.3/8 — параметры шейдера, а `Duration` и прозрачности по месту не писать); `arb_usage_test`.

**Готово, когда** ворота зелёные; `--smoke` не задет; при включённом флаге плюм в цветах игры и стоит при свёрнутом окне. **Объём.** M: 1 шейдер, 1 файл `lib`, значение модели, ARB, 2 теста. **Решения.** — (0011).

### Ф16. Удержание «Играть» — мышь, клавиатура и геймпад разом; решение 0013

**Цель.** Защита от случайного запуска, одинаковая для четырёх мест главного действия и кнопки X; поведение ввода — поле настроек, не `LibraryEffect`. Ведущих у заряда два: клавиша на экране (мышь, клавиатура) и `InputScope` (X геймпада); общего состояния заряда в блоке нет. **Что видит человек.** При включённой настройке «Играть» заряжается 620 мс с кольцом; отпустил раньше — ничего. X держится те же 620 мс, кольцо на кадре не рисуется (геймпад не знает, какая из четырёх клавиш «та»), подсказка в строке снизу — «Удерживайте». По умолчанию выключено.

**Шаги.**
- `app_settings.dart`: плоское `holdToPlay` (умолчание `false`, `toJson`/`fromJson`, `props`, `copyWith`). Не в `StartupSettings`, не в `GamepadBinding` (раскладка кнопок). Переключатель — `cards/gamepad_settings_card.dart` (после B14 читает `select` по `s.gamepad`; добавляется `select` по `holdToPlay`). `model_roundtrip_test`.
- `lib/input/hold_to_play.dart` (**новый**, чистый Dart): `HoldToPlayController` — `press()`, `release()`, `onFire`, подменяемая фабрика таймера. `test/input/hold_to_play_test.dart` (**новый**, `FakeAsync`): 200 мс — нет, 620 — да и один раз; отпускание сбрасывает; повторный `press` не перезапускает. Два экземпляра: клавиша и `_InputScopeState`.
- `motion.dart`: `static const hold = Duration(milliseconds: 620)`, `holdRelease` (160) — статика, не поля `standard`/`still`: «уменьшить движение» не ужимает защиту. В виджете `AnimationController(animationBehavior: AnimationBehavior.preserve)`. `motion_test`: `still` не трогает `hold`.
- `lib/ui/widgets/charge_ring.dart` (**новый**): `CustomPaint(foregroundPainter)` поверх `child`, `progress` 0…1; образец `_ChargeRingPainter` (`ev_play_button.dart:365-422`): дуга `extractPath` по `RRect`, отодвинутому наружу; `inset` и `MaskFilter.blur` — из `LauncherButtonTheme.ringInset`/`ringBlur` (Ф2), цвет — `colors.primary`. Тест **новый**: при 0 не рисует, при 1 — полная дуга.
- `launcher_action_button.dart`: `build` 59 строк при потолке 60 — сперва материал клавиши в `launcher_button_face.dart` (**новый** публичный виджет; один потребитель в той же папке — `lonelyShared` считает за папкой), потом поведение: `Semantics → Focus(onKeyEvent) → Listener → ChargeRing → LauncherButtonFace`. Параметр `hold` (умолчание `false`; параметров пять). При `hold`: заряд по `onPointerDown` и Space/Enter (`KeyRepeatEvent` не перезапускает), `onPointerUp`/`Cancel`/`KeyUpEvent` сбрасывают; без `hold` — как сегодня. **Без `DecorativeMotion`** (`game_page_effects_test:66`); дыхание ядра и блик 1050 мс не берутся. Кто считает `hold`: `featured_actions.dart` и `play_actions.dart` — `hold: action == PrimaryAction.play && settings.holdToPlay` (`select` по `bool`). `primary_action.dart` не меняется.
- `gamepad_service.dart`: поток `Stream<ButtonPhase> phases` (`ButtonPhase` — **новый** `(NavAction, down|up)` в `nav_action.dart`; `NavAction` не растёт); служба уже различает нажатие и отпускание (`_pressed`, `_handleButton`). `gamepad_service_test`: down/up; `actions` не меняется.
- `input_scope.dart`: параметр `holdToPlay`; при `true` `primaryAction` из `actions` игнорируется, `_InputScopeState` слушает `phases`, ведёт `HoldToPlayController`, зовёт `onPrimaryAction` из `onFire`. `AppShell` (`shell.dart:79`) передаёт флаг. Там же, раз файл открыт: `TypedSearchIntent` (`:42-61,280`) — «/» и по физической клавише, чтобы в русской раскладке поиск работал без переключения (`isEnabled` тот же — «„/“ в поле остаётся символом» проходит). Тесты — `input_navigation_test` («короткое X не запускает, удержание запускает один раз, отпускание сбрасывает» через фейковый поток `test_app.dart`; «/» в русской раскладке).
- `ButtonHints`: при `holdToPlay` подпись у X — `hintHold`. ARB `holdToPlay`, `holdToPlayNote`, `hintHold`.

**Стражи.** `game_page_effects_test` (при `holdToPlay` держит `EvaporateMotion.hold + 40 мс`; клавиша без `DecorativeMotion`), `primary_action_test`, `settings_layout_test`, `motion_test`; `complexity_test` (`build` клавиши < 60); `widget_structure_test`; `theme_structure_test` (`_durations`, `_curves` не пополняются); `layering_test` — правило «`lib/input` не знает `lib/ui`» сегодня не проверяется (`:24-36` держит только `bloc`, `services`, `models`, `core`) — `lib/input` добавляется, нарушителей нет; `bloc_lint`; `localization_test`.

**Готово, когда** ворота зелёные; с геймпада и клавиатуры защита одинакова; при `disableAnimations` удержание 620 мс (тест); без `holdToPlay` существующие тесты клавиши и оболочки проходят без правок; «/» ищет и в русской раскладке. **Объём.** L: модель, тема, 3 файла `lib/ui/widgets` (2 новых), 2 потребителя клавиши, 3 файла `lib/input` (1 новый), карточка, `shell.dart`, `ButtonHints`, ARB, 8 тестов (2 новых). **Решения.** `docs/decisions/0013-hold-to-play.md` (**новый**): удержание — поведение ввода на всех источниках; два ведущих вместо состояния заряда в блоке (заряд живёт меньше секунды, событие на каждый кадр кольца — состояние экрана в общем блоке); константа статикой, а не полем `still`; поле в `AppSettings`. Строка в реестре.

### Ф17. Ритуал запуска по состоянию блока (выключен по умолчанию); решение 0014

**Цель.** Ритуал дизайна (`evaporate_design/lib/launch/ev_launch_ritual.dart`, `ritual_core.dart`, `ritual_timeline.dart`), но стадии ведёт `LibraryState`, а не таймер: «удар» — когда процесс действительно поднялся. **Что видит человек.** При включении: после «Играть» — затемнение, ядро, искры; «удар» — когда игра запустилась; при ошибке затемнение уходит с сообщением. По умолчанию выключен.

**Шаги.**
- **Сначала харнес.** `test/support/test_app.dart` создаёт `LibraryBloc` без `launcher:` (конструктор принимает, `library_bloc.dart:56`). Без фейка запуск в тесте кончается только ошибкой (`_resolveExecutable` бросает раньше `Process.start`), и стадию «удар» не проверить. `TestHarness(launcher:)` и `test/support/fake_game_launcher.dart` (**новый**): `implements GameLauncher` (конкретный класс, `:38`), отдаёт `runningIds` как `ValueListenable<Set<String>>` (его слушают `DownloadsBloc` и `LibraryBloc:97`), `launch`, `terminate`, `elapsedFor`, `dispose`.
- `lib/ui/library/launch/launch_ritual_route.dart`, `ritual_frame.dart`, `ritual_core.dart`, художники по файлам (**новые**, ≤ 60 строк функцией) — образец `evaporate_design/lib/launch/*`. Стадии: `state.isBusy(launchKey(game.id))` — подготовка/снимок; `state.isRunning(game.id)` — удар; `Notice` с `isError` — прерывание (у дизайна отмены нет — здесь обязана быть). 2600 мс — нижняя граница, не расписание. `disableAnimations` ритуал проверяет сам, как образец (`ev_launch_ritual.dart:36`): краткое затемнение без вспышки.
- Искры — `EmberField.burst()`/`burstFrom(Rect)` из Ф13 на `DecorativeMotion` внутри маршрута; маршрут непрозрачен, украшения под ним встают по `decorationMayRun` — желаемо. Константы `ritual`, `flash`, `shock`, `iris` — **статика** в `motion.dart`, как `hold`; ветка brief — на самом ритуале. Аберрация — только на кадрах вспышки.
- `LibraryEffect.launchRitual('launchRitualEnabled')` вне `shipped`, в `full`; `effect_settings_test`; ARB стадий.

**Стражи.** `test/ui/library/launch/*` через `TestHarness` с фейком: «ошибка прерывает ритуал раньше удара»; «удар не раньше `running`»; brief при `disableAnimations`; `fake_game_launcher` держит контракт `DownloadsBloc`. `complexity_test`, `widget_structure_test`, `localization_test`, `layering_test`, `_reportedNowhere`/`thinFiles`.

**Готово, когда** ворота зелёные; при `LaunchException` ритуал уходит с сообщением; удар не наступает, пока `runningIds` пуст; с выключенным флагом `game_page_effects_test` не меняется. **Объём.** L: 5–6 новых файлов, харнес и фейк, модель, ARB, 4 теста. **Решения.** `docs/decisions/0014-launch-ritual-by-bloc-state.md` (**новый**): стадии по состоянию блока, а не по таймеру, и почему; фейк лаунчера как `implements` конкретного класса. Строка в реестре.

### Ф18. Сведение: умолчания, бюджет кадра, документы

**Цель.** Последнее слово о том, что горит по умолчанию, и документы. `_effectsFromJson` (`appearance.dart:154-157`) подставляет `shipped` для ключа, которого в `settings.json` нет, — новые украшения из `shipped` загорятся и у тех, кто приложением уже пользуется (вопрос владельцу). **Что видит человек.** Итоговый набор «обычно» и раздел версии в `CHANGELOG.md`.

**Шаги.**
- `shipped` (`library_effect.dart`): прежний состав не меняется; решение фазы — о новых: `embers`, `grain`, `glass`, `heroParallax` входят, `plume`, `launchRitual` — нет. На каждое — строка в `effect_settings_test`, ступень в `effect_preset_test`, комментарий у `shipped`. Если владелец включает `liquidSelection`/`selectionFrame` — то же, единственная правка существующего утверждения.
- Ряд по цене кадра «плюм > стекло трёх полос > капли ≈ частицы > портал > угли > фольга/наклон > зерно > капля» — оценка до замера (цену кадра в репозитории не меряет ничто); умолчания привязываются к ручной проверке на слабой машине с набором «обычно». Ориентир, не страж: настенное время `library_effects_test --reporter expanded` до и после серии — на ворота не ставится (§5 `TODO.md`).
- `CHANGELOG.md`: раздел следующей версии; `changelog_notes_test`. Документы под новые имена — всё, что читает `docs_names_test`: `CLAUDE.md`, `README.md`, `README.en.md`, `CONTRIBUTING.md`, записи 0010–0014. `TODO.md`: B7–B15 отмечены в тех фазах, где закрылись (B7 — Ф3, B9 — Ф4, B12 — Ф9, B13 — Ф8, B8/B14/B15 — Ф11, B10/B11 — Ф12). Сверка 0010–0014 между собой и с кодом.

**Готово, когда** ворота зелёные на пуше и `--smoke` прошёл на трёх системах с умолчаниями — ручным `workflow_dispatch` (`build-*` идут по тегу, вручную и по расписанию). **Объём.** S. **TODO.** закрытие B7–B15.

### Ф19 (по желанию владельца). Иконочный шрифт из SVG дизайна; Onest бандлом; знак приложения

**Цель.** Три независимые части, каждую владелец берёт отдельно. **Условия.** Иконочный шрифт держит только заливки, а 37 из 39 значков — обводка `stroke="currentColor"` (`build_assets.py:126-129`): нужна стадия «обводка → контур», образца в `tool/make_icon.py` нет. `test/tool/font_licenses_test.dart` принимает только OFL 1.1 — у значков лицензия не объявлена: либо `EvaporateIcons.ttf` под OFL 1.1 с `assets/fonts/OFL-EvaporateIcons.txt`, либо шрифта не будет.

**Шаги.**
- Значки: `tool/make_icon_font.py` (**новый**) из словаря `ICONS` `build_assets.py`; три стадии (обводка в контур — Inkscape или `picosvg` + `skia-pathops`; TTF — `fontTools`; генерация `lib/ui/theme/evaporate_icons.dart` с `EvaporateIcons`), зависимости в шапку и `CONTRIBUTING.md`. Размер — ступенью `EvaporateIconSize`. `evaporate_icons.dart` — таблица `const IconData`, в отчёт не попадёт: строка в `_reportedNowhere` рядом с `icon_size.dart` — единственное оговорённое пополнение списка.
- Onest: `assets/fonts/Onest.ttf` + `OFL-Onest.txt`; `EvaporateTheme.fontFamily = 'Onest'` с переписанным обоснованием; `fonts_test` (`loadFont`, цикл «w800 шире w300», ожидание семейства); `CLAUDE.md`. Раскладка — глазами в 1280×900: `section_layout_test` меряет служебным шрифтом.
- Знак: `tool/make_icon.py` экспортирует из `mark-a-vent`/`appicon-a-vent` (`build_assets.py:39-64`) PNG в `assets/branding`, `.ico` и набор macOS; правило «только на тёмной подложке» (`design/README.md:2094-2099`) — для Картриджа `mark-mono-dark`, путь ассета — поле `HardwareSurfaceTheme.brandMark` (данные, не `isDark`). Это и иконка в системе — потому вопрос владельцу.

**Стражи.** `_iconSizeHere`, `font_licenses_test`, `fonts_test`, `_reportedNowhere`, `hardware_surface_theme_test` (`brandMark`), `docs_names_test`. **Объём.** L значки, S Onest, S знак. **Решения.** При значках — запись о лицензии собственного шрифта и источнике (словарь `ICONS`).

## Порядок и зависимости

```
Ф0 → Ф1 → Ф2 → Ф3 → Ф4 → Ф5 → Ф6 → Ф7 → Ф8
                         Ф8 → Ф9, Ф10 (SliverSideBySide, download_status), Ф11 (InfoRow)
                   Ф6 → Ф12 → (Ф9, Ф10 — readoutLarge)
                   Ф3 → Ф13 → Ф17;  Ф11 → Ф16 → Ф17
                   Ф3, Ф6 → Ф14;  Ф3 → Ф15
все → Ф18;  Ф19 — независимо после Ф2
```

Ф9 и Ф10 — после Ф8 (виджет колонок и `download_status`), между собой параллельны; Ф11 — после Ф8 (`InfoRow` в `info_section`); Ф12 — после Ф6 (`featured_poster` открыт там) и до Ф9/Ф10, если владелец меняет характер показаний; Ф16 — после Ф11 (карточка геймпада на `select`), Ф17 — после Ф13 и Ф16; Ф13–Ф15 — по одному. Два PR не открывают одни файлы. Номера решений 0010–0014 следуют порядку Ф1 → Ф3 → Ф4 → Ф16 → Ф17. Видимый рубеж «уже похоже на дизайн» — конец Ф5.

## Риски и как их снимать

| Риск | Где | Как снять |
|---|---|---|
| Незакоммиченный B6 — конфликт в файлах эффектов | Ф0 | Коммит первым шагом |
| Палитра не пройдёт `theme_test`; `selection` = hot1 сливается с `portalRim` | Ф1 | Расчёт `look.md`, спорное — сдвигать цвет, не порог; умолчание hot2 |
| Шейдер в тестах на CI 3.47.4 / Skia под xvfb | Ф3 | Тест с настоящей программой — первым коммитом; красный — `useProgram` остаётся, `thinFiles` не трогается, плюм получает ту же подмену |
| Экран под полосами ломает высоты `section_layout_test` | Ф4 | Разделы между полосами (0012); 58+32 против 64+48+40 — места над сеткой больше; узкая панель — переносом, «первый ряд виден» проверяется при 900×620 и 1280×900 |
| Крошка против `find.text(name)`; тесты обоймы и храповики по путям при B12 | Ф4 | Имя раздела отдельным `Text`; тесты переписываются с сохранением инвариантов (выход с геймпада, четыре раздела диктору, навигация в 900×578); переименования одним коммитом с правкой записей и `CLAUDE.md` |
| Стекло трёх полос + искры + капли на Linux в CI | Ф5 | `glass` — флаг; `--smoke`; провал — `glass` вне `shipped` |
| `Shelf.recent` против «без остатка»; `library_body: 28` растёт от `onScan`; тело героя не вмещается в 238 | Ф6 | `recent` — выборка, тест правится тем же коммитом; ветка пустой полки в приватный виджет; описание 2 строки, точка сохранения — на страницу |
| Ореол и тень 54/26 налезают на кайму соседей | Ф7 | Размытие ≤ `tileGlowBlur`, просветы 28/32; `over == 0` |
| Таймер идущей игры перестраивает страницу; контраст полосы днём | Ф8 | Перестраивается только `_RunningTimer`; `GlassSurface` с `fillOpacity` Картриджа, `action_bar_test` |
| Перенос альф при выносе художника графика | Ф9 | Ступени `EvaporateAlpha` тем же коммитом |
| `thinFiles` — файлы разделов на 0 % | Ф8–Ф11 | «Переписал — дал тест»; решает слитый отчёт |
| Колонка настроек ломает `_ListTraversal` | Ф11 | Своя `FocusTraversalGroup`; `settings_navigation_test` |
| Инварианты «ровно один» `DecorativeMotion` | Ф3, Ф15, Ф16 | `PointerTrail`, плюм — на миксине; клавиша — `AnimationController`; явные тесты |
| Удержание на геймпаде — X дискретный | Ф16 | `ButtonPhase` в службе; фаза не сдаётся без геймпадной части |
| Ритуал перекрывает ошибку запуска | Ф17 | Прерывание по `Notice.isError` — обязательный тест; фейк лаунчера |
| Бюджет кадра на слабой машине | Ф13–Ф18 | Плюм и ритуал выключены, стекло только на полосах, свет кромки не берётся; `eco` половинит |
| Golden искр; ключи файлов на диске | все | Не меняются `PortalOutline.corner`, `halo`, цвета, порядок слоёв, 2:3; только новые плоские ключи с умолчанием, `model_roundtrip_test` |
| Тесты дизайна (152 `testWidgets` без харнеса) не переносятся | все | Каждая фаза пишет свои под `TestHarness`/`hostWidget` |

## Чего в плане нет намеренно

- **Nebula/Cryo** — температура акцента, не схема; ink3 не проходит 4.5.
- **Переключаемый потолок радиуса** — радиусы «одни на обе схемы».
- **`google_fonts`** — сеть на первом кадре против TTF в ассетах.
- **`flutter_svg`** — зависимость с регистраторами плагинов ради окраски мимо `IconTheme`.
- **Стеклянный материал капли (`EvGlassStyle.droplet`, blur 0, tint 22 %)** — под каплей `LiquidSelectionInk` перекрашивает подписи в `onSelection` (тёмный), а `theme_test` требует > 7 на `selection`; на прозрачной капле тёмная подпись нечитаема, а светлая теряет смысл капли.
- **Янтарная черта 3×22 у края окна** — второй маркер выбранного раздела при живой капле; лежит за полем рейла, в зоне `WindowChrome.edge`.
- **Ступенчатое поле `gutterFor` 16…44** — `contentMaxWidth` 1340 центрует широкие окна, поле 28 постоянное нарочно.
- **«Повторный выбор раздела — к началу»** — новое событие и `PrimaryScrollController` в четырёх страницах при своём `controller.scroll` у сетки; после issue.
- **Ctrl+O/Ctrl+V из пустой полки** — Ctrl+V принадлежит полю ввода; вход есть клавишей «Указать источник».
- **Палитра команд, клавиши 1–4, Стена, Терминал, Пульт** — новое поведение и экраны; сначала issue.
- **Лист игры модалкой** — ломает возврат фокуса и `openedGameId`.
- **Горизонтальные полки** — несколько прокруток, другой `targetKey`.
- **Наведение только поднимает карточку** — кадр и X идут за игрой под курсором.
- **Правило рамки «только с клавиатуры»** — на десктопе пустое.
- **`EvInstallBox` в герое** — полоса загрузки уже у плитки и на странице.
- **Друзья, профиль друга, оверлей** — ни одного настоящего числа; от оверлея взят только таймер идущей игры (Ф8).
- **Звук (`flutter_soloud`)** — нативная сборка на трёх CI.
- **Линза стекла** — только Impeller, гаснет под любым `Opacity < 255`.
- **30 к/с в неактивном окне** — противоречит `window_visibility.dart`.
- **Свет кромки от курсора, hover-свечение и нажатие ×1.035 стекла, `EvScrollEdge` (восемь `BackdropFilter`), `EvPanel.glowCorner`** — перерисовка стёкол на каждом шаге курсора и лишние слои размытия.
- **`EvBigNumber` с плавным кеглем** — `fontSize` по месту; показания — ролью `readoutLarge`.
- **Тепловая карта пиров, кольцо долей, «пик за час»** — выдуманное рядом с настоящим.
- **Облако с квотой, конфликт двух версий** — состояния нет; конфликт — самое опасное место, отдельное решение.
- **Разделы настроек дизайна «Звук», «Раздача» (`stopSeeding`, «друзьям без лимита»), «Клавиши», расписание скорости 24 ч, папки-диски с занятостью, порт/шифрование, плотность/геометрия, «Разработка», `EvSkinCards`** — движок расписание не соблюдает намеренно, свободного места сервис не считает, порт и шифрование в `DownloadEngine` не видны, таблицы клавиш нет, «Разработка» — витрина.
- **Поиск по настройкам** — каталог данными и перестройка 12 карточек.
- **Скелет 300 мс и полоса сценария** — `library.json` читается мгновенно.
- **Дайджест «пока вас не было»** — нет журнала событий на диске.
- **Дым, подповерхностное рассеивание, марево кадра** — третий фоновый слой; у `FeaturedArt` нет растра.
- **Sheen карточки, дыхание и блик клавиши** — второй блик поверх `FoilSurface`; второй `DecorativeMotion` на странице игры.
- **Зерно на всё окно** — `ImageShader` поверх стекла и страницы игры.
- **Снимки экрана как стражи** — §5 `TODO.md`; эталон — только искры.

## Вопросы владельцу

Только те, что меняют работу; с рекомендацией по умолчанию.

1. **`selection` ночной схемы — hot2 или hot1?** Рекомендация: hot2 — не сливается с `portalRim`. Ф1.
2. **Радиус выреза обложки — 8 (угол = кромка искр) или 5?** Рекомендация: 8. Golden не задет в любом случае. Ф2.
3. **Рейл без подписей (крошка в полосе) или с подписями?** Рекомендация: без, как в дизайне. Ф4 и три теста.
4. **`holdToPlay` по умолчанию — выключено (рекомендация) или включено?** Включённое меняет главное действие у всех, включая X. Ф16, 0013.
5. **`selectionFrame` и `liquidSelection` — в `shipped`?** Рекомендация: `liquidSelection` — да после Ф4 (капля в рейле — главный указатель раздела); `selectionFrame` — нет (`autofocus: selected` при перестройке сетки спорит с рисунком). Ф18.
6. **Новые украшения в `shipped` (`embers`, `grain`, `glass`, `heroParallax`) загорятся у существующих профилей молча — приемлемо?** Рекомендация: да — это и значит «обычно», а дорогое (плюм, ритуал) выключено; «нет» означает умолчание вне `shipped` или признак версии профиля в `settings.json` (новый ключ). Ф18.
7. **Крупные показания — Unbounded w300 или моно w700?** Рекомендация: моно оставить, `readoutLarge` — Unbounded w300. Ф12.
8. **Роль `label` — оставить моно 9 w700 или взять JetBrains Mono 10.5 w500 ls 2.1; заводить ли `sectionLabel` (Unbounded 13 w600) для `SectionHeading`?** Рекомендация: оставить `label` (от него `statusLabel` и `badge` — уехали бы показания и значки очереди), `sectionLabel` не заводить (B10 требует меньше ролей). Ф12.
9. **Кегль строки 13 → 14?** Рекомендация: только если `section_layout_test` проходит после замера. Ф12.
10. **Наклон плитки до 11°?** Рекомендация: оставить — два числа в `foil_motion.dart` в любой момент.
11. **Клавиши 1–4 для разделов?** Рекомендация: нет без issue; если да — пункт с тестом в `input_navigation_test` («в поле поиска — нет»).
12. **Обходить папку синхронизации при открытии раздела «Сохранения»?** Рекомендация: нет — обход диска по смене раздела; если да — событие `SavesBloc` при первом показе раздела (`watchWhileShown`) и тест блока, Ф10 + 1 файл блока.
13. **Клавиша «Проверить целостность» у установленной игры?** Движок умеет (`DownloadEngine.verify`, зовётся при завершении, `downloads_bloc.dart:547`), события для человека нет. Рекомендация: нет в этом плане; если да — `DownloadVerifyRequested(game)`, `busy`, `Notice`, клавиша в `ActionBar` (Ф8) и тест с `FakeDownloadEngine`.
14. **Менять ли знак приложения на «Отдушину» дизайна?** Это и иконка в системе, трее и установщике. Рекомендация: нет в этой серии; если да — третья часть Ф19.
15. **Нужна ли Ф19 (шрифт значков, Onest)?** Рекомендация: нет, пока Material `*_outlined` не мешает.

## Ссылки

Исследование: `redesign-research/maps/look.md`, `structure.md`, `effects.md`; конспекты `redesign-research/readers/*.md`; проба `redesign-research/probe/shader_probe_test.md`. Стражи, задеваемые чаще всего: `test/guards/theme_structure_test.dart`, `test/guards/widget_structure_test.dart`, `tool/check_coverage.dart`, `test/ui/shell/section_layout_test.dart`, `test/tool/docs_names_test.dart`, `test/ui/theme/theme_test.dart`, `test/ui/settings/effect_settings_test.dart`, `test/models/effect_preset_test.dart`.

| Фаза | Что читать |
|---|---|
| Ф0 | `readers/ev-effects.md` (B6), `TODO.md` B6 |
| Ф1 | `maps/look.md` (палитра, WCAG), `readers/ev-theme.md`, `evaporate_design/lib/design/tokens.dart` |
| Ф2 | `maps/look.md` (радиусы, тени, стекло), `evaporate_design/lib/design/theme.dart`, `lib/glass/glass_style.dart`, `lib/widgets/ev_play_button.dart:222-332` |
| Ф3 | `maps/effects.md` (курсор, качество, шейдеры в тестах), `evaporate_design/lib/atmosphere/ev_pointer.dart`, `lib/design/effects.dart`, `test/atmosphere_test.dart`; `TODO.md` B7, B8 |
| Ф4 | `maps/structure.md` (каркас, конфликты), `readers/ev-shell.md`, `readers/ed-shell-glass.md`, `evaporate_design/lib/shell/*` (`ev_shell.dart:262-300, 416-448`); `TODO.md` B9, B12 |
| Ф5 | `maps/effects.md` (стекло, бюджет), `evaporate_design/lib/glass/ev_glass.dart`, `glass_surface.dart:30-50` |
| Ф6 | `maps/structure.md` (герой, полки), `readers/ev-library.md`, `readers/ed-library.md`, `evaporate_design/lib/library/ev_hero.dart`, `hero_state.dart`, `hero_cta.dart`, `lib/returning/ev_return_widgets.dart:18-81`, `lib/first_run/ev_first_run_widgets.dart` |
| Ф7 | `maps/effects.md` (ореол, рамка), `evaporate_design/lib/widgets/ev_game_card.dart`, `ev_surfaces.dart:357-444` |
| Ф8 | `maps/structure.md` (лист игры), `readers/ed-extras.md` (оверлей → таймер), `evaporate_design/lib/sheet/*`, `lib/library/hero_cta.dart:130`; `TODO.md` B13 |
| Ф9 | `readers/ev-sections.md`, `readers/ed-sections.md`, `evaporate_design/lib/downloads/*`, `lib/widgets/ev_surfaces.dart:448, 599-633`, `lib/screens/downloads_page.dart` |
| Ф10 | те же, `evaporate_design/lib/saves/ev_timeline.dart`, `lib/widgets/ev_thread.dart`, `lib/screens/saves_page.dart` |
| Ф11 | те же, `evaporate_design/lib/screens/settings_page.dart`, `lib/settings/ev_settings_widgets.dart:484, 591`; `TODO.md` B14, B15 |
| Ф12 | `maps/look.md` (типографика, моушн), `evaporate_design/lib/design/typography.dart`; `TODO.md` B10, B11 |
| Ф13 | `maps/effects.md` (угли, зерно), `evaporate_design/lib/atmosphere/ember_field.dart`, `ember_paint.dart`, `film_grain.dart` |
| Ф14 | `maps/effects.md` (параллакс), `evaporate_design/lib/library/ev_hero.dart:116-120, 360-383` |
| Ф15 | `maps/effects.md` (плюм), `evaporate_design/lib/atmosphere/ev_atmosphere.dart`, `shaders/plume.frag` |
| Ф16 | `maps/effects.md`, `maps/structure.md` (удержание), `evaporate_design/lib/widgets/ev_play_button.dart:60-130, 365-422` |
| Ф17 | `maps/effects.md` (ритуал), `evaporate_design/lib/launch/*` |
| Ф18 | `maps/effects.md` (бюджет, `shipped`), `readers/ed-extras.md`, `readers/ev-tests-plan.md` |
| Ф19 | `maps/look.md` (иконки, Onest, знак), `evaporate_design/design/build_assets.py`, `design/README.md:2092-2109` |

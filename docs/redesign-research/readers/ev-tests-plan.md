# Конспект читателя: ev-tests-plan

## Сводка

Тестовая обвязка evaporate — интеграционная, без bloc_test/mocktail: одиночный виджет собирает `hostWidget(child, {theme, locale})` (MaterialApp с EvaporateTheme.dark(), переводами L и Scaffold; параметров ровно два, флаги запрещены комментарием), целое приложение — `TestHarness(tmp)` из test/support/test_app.dart (все семь блоков на JsonStore-заглушке в памяти, поток геймпада подменён, `buildApp(theme, locale, builder, motion:false)` заворачивает AppShell в MediaQuery(disableAnimations: !motion) и InterfaceScale; `pump()` ставит окно 1600×1100 и ждёт 500 мс отложенной записи). Ловушки: харнес создаётся внутри testWidgets (Bloc запоминает зону), temp-папка снаружи, `saveRoots: () => const []` обязателен (страж test_hygiene_test), файловый I/O и ожидание условий — через `tester.runAsync` (`pumpUntil`), «ничего не произошло» — барьером `HandlerTracker.settle()`, состояние блока — `waitForState` (проверяет текущее первым). Снимков экрана как стражей нет намеренно (TODO.md §5): единственный эталон — test/goldens/portal_sparks_reference.png, сравниваемый по светящимся пикселям с допуском; остальные «снимки» пишут PNG только по переменным окружения (PORTAL_PREVIEW, LIQUID_PREVIEW*, GAME_PAGE_PREVIEW, WINDOW_FRAME_PREVIEW) и глазами. Ворота `dart tool/gate.dart` — шесть шагов CI (формат, analyze, bloc lint, git diff регистраторов, тесты с покрытием в случайном порядке, порог покрытия); пороги: 82 % весь код, 82 % core+models+services, 90 % save_manager+restore_transaction, файл ниже 50 % — храповик thinFiles, файл без единой строки в отчёте — обязан быть в _reportedNowhere; сложность ≤15, длина ≤60, вложенность ≤3 (списки пусты); замыкание в build ≤25 строк (храповик _longClosures, 15 записей), виджет ≤7 параметров, приватный виджет ≤40 строк, в lib/ui/widgets только нужное двум местам. Действующий план — TODO.md третьего разбора: Этап B (интерфейс) выполнен B1–B6, открыты B7–B15; Порядок и §5 «Чего в плане нет» фиксируют, что нельзя предлагать (понижать пороги, новые меры на ворота, freezed, Cubit для форм, уход с part, переписывание темы, integration_test и снимки экрана как стражи). Облик хранится в `Appearance` (themeMode, locale, interfaceScale, libraryScale, libraryEffects, Set<LibraryEffect>) с плоской записью на диске и клампингом при чтении — новые поля облика ложатся туда, украшения — в enum LibraryEffect, значения по умолчанию сторожит effect_settings_test.

## Файлы

- `test/support/host_widget.dart` — один виджет в окружении приложения: тема, переводы, Scaffold; ровно два параметра
- `test/support/test_app.dart` — TestHarness: всё приложение с блоками на памяти, подменённым геймпадом и флагом motion
- `test/support/bloc_idle.dart` — HandlerTracker/installHandlerTracker — барьер «обработчики всех блоков закончили»
- `test/support/pump_until.dart` — waitUntil/pumpUntil — ожидание условия в настоящем времени внутри runAsync
- `test/support/library_seed.dart` — seedGame — положить игру в library.json и перечитать, минус событий-снимков
- `test/support/wait_for_state.dart` — waitForState — ждать состояние блока, проверяя текущее первым
- `test/support/guards.dart` — expectRatchet — двусторонний храповик (новое роняет, исправленное обязано уйти)
- `tool/check_coverage.dart` — пороги покрытия, _reportedNowhere, thinFiles, флаг --all-systems
- `tool/check_complexity.dart` — замер сложности/длины/вложенности и buildClosures на дереве analyzer
- `tool/gate.dart` — шесть шагов ворот в порядке CI и список чисто CI-шагов
- `test/guards/complexity_test.dart` — пороги 15/60/3, пустые списки нарушителей, тест «замер ослеп»
- `test/guards/widget_structure_test.dart` — храповики privateWidgets, widgetFunctions, crowdedFiles, _longClosures, _wideWidgets, lonelyShared
- `test/guards/theme_structure_test.dart` — страж темы: регулярки и храповики fontSize/durations/curves/alphas/textStyles/iconSizes
- `test/guards/test_hygiene_test.dart` — SavesBloc в тестах обязан получать saveRoots
- `test/goldens/portal_sparks_reference.png` — единственный эталонный снимок — искры портала
- `test/ui/library/portal_sparks_test.dart` — сравнение искр с эталоном по светящимся пикселям, превью по PORTAL_PREVIEW
- `test/ui/library/library_effects_test.dart` — фольга, наклон, атмосфера, частицы, «живая библиотека» с motion:true
- `test/ui/widgets/liquid_selection_test.dart` — капля выбора: переезд, обойма/фильтры/сетка в обеих схемах, превью LIQUID_PREVIEW*
- `test/ui/library/cover_drops_test.dart` — капли: выключенный эффект, без обложки, несобравшийся шейдер, пропавшая обложка
- `test/ui/settings/effect_settings_test.dart` — страж значений украшений по умолчанию и виджет-тесты переключателей effects-<name>-toggle
- `test/ui/shell/section_layout_test.dart` — первый ряд обложек в 1280×900, метка раздела вместо трёх имён, нижняя строка — показания
- `test/ui/theme/theme_test.dart` — контраст WCAG каждого цвета на каждой подложке в обеих схемах
- `test/tool/docs_names_test.dart` — каждый путь и CamelCase-имя в обратных кавычках документов существует
- `test/tool/font_licenses_test.dart` — каждый раздаваемый шрифт лежит с текстом лицензии
- `TODO.md` — действующий план третьего разбора: Этап B (419–756), Порядок (1369), Чего нет намеренно (1399)
- `docs/decisions/README.md` — оглавление решений 0001–0009 с отказами
- `docs/reviews/2026-09-19.md` — оценка первого разбора (план закрыт, текст в git show f64b706:TODO.md)
- `docs/reviews/2026-09-21.md` — оценка второго разбора: надёжность, девять P0 (план в git show 055a9aa:TODO.md)
- `CONTRIBUTING.md` — ворота, выпуск версии, ручной чек-лист, правила кода (рус./англ.)
- `CHANGELOG.md` — верх — 0.40.1 от 2026-09-23; раздела «Не выпущено» сейчас нет
- `analysis_options.yaml` — strict-casts/inference/raw-types, линты, пять правил bloc_lint
- `lib/models/appearance.dart` — Appearance: themeMode, locale, interfaceScale, libraryScale, libraryEffects, Set<LibraryEffect>
- `lib/models/library_effect.dart` — enum четырнадцати украшений с jsonKey, independent и набором shipped
- `lib/models/effect_preset.dart` — наборы off/calm/standard/full поверх Appearance
- `lib/models/app_theme_mode.dart` — enum system/light/dark — своя перечислимая, без Flutter
- `lib/ui/theme/theme_mode.dart` — AppThemeMode → ThemeMode для MaterialApp (в thinFiles с 0 %)
- `lib/ui/settings/theme_picker.dart` — SegmentedSetting на три сегмента: система/светлая/тёмная
- `lib/ui/settings/cards/appearance_card.dart` — карточка облика: тема, язык, масштаб интерфейса
- `evaporate_design/todo.md` — план переноса прототипа в evaporate_design — закрыт целиком
- `evaporate_design/lib/design/appearance.dart` — EvAppearance (ChangeNotifier): skin и geometry — аналог Appearance у прототипа
- `evaporate_design/lib/design/effects.dart` — EvEffects/EvEffectsQuality: eco/full/max, десять флагов, EvEffects.still() для тестов

## facts

- hostWidget принимает ровно два параметра — theme и locale — и по комментарию расти не должен: свой MediaQuery или builder рамки пишут на месте (test/support/host_widget.dart:11-15).
- TestHarness создаётся синхронно и обязан вызываться внутри testWidgets, temp-папка — снаружи через TestHarness.makeTempDir (test/support/test_app.dart:53-58, 152-161).
- buildApp заворачивает AppShell в MediaQuery(disableAnimations: !motion) и InterfaceScale; motion:false по умолчанию, тесты украшений включают его явно (test/support/test_app.dart:238-246).
- TestHarness.pump ставит окно 1600×1100 при dpr 1 и после pumpAndSettle ждёт 500 мс отложенной записи библиотеки (test/support/test_app.dart:264-270).
- Блоки в харнесе пишут в _WidgetLibraryStore (JsonStore в памяти), saveRoots: () => const [], pathExists синхронный — иначе файловый I/O внутри testWidgets не завершается (test/support/test_app.dart:37-48, 113-120).
- UpdateBloc в харнесе получает fetch: (uri) async => '{}' и DesktopEntry с пустым окружением — без сети и без записи меню (test/support/test_app.dart:132-138).
- HandlerTracker считает события каждого блока в onEvent/onDone, settle() требует двух спокойных оборотов подряд, таймаут 10 с (test/support/bloc_idle.dart:16-56).
- pumpUntil ждёт условие в runAsync (настоящее время), затем pumpAndSettle снаружи (test/support/pump_until.dart:34-41).
- waitForState проверяет текущее состояние первым — иначе ожидание уже случившегося висело до таймаута (test/support/wait_for_state.dart:14-21).
- seedGame дописывает игру в library.json и шлёт LibraryLoadRequested, потому что событий «вот вся игра» у библиотеки нет намеренно (test/support/library_seed.dart:8-31).
- Страж test_hygiene_test валит любой SavesBloc( без saveRoots внутри его скобок (test/guards/test_hygiene_test.dart:10-27, 58-73).
- Пороги покрытия: 82 % весь код без генерации, 82 % lib/core+lib/models+lib/services, 90 % save_manager.dart+restore_transaction.dart (tool/check_coverage.dart:248-267).
- _reportedNowhere (11 файлов): lib/main.dart, lib/app_services.dart, services/notifications/system_notification_service.dart, services/system/native_tray_host.dart, lib/ui/theme.dart, models/app_theme_mode.dart, ui/theme/alpha.dart, ui/theme/icon_size.dart, ui/theme/spacing.dart, bloc/frequent_event.dart, ui/library/featured/shots_timing.dart (tool/check_coverage.dart:91-103).
- thinFiles (30 записей, порог 50 %), из lib/ui: engine_failure 0, executable_picker_dialog 0, running_game_actions 0, find_paths_progress 0, bulk_outcome_group 0, bulk_report_view 0, pick_game_dialog 0, sync_folder_contents 0, sync_package_row 0, settings/pick_folder 0, theme/theme_mode 0, drop_overlay 2, busy_spinner 17, snapshots_section 22, notification_actions 31, effects/cover_drops 44; остальное — файлы событий блоков (21–34), managed_window 35, engine_queue 41 (tool/check_coverage.dart:152-183).
- Храповик thinFiles валит прогон только с --all-systems (три отчёта); локально список лишь показывается (tool/check_coverage.dart:287-302).
- Файл без единой выполненной строки в отчёт не попадает и обязан быть назван в _reportedNowhere — иначе провал (tool/check_coverage.dart:73-79, 305-316).
- Ворота: шесть шагов — dart format, flutter analyze, bloc lint lib, git diff --exit-code linux windows macos, flutter test --coverage --test-randomize-ordering-seed random, check_coverage; идут все, итог кодом возврата (tool/gate.dart:28-57, 133-145).
- Пороги сложности: maxComplexity 15, maxLines 60, maxNesting 3; списки нарушителей пусты; тест «замер ослеп» требует >1000 функций (test/guards/complexity_test.dart:19-21, 72-78).
- Страж виджетов: maxClosureLines 25, maxPrivateWidgetLines 40, виджет с 8+ параметрами — нарушение; _privateWidgets, _widgetFunctions, _crowdedFiles, _lonelyShared, _wideWidgets пусты (test/guards/widget_structure_test.dart:11, 353-386; test/support/widget_structure.dart:88).
- _longClosures — 15 записей с числом, среди них украшения: game_wave 43, library_atmosphere 40, portal_sparks 30, shots_slideshow 40, featured_game 30, library_grid 30, navigation_rack 49 (test/guards/widget_structure_test.dart:365-383).
- Страж темы держит счётчики по файлам: _fontSize и _textStyles — 4 файла типографики картинки (cover_title_plate, detail_cover, featured_title, top_bar_brand), _durations — frame_step, liquid_selection (460 мс), rise_in; _curves — foil_motion, hero_sweep, shots_slideshow, liquid_selection_path 3, rise_in; _alphas — 8 файлов, в том числе foil_surface 2, library_atmosphere 2, portal_atlas 1 (test/guards/theme_structure_test.dart:377-444).
- Единственный эталон — test/goldens/portal_sparks_reference.png; тест сравнивает только пиксели ярче 70 по трём каналам с допуском на сглаживание, превью пишется по PORTAL_PREVIEW (test/ui/library/portal_sparks_test.dart:392-425).
- Тесты, снимающие отрисовку через toImage: cover_backdrop, game_page_effects, library_effects, portal_sparks, download_chart, animated_progress, liquid_selection, window_frame; шрифты грузят руками через FontLoader в пяти файлах (grep test/).
- Переменные превью разбросаны: LIQUID_PREVIEW, LIQUID_PREVIEW_DARK, LIQUID_PREVIEW_PREFIX, PORTAL_PREVIEW, WINDOW_FRAME_PREVIEW, GAME_PAGE_PREVIEW, GAME_PAGE_LIGHT — пункт F5 плана сводит их к EVAPORATE_PREVIEW_DIR и savePreview() (TODO.md:1298-1310).
- Тесты сохраняемых украшений: фольга «наклоняется жёстко, не теряет картинку и успокаивается по уходе выбора»; капля «переезд не теряет содержимое, меняет цель, успокаивается и слушает запреты движения» и «живёт в обойме, фильтрах и сетке (днём/ночью)»; капли «несобравшийся шейдер оставляет обложку на месте»; искры — 5 групп, включая «искры горят вокруг обложки, а не поверх неё» (library_effects_test.dart:26-28; liquid_selection_test.dart:53-55,176-177; cover_drops_test.dart:82; portal_sparks_test.dart:352).
- «Живая библиотека» строится TestHarness с 12 играми, окном 1280×900, EvaporateTheme.light(), motion:true и 40 кадрами по 17 мс (test/ui/library/library_effects_test.dart:388-432).
- CoverDrops держит один FragmentProgram на приложение и подменяется в тестах useProgram(): шейдер компилируется только при сборке приложения (lib/ui/library/effects/cover_drops.dart:37-47).
- Точки монтирования украшений: FoilCard — library_grid_tile.dart:128, PortalSparks — cover/cover_frame.dart:35, CoverDrops — cover/cover_face.dart:62, LiquidSelection — library_grid.dart:46, navigation_rack.dart:60, shelf_tabs.dart:42, LiquidSelectionInk — navigation_key.dart:57, shelf_button.dart:40, LibraryAtmosphere — library_body.dart:67, GameWave — shell_panel.dart:40, HeroSweep+ShotsBackdrop — featured_art.dart:37-45, CoverBackdrop — game_page.dart:28.
- Незакоммиченный diff в рабочем дереве — B6: новый lib/ui/widgets/decoration_clock.dart, правки foil_card, library_atmosphere, decorative_motion, liquid_selection, window_visibility, CLAUDE.md и TODO.md (B6 отмечен [x]); в git log B6 ещё нет (git status; git diff --stat).
- Этап B по git log и TODO.md: сделано B1 (606e6ee, решение 0009), B2 (7027a7a), B3 (5fecca4, страж lonelyShared), B4 (ead457a), B5 (f11dc38), B6 (в рабочем дереве); не сделано B7 (тестовые крючки в боевом коде: targetRect/targetIdentity, isAnimating, perspective, positionOf/tailOf), B8 (мёртвые параметры: LiquidSelection.resting, EvaporateMotion.exit, _railTheme), B9 (числа мимо стража: spacing:, высота органа 48/42, кортежи ступеней), B10 (30 ролей текста → меньше, без полукеглей), B11 (context.surface/glass/effects; EvaporateMotion — не ThemeExtension), B12 (словарь имён: плитка/полка/сетка/обойма/рейка/плашка, файл = класс, убрать Concept), B13 (LibraryPage: побочные действия build → BlocListener), B14 (select вместо watch в карточках настроек), B15 (SettingRow, context.patchSettings, мелочи) (TODO.md:424-754).
- Пересечения Этапа B с редизайном: B7–B9 трогают ровно файлы сохраняемых украшений (library_atmosphere, foil_card, liquid_selection, portal_*), B10–B11 — типографику и доступ к теме, B12 — имена NavigationRack/ConceptTopBar/ConceptNavigation/шести файлов, B13 — LibraryPage, B14–B15 — карточки настроек, куда лягут новые поля облика (TODO.md:636-754).
- Порядок плана: B1 до любой правки интерфейса (сделано); F11 (храповики с числом → к нулю) вслед за B1 и B4; E3–E5 (документы) одним проходом после этапов B–C, E7 последним (TODO.md:1374-1391).
- Темп плана: после каждого шага — ворота целиком и ручная проверка сценария; где поведение меняется — тест, который без правки падает (TODO.md:1393-1397).
- §5 «Чего в плане нет намеренно»: понижение порогов, новая мера на ворота («файлов на экран»), freezed, возврат Cubit для форм, уход с part, перевод комментариев на английский, переписывание темы (ярусы и расширения остаются по 0002), integration_test и снимки экрана как стражи (TODO.md:1399-1419).
- Решения: 0001 — новое состояние Bloc, Cubit исключение, NavigationBloc остаётся блоком; 0002 — тема в три яруса, компонент — ThemeExtension с двумя экземплярами, не наследник; 0003 — репозитория игр нет; 0004 — ни ButtonCaptureBloc, ни WindowBloc (служба WindowModeWatch); 0005 — без bloc_test/mocktail, freezed/json_serializable и DCM; 0006 — замер сложности на дереве analyzer; 0007 — подпись обновлений (отменена); 0008 — подписи обновлений нет; 0009 — приватный виджет ≤40 строк без State с ресурсами остаётся у потребителя (docs/decisions/README.md:12-22).
- Записи решений не переписывают задним числом — передумали значит новая запись со ссылкой (docs/decisions/README.md:9-10).
- docs/reviews: 2026-09-19.md — первый разбор («как написано», план в f64b706), 2026-09-21.md — второй (надёжность данных, девять P0, план в 055a9aa); третий разбор от 2026-09-23 живёт в TODO.md (TODO.md:1-8).
- CHANGELOG: верхний раздел [0.40.1] — 2026-09-23; changelog_notes_test сторожит верхний раздел, внутреннее (стражи, прогоны) в историю не пишут, «Безопасность» идёт первой (CHANGELOG.md:6; CONTRIBUTING.md:51-59).
- CONTRIBUTING ещё говорит «ни приватных виджетов» — расходится с 0009 (CONTRIBUTING.md:132-133, 288-289; пункт E5 плана).
- analysis_options: strict-casts/strict-inference/strict-raw-types; линты unawaited_futures, cancel_subscriptions, close_sinks, avoid_dynamic_calls, prefer_const_constructors, directives_ordering, avoid_catches_without_on_clauses, avoid_void_async, only_throw_errors, prefer_single_quotes, avoid_positional_boolean_parameters; bloc-правила avoid_flutter_imports, avoid_public_bloc_methods, prefer_bloc, prefer_file_naming_conventions, prefer_void_public_cubit_methods (analysis_options.yaml:16-19, 26-77, 105-111).
- Appearance: themeMode (AppThemeMode system/light/dark), locale (String?, только ru/en), interfaceScale 0.85–1.25, libraryScale 0.75–1.5, libraryEffects (общий выключатель), effects Set<LibraryEffect>; при чтении масштабы зажимаются, незнакомая тема/язык → умолчание; запись плоская, ключ на украшение (lib/models/appearance.dart:16-51, 89-119, 154-162).
- LibraryEffect — 14 значений в порядке переключателей «Подробно»: particles, waves, foil, cardTilt, liquidDistortion, liquidSelection, ambient, heroSweep, shotsBackdrop, coverBackdrop, drops, portal, selectionFrame (independent), interfaceAnimations; shipped = waves, foil, cardTilt, ambient, heroSweep, shotsBackdrop, coverBackdrop, portal, interfaceAnimations (lib/models/library_effect.dart:12-99).
- EffectPreset off/calm/standard/full раскладывается в те же украшения, calm = interfaceAnimations+coverBackdrop; effectPreset определяется сравнением applyTo(this)==this, а не таблицей (lib/models/effect_preset.dart:21-79).
- ThemePicker — SegmentedSetting из трёх сегментов system/light/dark с иконками Material; AppThemeMode переводится в ThemeMode расширением в lib/ui/theme/theme_mode.dart (единственное место — сборка MaterialApp) (theme_picker.dart:21-42; theme_mode.dart:10-16).
- AppSettings — девять полей, три из них значения (appearance, startup, saves); правка через withAppearance((a) => a.copyWith(…)), ключи на диске прежние; держит model_roundtrip_test (lib/models/app_settings.dart:14-39).
- effect_settings_test поимённо сторожит умолчания каждого украшения для свежих и вычитанных настроек и требует, чтобы toJson/fromJson были обратимы (test/ui/settings/effect_settings_test.dart:18-91).
- Проверяемые тестами раскладки, которые редизайн заденет: «первый ряд обложек виден целиком в окне 1280×900», «раздел подписан меткой, а не своим именем трижды», «нижняя строка занята показаниями, а не мебелью сайта» (section_layout_test.dart:38-79); «витрина не исчезает в невысоком окне, а становится полосой» (library_grid_test.dart:205); «узкое окно уплотняет аппаратную панель без переполнения» (app_shell_test.dart:228); «клавиша темы перебирает все три состояния» (concept_shell_test.dart:20).
- Тесты темы: контраст 4.5/7 на каждой подложке обеих палитр, «акценты у схем разные», «переход между схемами не спотыкается» (theme_test.dart:34-160); theme_fields_test считает поля каждого ThemeExtension по исходнику — забытое в lerp/values поле роняет прогон (theme_fields_test.dart:5-45); fonts_test грузит настоящие шрифты и меряет ширину по весу (fonts_test.dart:35-116).
- docs_names_test сверяет каждый путь и CamelCase-имя в обратных кавычках CLAUDE.md/README/решений с деревом — переименование виджета при редизайне требует правки документов в том же коммите (test/tool/docs_names_test.dart:5-13, 35).
- font_licenses_test требует текст лицензии рядом с каждым раздаваемым шрифтом; evaporate шрифты бандлит (Unbounded, Golos Text, JetBrains Mono в pubspec.yaml:98-106), тогда как evaporate_design берёт google_fonts, flutter_svg и flutter_soloud (evaporate_design/pubspec.yaml:33-36).
- evaporate_design: план переноса прототипа закрыт целиком (todo.md «Осталось»), тесты — 152 testWidgets в 21 файле без харнеса и стражей, analysis_options — голый flutter_lints; облик — EvAppearance(skin: EvSkin.magma, geometry: EvGeometry.tight) ChangeNotifier, эффекты — EvEffects с десятью флагами и EvEffectsQuality eco/full/max, EvEffects.still() для тестов (evaporate_design/lib/design/appearance.dart:9-30; effects.dart:7-60).
- В третьем разборе «трогать не надо»: DecorativeMotion, FrameStep, украшения разложены по «что от чего зависит» (portal/, particle_field), watchWhileShown, GameDropTarget с TickerMode, primary_action.dart, семантика плитки и SectionHeading (TODO.md:132-139).

## constraints

- Ворота целиком (`dart tool/gate.dart`) после каждого шага плана; ни один шаг не сдаёт красными: формат, analyze с подсказками, bloc lint, регистраторы плагинов, тесты в случайном порядке, порог покрытия.
- Пороги покрытия 82/82/90 не опускать; каждый новый файл lib/ui обязан выполняться хоть одним тестом (иначе — поимённо в _reportedNowhere с причиной) и покрываться не ниже 50 % (иначе новая запись в thinFiles запрещена — храповик роняет прогон в CI по слитому отчёту).
- Храповики стражей только убывают: _longClosures (15), счётчики theme_structure_test, thinFiles — новая запись запрещена, исправленное обязано уйти (expectRatchet двусторонний).
- Сложность ≤15, длина ≤60 строк, вложенность ≤3; списки нарушителей пусты и пополняться не могут; замыкание в build ≤25 строк; виджет ≤7 параметров; приватный виджет ≤40 строк без State с ресурсами и только в файле единственного потребителя (0009); lib/ui/widgets — только нужное двум местам.
- Тема — три яруса (0002): никаких isDark, fontSize:, Duration(milliseconds:), Curves.*, BorderRadius.circular(число), чисел раскладки, alpha числом в виджетах; новый компонент — ThemeExtension с двумя экземплярами arclight/cartridge и полным lerp/values (theme_fields_test); контраст WCAG 4.5/7 на каждой подложке (theme_test).
- Все видимые строки — в app_ru.arb и app_en.arb; кириллица в lib/ui запрещена стражем; каждый ключ ARB кем-то читается (arb_usage_test).
- Новые поля облика — в Appearance (плоская запись, прежние ключи, клампинг при чтении, model_roundtrip_test); новые украшения — значением enum LibraryEffect с jsonKey и решением о включении в shipped; умолчания поимённо в effect_settings_test.
- Новое состояние — Bloc с событиями (prefer_bloc на воротах); блоки не импортируют lib/ui; частые события помечать FrequentEvent.
- Украшения слушают одно правило decorationMayRun и общие часы DecorationClock (B6 в рабочем дереве); тест «скрытый раздел, свёрнутое окно, просьба не двигаться и настройка гасят часы» должен остаться зелёным.
- Виджет-тесты: hostWidget без новых флагов; TestHarness внутри testWidgets, temp-папка снаружи, saveRoots обязателен, файловый I/O через runAsync, ожидание барьером/условием, а не паузой (F4).
- Снимки экрана как стражи не заводить (TODO.md §5) — визуальная проверка через превью по переменной окружения; эталон допустим только по образцу portal_sparks_reference (сравнение светящихся пикселей с допуском).
- Переименование класса или файла из lib/ui требует правки CLAUDE.md/README/решений в том же коммите (docs_names_test); документы и комментарии — по-русски.
- План согласуется с TODO.md Этап B: не открывать те же файлы дважды — B7–B9 (украшения), B10–B11 (типографика/доступ к теме), B12 (словарь имён), B13–B15 (LibraryPage, настройки) делаются вместе с редизайном соответствующих мест, а F11 — вслед.
- Крупное — новый экран, зависимость (google_fonts, flutter_svg, flutter_soloud из evaporate_design), новая схема — сначала issue/решение в docs/decisions следующим номером; шрифты только бандлом с лицензией (font_licenses_test).
- CHANGELOG: раздел версии вверху по diff, внутреннее не пишут; выпуск — тег на зелёный main.

## risks

- B6 лежит незакоммиченным в рабочем дереве (decoration_clock.dart новый, foil_card/library_atmosphere/decorative_motion/liquid_selection переписаны): план, начатый поверх, либо конфликтует, либо теряет эту правку — сперва довести B6 до коммита.
- section_layout_test держит «первый ряд обложек целиком в 1280×900» и одну метку раздела вместо трёх имён; любая шапка/герой из evaporate_design выше нынешних ~238 точек уронит тест и вернёт беду, ради которой он написан.
- theme_test меряет контраст каждого цвета на каждой подложке (4.5/7): палитра прототипа «magma» без пересчёта под WCAG не пройдёт, а часть цветов Evaporate уже отклонена от исходных именно этим тестом.
- theme_fields_test и hardware_surface_theme_test считают поля расширений по исходнику: новый ThemeExtension без полного lerp/values или с одним экземпляром на обе схемы (как EvaporateMotion, B11) — красный прогон.
- _longClosures и счётчики стража темы записаны с числом на файл: переписанный build украшения (game_wave 43, library_atmosphere 40, portal_sparks 30) при росте на одну строку роняет прогон и требует правки стража; уменьшение — тоже (запись обязана уйти).
- thinFiles: cover_drops.dart стоит на 44 % — любая правка капель, добавляющая непроверенные ветки, опустит его ниже 44 и уронит CI; исправить можно только тестом, а настоящий шейдер в прогоне не собирается (useProgram).
- Файлы событий блоков тонки «по природе» (props читает только сравнение): новый блок экрана под редизайн (например, режимов просмотра) сразу даст новый тонкий *_event.dart — новая запись в thinFiles запрещена, нужен тест на равенство событий.
- docs_names_test: CLAUDE.md называет NavigationRack, SectionHeading, ReadoutPanel, FeaturedGame, CoverBackdrop, ShotsBackdrop, AmbientLight, LiquidSelection и десятки путей; B12 переименовывает ConceptTopBar/ConceptNavigation/game_cover.dart — каждое переименование без правки документов красное.
- Пользовательские настройки на диске: ключи Appearance и по одному ключу на украшение — новая схема/геометрия обязаны читаться из старого файла с умолчанием и записываться плоско; model_roundtrip_test сторожит отсутствие вложенных объектов.
- Тесты украшений строят виджеты напрямую (FoilCard, PortalSparks, LiquidSelection, CoverDrops с параметрами enabled/active/foilEnabled/tiltEnabled/distortionEnabled): смена сигнатур при переносе в новую плитку ломает ~25 тестов, а B7 планирует убрать те самые крючки (targetRect, perspective, isAnimating), на которые тесты опираются.
- game_page_effects_test и library_effects_test грузят настоящие шрифты и снимают toImage: замена семейств (evaporate_design тянет google_fonts по сети) сломает fonts_test («семейства отличаются», «слушаются веса») и font_licenses_test.
- Порог сложности 15 и длина 60 при пустых списках: 65 build уже в полосе 41–60 (TODO.md:83), перенос плотных экранов прототипа (герой, стекло, режимы) без разбора на приватные виджеты ≤40 строк упрётся в потолок с первого файла.
- Страж layering транзитивен: модель облика не может импортировать ничего из Flutter (AppThemeMode своя ради изолята), значит EvSkin/EvGeometry из evaporate_design нельзя перенести с зависимостью на ThemeData.
- Общий выключатель libraryEffects и наборы EffectPreset: новое украшение, не названное в shipped, «обычно» не покажет, а independent-украшение уйдёт мимо наборов — effect_preset_test и settings_layout_test («украшения выбираются набором, а не тринадцатью галочками») проверяют лестницу calm ⊂ standard ⊂ full.

## openQuestions

- Коммитить ли B6 (DecorationClock) отдельно до начала редизайна, чтобы план не ложился поверх незакоммиченного диффа?
- Новая схема из evaporate_design (skin magma, геометрия tight/…) — третий экземпляр ThemeExtension рядом с arclight/cartridge и третье значение AppThemeMode, или замена одной из двух схем? От этого зависят theme_test (контраст обеих) и ключ themeMode в файле настроек.
- Куда класть «качество эффектов» eco/full/max из EvEffectsQuality: полем Appearance (плоский ключ) или третьим измерением EffectPreset? Наборы сейчас — лестница подмножеств, а качество — множитель.
- Разрешено ли трогать `_longClosures` записями вниз при переписывании build украшений, или редизайн обязан сразу закрыть F11 для затронутых файлов (перенос замыканий в приватные виджеты)?
- Нужен ли эталонный снимок для капли/фольги/капель по образцу portal_sparks_reference, или достаточно превью по переменной окружения (§5 запрещает снимки как стражей, но эталон искр уже есть)?
- Переносить ли из evaporate_design звук (flutter_soloud) и SVG (flutter_svg) — это новые зависимости и по CONTRIBUTING требуют issue до кода; в собранном плане они пока не упомянуты.
- Как считать покрытие новых экранов, у которых нет тестов в evaporate_design формата харнеса: писать под TestHarness (интеграционно) или под hostWidget (по одному виджету)?

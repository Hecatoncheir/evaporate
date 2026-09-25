# Сопоставление, линза: СТРУКТУРА — оболочка, разделы, экраны, виджеты, слои, блоки. Сопоставление каркаса evaporate_design (рейл 76 / топбар 58 / строка подсказок 32, палитра команд, герой + полки, лист игры, приборная доска загрузок, лента сохранений, настройки с колонкой и поиском, режимы Витрина/Стена/Терминал/Пульт) с оболочкой evaporate (ConceptTopBar 64 + NavigationRack 48 + AppFooter 40, FadeIndexedStack с TickerMode, InputScope/NavAction, FeaturedGame + LibraryGrid, GamePage/GameDetail, DownloadsPage с ReadoutPanel и TaskCard, SavesPage сливерами, SettingsPage из 12 карточек). Все факты сверены по коду обоих репозиториев на момент HEAD f11dc38 плюс незакоммиченный B6 (DecorationClock).

## Сопоставления

### Каркас окна: EvShell — Stack, экран под полосами во всю высоту, занятое место через MediaQuery.padding (top 58, bottom 32/60), рейл 76 слева, BackdropGroup на три стекла (ev_shell.dart:262-300); размеры — EvSpace.railWidth/topBarHeight/hintsHeight (tokens.dart:269-275)

- **Аналог в evaporate:** ShellLayout — Column: ConceptTopBar 64 (WindowDragArea подложкой, TopBarBrand | ConceptNavigation по центру | TopBarActions), ShellPanel (полупрозрачная панель с GameWave), _FooterStrip 40 через OverflowBox; поля 6/10, подвал прячется ниже 520 (shell_layout.dart:13-49); высоты — EvaporateLayout.topBarHeight/railHeight/footerHeight
- **Решение:** адаптировать
- **Почему:** Геометрия дизайна (вертикальный рейл слева, полосы поверх экрана) ложится на ту же Column/Stack-раскладку: новые константы EvaporateLayout (railWidth 76, topBarHeight 58, hintsHeight 32) вместо 64/48/40, экран под полосами через MediaQuery.padding как у дизайна. Обязательно сохранить: WindowDragArea в топбаре (окно без системной рамки — window_frame.dart:8-14), инвариант WindowChrome.edge 4 < inset (window_frame_test), FadeIndexedStack внутри панели. BackdropGroup для трёх полос — взять, один снимок фона на все.
- **Файлы дизайна:** evaporate_design/lib/shell/ev_shell.dart, evaporate_design/lib/design/tokens.dart
- **Файлы evaporate:** lib/ui/shell/shell_layout.dart, lib/ui/shell/top_bar.dart, lib/ui/theme/layout.dart, lib/ui/window/window_frame.dart
- **Стражи:** theme_structure (_layoutHere: числа 76/58/32 только полями EvaporateLayout), widget_structure (_longClosures: navigation_rack 49 и top_action 29 — записи уйдут вместе с файлами, новые build ≤25 строк), window_frame_test (drag по (100,32) от 'window-drag-region', edge<compactInset), app_shell_test (обойма при 820×620, подписи при 620), section_layout_test (первый ряд обложек в 1280×900 — новая шапка не выше)

### EvShellController — ChangeNotifier: section, detail, crumb, open()/back(), reselected для прокрутки к началу (ev_shell.dart:18-73); клавиши в своём FocusScope.onKeyEvent

- **Аналог в evaporate:** NavigationBloc — SectionSelected, SectionCycled(delta), GameSelected (FrequentEvent), GameOpened(id|null), SearchFocusRequested; closeOpenedGame() единственный публичный метод (navigation_bloc.dart:25-75); detail = openedGameId, крошка = LibraryBloc.gameById(openedGameId)?.title
- **Решение:** оставить evaporate
- **Почему:** Решение 0001 и bloc_lint prefer_bloc: навигация остаётся блоком (память navigation-stays-bloc). Всё, что умеет контроллер дизайна, у блока уже есть: раздел, вложенная страница (openedGameId), назад (closeOpenedGame). Не хватает только «повторный выбор → к началу» — при надобности новое событие SectionReselected и PrimaryScrollController в страницах, но у LibraryGrid свой controller.scroll (library_grid.dart:54), так что это отдельная правка, не часть каркаса.
- **Файлы дизайна:** evaporate_design/lib/shell/ev_shell.dart
- **Файлы evaporate:** lib/bloc/navigation/navigation_bloc.dart, lib/bloc/navigation/navigation_state.dart
- **Стражи:** bloc_lint prefer_bloc, bloc_members_test (новый публичный метод — только с // ignore и объяснением), FrequentEvent для частых событий

### EvSection — шесть разделов с русскими литералами, hotkey = index+1, primary = первые четыре, «Друзья»/«Профиль» ниже (ev_section.dart:7-24)

- **Аналог в evaporate:** AppSection — четыре раздела, at() и shifted() по кругу (app_section.dart:8-22); порядок = индекс FadeIndexedStack (shell_sections.dart:29-37) и номер метки «[ 0N / … ]»
- **Решение:** оставить evaporate
- **Почему:** Разделы «Друзья» и «Профиль» не имеют ни одного настоящего числа (аккаунтов, presence, узнавания пиров у evaporate нет); README дизайна сам называет сохранёнными именно четыре раздела (README.md:2127). Пятый раздел ломает нумерацию меток и SectionCycled по кругу. Подписи — из ARB через sectionLabel, не литералами enum.
- **Файлы дизайна:** evaporate_design/lib/shell/ev_section.dart
- **Файлы evaporate:** lib/models/app_section.dart, lib/ui/shell/shell_sections.dart
- **Стражи:** section_layout_test (метки [ 01 ]…[ 04 ] по порядку), localization_test (кириллица в enum запрещена в lib/ui; модель без строк показа), layering (модели — чистый Dart)

### Смена раздела: AnimatedSwitcher с ключом (section, detail) — уходящий экран уничтожается; переход 340/440 мс с подъёмом 10 px и ростом с 0.994, обратно 200 линейно; _SectionHost с primary-скроллом (ev_shell.dart:249-260, 416-448)

- **Аналог в evaporate:** FadeIndexedStack — все разделы живы, TickerMode(enabled) ровно текущему, проявление за motion.instant, при disableAnimations value=1 (fade_indexed_stack.dart:5-10, 48-86)
- **Решение:** оставить evaporate
- **Почему:** На TickerMode стека держатся GameDropTarget (молчание невидимого приёмника), WatchWhileShown, decorationMayRun и один DownloadHistoryBloc на приложение; уничтожение экрана вернуло бы потерю прокрутки, ввода и фокуса, ради которых стек и заведён (fade_indexed_stack.dart:6-10). Взять можно только облик перехода — сдвиг на 10 px внутри FadeIndexedStack (SlideTransition рядом с FadeTransition) на ступени context.motion.
- **Файлы дизайна:** evaporate_design/lib/shell/ev_shell.dart
- **Файлы evaporate:** lib/ui/shell/fade_indexed_stack.dart, lib/ui/widgets/game_drop_target.dart, lib/ui/widgets/watch_while_shown.dart
- **Стражи:** theme_structure (_durationHere/_curveHere: 340/440/200 и Curves.linear только токенами), library_effects_test (скрытый раздел гасит часы), hidden_page_test (скрытые загрузки не перестраиваются)

### EvRail — стекло 76 на всю высоту с кромкой справа, знак 36, кнопки 48×44 колонкой, EvDroplet по dropletRect, янтарная черта 3×22 у края окна, боковая подсказка OverlayPortal, аватар 38, число задач в подсказке (ev_rail.dart:13-130)

- **Аналог в evaporate:** ConceptNavigation (GlobalKey на раздел, sectionLabel, Material Icons, queuedAt из DownloadsBloc.inWork) → NavigationRack (корпус 48, LiquidSelection 'rail-liquid' по targets[section], radiusChip) → NavigationKey (TextButton, LiquidSelectionInk, подпись заглавными, QueueBadge, Semantics selected); RackFit решает, что помещается (navigation_rack.dart:33-87)
- **Решение:** адаптировать
- **Почему:** Рейл — та же обойма, повёрнутая вертикально: GlobalKey на раздел, LiquidSelection над колонкой NavigationKey (вместо EvDroplet — сохраняемый эффект), QueueBadge = downloadsActive дизайна. Взять: стекло полосы, кромку справа, знак сверху, боковую подсказку (только если подписи прячутся). Не брать: аватар, «Друзья», EvFocusable со звуком. Черта у края окна — новое украшение через тему компонента, не число по месту. B12 (Concept → убрать, файл = класс) делать в этом же заходе.
- **Файлы дизайна:** evaporate_design/lib/shell/ev_rail.dart, evaporate_design/lib/glass/ev_droplet.dart
- **Файлы evaporate:** lib/ui/shell/navigation.dart, lib/ui/shell/navigation_rack.dart, lib/ui/shell/navigation_key.dart, lib/ui/shell/rack_fit.dart, lib/ui/shell/queue_badge.dart
- **Стражи:** widget_structure (ev_rail: 4 публичных виджета в файле, _SideTooltip 74 строки > 40 — резать на файлы), theme_structure (BorderRadius.circular(_markSize*14/48), withValues(alpha: 0.35), Duration 180 — токенами), liquid_selection_test ('rail-liquid' едет при SectionSelected, значок красится в onSelection), concept_shell_test ('concept-navigation' отцентрована), rail_quit_test (до 'rail-quit' ≤12 dpadRight от «НАСТРОЙКИ» — с вертикальным рейлом ожидание меняется), docs_names_test (переименование NavigationRack/ConceptNavigation требует правки CLAUDE.md в том же коммите)

### EvTopBar 58 — «EVAPORATE / <раздел>» крошка с AnimatedSwitcher, слот tools от 1080 (переключатель видов), _SearchButton с EvKey('/'), trailing плашки EvPill (скорость приёма, состояние движка) (ev_top_bar.dart:14-104; main.dart:556-643)

- **Аналог в evaporate:** ConceptTopBar 64 — WindowDragArea, TopBarBrand (знак 30 + слово EVAPORATE), ConceptNavigation по центру, TopBarActions: поиск → SearchFocusRequested, ThemeCycleAction, rail-minimize/rail-maximize (при WindowControl), rail-quit → windowManager.close() (top_bar.dart:17-53; top_bar_actions.dart:20-64)
- **Решение:** адаптировать
- **Почему:** Полоса дизайна принимает всё, что сейчас в рейке: WindowDragArea подложкой (окно тянут за крошку — IgnorePointer на тексте, как у TopBarBrand), TopBarActions справа (поиск, тема, свернуть/развернуть/выход — у дизайна их нет, а без рамки ОС они обязательны), trailing-плашки = EngineReadout в облике EvPill. Крошка «/ раздел» спорит с section_layout_test «имя раздела ровно один раз» — см. конфликт. Слот tools оставить пустым до появления режимов просмотра.
- **Файлы дизайна:** evaporate_design/lib/shell/ev_top_bar.dart, evaporate_design/lib/main.dart
- **Файлы evaporate:** lib/ui/shell/top_bar.dart, lib/ui/shell/top_bar_actions.dart, lib/ui/shell/top_bar_brand.dart, lib/ui/shell/window_drag_area.dart, lib/ui/shell/theme_cycle_action.dart
- **Стражи:** section_layout_test (имя раздела findsOneWidget), theme_structure (_fontSize/_textStyles/_iconSizes top_bar_brand: 1 — храповик уходит вместе с файлом; крошка fontSize 12/12.5 — ролью), window_frame_test (rail-minimize/maximize/quit зовут minimize/maximize/close; drag от 'window-drag-region'), concept_shell_test (tooltip темы перебирает три состояния), arb_usage (searchHint, minimizeWindow, maximizeWindow, restoreWindow, quitApp — читать по-прежнему)

### EvHintsBar 32 — стекло frost плотнее (tintAlpha .74), подсказки из evHints (первые пять evKeyBindings с hint), EvKey-чип + подпись 10.5 ink4, справа «● ГОТОВ/ЗАНЯТ» и «© 2026 EVAPORATE» (ev_hints_bar.dart:14-74; settings_data.dart:23-64)

- **Аналог в evaporate:** AppFooter 40 — ButtonHints (клавиатура: ↑↓←→/Enter/Esc/Ctrl+Tab//; геймпад: D-pad + binding.buttonsFor по пяти NavAction; _HintChip) + EngineReadout (PulseDot по colors.engine(state), engineStateLabel заглавными, ↓↑ скорости при activeCount>0) (app_footer.dart:19-66; button_hints.dart:22-75; engine_readout.dart:22-69)
- **Решение:** адаптировать
- **Почему:** Облик взять (стекло, высота 32, EvKey-чип вместо _HintChip), содержимое оставить evaporate: подсказки геймпада из GamepadBinding.buttonsFor у дизайна нет, а «● ГОТОВ/ЗАНЯТ» беднее четырёх состояний движка со скоростями. Копирайт не брать — section_layout_test запрещает его нарочно. Идея «строка и таблица клавиш не расходятся» хороша, но таблицы клавиш в настройках evaporate нет — брать вместе с карточкой «Клавиши», если она появится.
- **Файлы дизайна:** evaporate_design/lib/shell/ev_hints_bar.dart, evaporate_design/lib/settings/settings_data.dart
- **Файлы evaporate:** lib/ui/shell/app_footer.dart, lib/ui/shell/button_hints.dart, lib/ui/shell/engine_readout.dart
- **Стражи:** section_layout_test ('ОСТАНОВЛЕН' findsOneWidget, нет '© 2026 EVAPORATE'/'GITHUB'/'RELEASES'), app_shell_test (l.hintNavigate и «Выбрать» в подвале), theme_structure (fontSize 10.5, SizedBox(width: 7/20) — токенами), arb_usage (hintNavigate/hintSelect/hintBack/hintPlay/hintSearch/hintSections), engine_state_color_test

### Палитра «Поиск и команды» showEvPalette — PageRouteBuilder(opaque:false) с размытием, EvCommand (title/subtitle/onRun/onLaunch/cover), фильтр по названию и подписи, ≤9 строк, Enter/Shift+Enter, капля под строкой; команды: игры, разделы, смена облика и радиуса (ev_palette.dart:16-120; main.dart:676-710); клавиши «/» и Ctrl+K

- **Аналог в evaporate:** Прямого аналога нет. Ближайшее — LibrarySearchField в тулбаре + SearchFocusRequested + TypedSearchIntent на «/» (input_scope.dart:280); поиск живёт над сеткой, страница игры его закрывает (navigation_bloc.dart:48-58)
- **Решение:** новое
- **Почему:** Это новый экран — по CLAUDE.md сначала issue. Если брать: «/» остаётся поиском по сетке (тесты input_navigation_test), палитра — на Ctrl+K через _shortcuts с проверкой focusInTextField; список команд — чистая функция над LibraryBloc.games, AppSection и NavAction (без команд облика/радиуса — их у evaporate нет); Enter → GameOpened, Shift+Enter → dispatchPrimaryAction. Состояние строки поиска и выбранной строки — блок диалога (0001), не setState с ChangeNotifier.
- **Файлы дизайна:** evaporate_design/lib/shell/ev_palette.dart
- **Файлы evaporate:** lib/input/input_scope.dart, lib/ui/library/toolbar/library_search_field.dart, lib/ui/library/primary_action.dart
- **Стражи:** widget_structure (ev_palette: 3 публичных виджета, методы-виджеты _panel/_list — переписать), complexity (15/60/3), localization/arb_usage ('↵ выполнить', 'Закрыть поиск' — ключами ru+en), layering (lib/input не импортирует lib/ui), bloc_lint prefer_bloc (блок диалога), coverage (_reportedNowhere: новый файл без теста валит прогон), theme_structure (Color(0x99040408), blur 12, Interval 220/280 — токенами)

### Клавиши каркаса: цифры 1–6 и numpad → раздел, Ctrl+Tab/Ctrl+Shift+Tab (и из поля ввода), «/» по символу и физической клавише, Ctrl+K, Esc → back, widget.keys по PhysicalKeyboardKey (P → Пульт) — свой FocusScope.onKeyEvent (ev_shell.dart:148-232)

- **Аналог в evaporate:** InputScope — таблица _shortcuts (slash → TypedSearchIntent, Ctrl/Cmd+F, Ctrl+Tab/Shift, Cmd+[ ], Ctrl/Cmd+Enter primaryAction, Escape → back) + NavAction (12 действий) + мост геймпада + focusInTextField() (input_scope.dart:279-317; nav_action.dart:5-30)
- **Решение:** адаптировать
- **Почему:** Таблица _shortcuts расширяется строками, а не вторым обработчиком: цифры 1–4 → новый Intent «раздел по номеру» через AppSection.at(n) с проверкой focusInTextField (иначе съедят порт прокси и поиск); Ctrl+K — только вместе с палитрой; P — только вместе с Пультом. «/» по физической клавише в русской раскладке — полезная правка TypedSearchIntent. Геймпад цифр не имеет — NavAction не растёт, ButtonHints показывает только то, что работает.
- **Файлы дизайна:** evaporate_design/lib/shell/ev_shell.dart
- **Файлы evaporate:** lib/input/input_scope.dart, lib/input/nav_action.dart, lib/ui/shell/button_hints.dart
- **Стражи:** complexity (_handleAction switch уже 12 веток — новые Intent мимо него), layering (lib/input без lib/ui), input_navigation_test (бамперы/Ctrl+Tab, «/» в поле остаётся символом), gamepad_service_test

### Герой EvHero — высота 340–520 (52vh; 300 при ≤800; 520–660 при ≥1800), процедурный трёхслойный кадр с параллаксом за EvPointer и маревом при заряде, _GradePainter (виньетка, затемнение снизу/слева), тело внизу слева: EvEyebrow, название в 2 строки, blurb 46ch, чипы, CTA по EvHeroState (7 состояний), EvSavePointCard (ev_hero.dart:122-243; library_layout.dart:49-86; hero_state.dart:10-32)

- **Аналог в evaporate:** LibraryFeaturedSlot (игра — выбранная или первая; скрыт <520, compact <760) → FeaturedGame 238/128 → _FeaturedFrame → Stack[FeaturedArt (HeroSweep + ShotsBackdrop с настоящими кадрами/обложкой + три затемнения), FeaturedPoster (44 % ширины: eyebrow, FeaturedTitle, описание 2 строки, FeaturedActions по primaryActionFor) | FeaturedCompactBar, PlaytimeReadout] (featured_game.dart:51-96; library_featured_slot.dart:24-59)
- **Решение:** адаптировать
- **Почему:** Раскладку тела героя (eyebrow → название → чипы → CTA слева внизу, затемнение слева и снизу) переносить в FeaturedPoster; кадр — ShotsBackdrop/обложка с диска, не процедурный EvCover; высоту оставить 238/128/скрыт — section_layout_test держит первый ряд обложек в 1280×900, а вертикальный бюджет над сеткой считан. Состояния: 7 → GameStatus (6): «update» и «offline» источников не имеют, «installing» = downloading/paused; CTA решает primaryActionFor. Точка сохранения — новое: из последнего SaveSnapshot (createdAt, sizeBytes, deviceName), без «главы». Параллакс/марево — новые LibraryEffect на DecorationClock, вторым этапом.
- **Файлы дизайна:** evaporate_design/lib/library/ev_hero.dart, evaporate_design/lib/library/hero_state.dart, evaporate_design/lib/library/hero_cta.dart, evaporate_design/lib/library/library_layout.dart
- **Файлы evaporate:** lib/ui/library/featured_game.dart, lib/ui/library/library_featured_slot.dart, lib/ui/library/featured/featured_poster.dart, lib/ui/library/featured/featured_art.dart, lib/ui/library/primary_action.dart
- **Стражи:** section_layout_test (первый ряд обложек в 1280×900), library_grid_test (compact при 760, отсутствие при 420), theme_structure (_fontSize featured_title: 1 — titleSize clamp(34, 5.4vw, 68) как fontSize не пройдёт, нужна роль; _roleTweaks featured_poster: 1), widget_structure (_longClosures featured_game: 30; ev_hero методы-виджеты _cta/_body), complexity (_cta по состояниям → по виджету на состояние, как PrimaryActions), localization/arb_usage («Оверлей», «Завершить», «Подробнее»), effect_settings_test/effect_preset_test (новые LibraryEffect параллакс/марево)

### Карточка полки EvGameCard — ширина 178 ступенями, AspectRatio 3/4, lifted = hover||focus → −8 px, рамка hot1 .4, тени shadowLift + glow blur 42, кромка 1 px, EvCoverBadge (линза), EvBar 3 px снизу, диагональный sheen при подъёме, подпись title/subtitle под обложкой, EvFocusable с рамкой 2 px, звук tick (ev_game_card.dart:54-179)

- **Аналог в evaporate:** LibraryGridTile (MouseRegion → GameSelected; RiseIn; AnimatedContainer −7; KeyedSubtree(tileKey)) → FoilCard(active = hovered ?? selected; foil/tilt/distortion) → GameCoverTile (MergeSemantics → NavTile: рост 1.06, рамка selectionFrame) → CoverFrame (PortalSparks(selected && portal) снаружи ClipRRect, AspectRatio 2/3) → CoverFace (Semantics → FoilSurface → CoverDrops(selected && drops) → CoverArt; CoverProgressStrip | CoverStatusBadge) (library_grid_tile.dart:53-145; game_cover.dart:42-80; cover_frame.dart:33-64; cover_face.dart:46-73)
- **Решение:** оставить evaporate
- **Почему:** Это единственная цепочка, где живут все пять сохраняемых эффектов и якорь KeyedSubtree(tileKey) для капли и атмосферы; у EvGameCard нет ни наклона, ни искр, ни капель (наклон описан только в брендбуке). Взять от дизайна лишь облик деталей: EvCoverBadge → CoverStatusBadge, EvBar → CoverProgressStrip (через тему компонента), sheen не брать (второй блик поверх FoilSurface). Пропорция остаётся 2/3 — иначе golden искр и PortalOutline. Подпись под обложкой — только снаружи Semantics-узла и с правкой semantics_test.
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_game_card.dart, evaporate_design/lib/widgets/ev_focusable.dart
- **Файлы evaporate:** lib/ui/library/library_grid_tile.dart, lib/ui/library/game_cover.dart, lib/ui/library/nav_tile.dart, lib/ui/library/cover/cover_frame.dart, lib/ui/library/cover/cover_face.dart
- **Стражи:** portal_sparks_test (golden, over == 0, кайма 48), library_effects_test (builds == 1, одна анимирующая FoilCardState), cover_drops_test, semantics_test (плитка одним узлом-кнопкой), library_grid_test (подъём из AnimatedContainer.transform, наведение выбирает), effect_settings_test (ровно одна PortalSparks.enabled следует за GameSelected)

### Полки дизайна: вертикальный ListView(primary) с горизонтальными _Shelf (SingleChildScrollView, EvGameCard через 16) «Библиотека» (installed) и «Скоро на диске» (incoming), секция «Продолжить» из EvSessionGrid/EvSessionRow, EvSectionHeader с счётчиком (screens/library_page.dart:121-183, 263-296)

- **Аналог в evaporate:** LibraryGrid — LiquidSelection('grid-liquid') над GridView.builder (215·libraryScale, 2/3, 28/32, findChildIndexCallback по ValueKey), layoutFor/scrollTo для догона фокуса; полки — ShelfTabs (all/installed/notInstalled, LiquidSelection 'shelf-liquid') + LibrarySearchField в LibraryToolbar на GlassSurface (library_grid.dart:30-95; shelf_tabs.dart:30-55; toolbar.dart:43-64)
- **Решение:** оставить evaporate
- **Почему:** Горизонтальные полки — несколько Scrollable и другой targetKey для капли/атмосферы, ломают layoutFor/scrollTo, обход стрелками и возврат фокуса на непостроенную плитку; при 40+ играх ряд не читается. Сетка с вкладками-полками остаётся; «Продолжить» — новое значение Shelf.recent (по play.lastPlayed) во вкладках, а не отдельный ряд над сеткой (высота над сеткой зажата тестом). Раскладку EvSectionHeader (счётчик, линия) взять для ShelfButton-подписей числом, которые уже есть.
- **Файлы дизайна:** evaporate_design/lib/screens/library_page.dart, evaporate_design/lib/library/ev_session_row.dart
- **Файлы evaporate:** lib/ui/library/library_grid.dart, lib/ui/library/library_grid_controller.dart, lib/ui/library/toolbar/shelf_tabs.dart, lib/models/shelf.dart, lib/bloc/library_view/library_view_bloc.dart
- **Стражи:** library_grid_test (layoutFor при 1280/1100/1600, тождество плитки после отбора), liquid_selection_test ('grid-liquid', 'shelf-liquid'), section_layout_test, library_effects_test (targetKey атмосферы), arb_usage (новая подпись полки в обоих ARB)

### EvSectionHeader — капс section 13 ls 2.6 + счётчик ink4 + линия line→0 на всю ширину; стоит внутри страниц над каждой секцией (ev_surfaces.dart:599-633)

- **Аналог в evaporate:** SectionHeading — метка «[ 01 / КОЛЛЕКЦИЯ ]» ролью label в primary, Semantics(header) с обычным именем, trailing (section_heading.dart:21-75); подписи подразделов — SectionTitle (загрузки) и SectionCardHeader (карточки); в B12 отмечено «три слова для подписи раздела»
- **Решение:** адаптировать
- **Почему:** SectionHeading с меткой остаётся у раздела — section_layout_test держит нумерацию и единственность имени. Облик EvSectionHeader (счётчик, линия) — в SectionTitle/SectionCardHeader, и здесь же закрыть B12: одно слово для подписи подраздела вместо трёх. Нумерация «[ 0N ]» — по порядку рейла.
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_surfaces.dart
- **Файлы evaporate:** lib/ui/widgets/section_heading.dart, lib/ui/widgets/section_card_header.dart, lib/ui/downloads/section_title.dart
- **Стражи:** section_layout_test (метки и имя раздела), widget_structure lonelyShared (section_card_header: 2 потребителя; section_title живёт у загрузок), docs_names_test при переименовании

### Загрузки — приборная доска: EvHeadPanels(_RatePanel: «ПРИЁМ · СЕЙЧАС» EvBigNumber + EvRateGraph 74 px (случайное блуждание) + EvKpiGrid 2×2; _SwarmPanel: EvSwarmRing из четырёх долей + EvPeerHeat 32×2 случайных), EvTorrentRow (обложка 40×52, имя, путь, три клавиши, EvAlertBox с тоном, четыре прибора, EvBar по тону, подпись «11.8 / 28.8 ГБ · осталось»), EvQueueRow пунктиром; тики 1 с / 900 мс своим AnimationController (screens/downloads_page.dart:14-130; ev_torrent_row.dart:30-120)

- **Аналог в evaporate:** DownloadsPage (watchWhileShown) → GameDropTarget → DownloadsHeading (SectionHeading + EngineStatusChip + перезапуск) → DownloadsStatusBar (DownloadsReadout: сеть/отдача/активных из предела/в очереди + EngineFailure) → DownloadsColumns (AvailableGames с Draggable<Game> | QueueColumn DragTarget: TaskCard = TaskHeader + DownloadActivity (DownloadMetrics по DownloadHistoryBloc + DownloadChart + DownloadAmounts + AnimatedProgress) + TaskStats; QueueList Reorderable → QueuedCard) (downloads_page.dart:27-80)
- **Решение:** адаптировать
- **Почему:** Раскладку «приборы сверху, строки ниже» взять: _RatePanel → ReadoutPanel + DownloadChart на настоящей истории DownloadHistoryBloc (сумма по задачам — новая производная, минута, не час); EvTorrentRow → TaskCard (обложка через CoverArt/decodeWidth, путь task.dir, клавиши TaskActions + «открыть папку» — новое, приборы DownloadMetrics, EvAlertBox → InlineWarning на errorMessage/EngineFailure). Не брать: EvPeerHeat и первые 59 отсчётов графика (выдуманное рядом с настоящим), кольцо четырёх долей (движок отдаёт только completed/total — двухдольное). AvailableGames + Draggable оставить: единственный путь в очередь мышью. Тики — через watchWhileShown/DecorativeMotion, не свой контроллер.
- **Файлы дизайна:** evaporate_design/lib/screens/downloads_page.dart, evaporate_design/lib/downloads/ev_torrent_row.dart, evaporate_design/lib/downloads/rate_graph.dart, evaporate_design/lib/downloads/download_data.dart
- **Файлы evaporate:** lib/ui/downloads/downloads_page.dart, lib/ui/downloads/downloads_readout.dart, lib/ui/downloads/task_card.dart, lib/ui/downloads/download_activity.dart, lib/ui/downloads/download_chart.dart, lib/ui/downloads/queue_column.dart, lib/bloc/download_history/download_history_bloc.dart
- **Стражи:** widget_structure (_longClosures downloads_page: 36, queue_column: 38 — уменьшить или снять), download_chart_test / downloading_header_test (DownloadChart height:null подложкой страницы игры — API не менять), download_activity_test, download_cancel_test, queue_keys_test, hidden_page_test, thinFiles (engine_failure 0 — переписывая, дать тест), theme_structure (цвета EvBar 0xFF1B6F8A и др. только в lib/ui/theme; fontSize 11/13, alpha .32/.026), localization/arb_usage (тексты разборов и подписей), FrequentEvent (EngineTasksChanged/EngineStatsChanged)

### Сохранения — EvHeadPanels(_CloudPanel: «ОБЛАКО · ЗАНЯТО» EvBigNumber «4.1 из 20», EvBar, EvKpiGrid; _DevicePanel: устройства со статусом), секция конфликта EvConflictCard («ПРОТИВ», «Оставить эту», «Сохранить обе»), EvSaveTimeline на EvThread из EvSaveRow (where/stamp/EvBar/чипы mark/device), EvNothing при недоступном облаке (screens/saves_page.dart:60-160; ev_timeline.dart:66-120)

- **Аналог в evaporate:** SavesPage (selectWhileShown) — CustomScrollView: SectionHeading + SavesReadout (снимков/занято/игр с путями/последний) → SliverSideBySide(≥1080, 430 | остальное): BulkTransferCard + SyncFolderCard (папка синхронизации, «Проверить», SyncFolderContents/SyncPackageRow) | SnapshotHistory — ленивый SliverList в SliverGlassClip из SnapshotRow (saves_page.dart:32-100)
- **Решение:** адаптировать
- **Почему:** Раскладку двух приборов сверху взять: _CloudPanel → SavesReadout (без квоты — папка синхронизации без предела), _DevicePanel — новое, честное: устройства из deviceName снимков и пакетов с «последний снимок тогда-то» вместо «в сети/офлайн». Ленту (нить, точки, чипы устройства/origin) — в облик SnapshotRow при сохранении SliverList (snapshot_history_test требует ленивость). Конфликт двух версий не брать: состояния нет, ближайшее — ImportNewerDialog и RestorePreviewBloc на странице игры; «где остановился» — только note снимка.
- **Файлы дизайна:** evaporate_design/lib/screens/saves_page.dart, evaporate_design/lib/saves/ev_timeline.dart, evaporate_design/lib/saves/ev_conflict.dart, evaporate_design/lib/widgets/ev_thread.dart
- **Файлы evaporate:** lib/ui/saves/saves_page.dart, lib/ui/saves/saves_readout.dart, lib/ui/saves/snapshot_history.dart, lib/ui/saves/snapshot_row.dart, lib/ui/saves/sync_folder_card.dart, lib/bloc/saves/saves_state.dart
- **Стражи:** snapshot_history_test (строки строятся по мере прокрутки), saves_page_test (показания считают снимки, удаление с именем игры), sliver_glass_clip_test, sliver_side_by_side_test, thinFiles (bulk_outcome_group, bulk_report_view, pick_game_dialog, sync_folder_contents, sync_package_row — все на 0 %, переписанные обязаны получить тесты), localization/arb_usage

### Настройки — липкая колонка 212 (EvSettingsSearch + EvSettingsNavItem по видимым разделам + версия), spy по прокрутке, _go через animateTo к GlobalKey-якорю, narrow 880 → колонка над телом; десять разделов данными EvSettingSection/EvSettingPanel/EvSettingRow с words и dim, поиск по основе слова; панель «Разработка» (screens/settings_page.dart:117-345; settings_search.dart:1-70)

- **Аналог в evaporate:** SettingsPage — FocusTraversalGroup(_ListTraversal) + Shortcuts стрелок без ignoreTextFields + SingleChildScrollView (не ListView — все карточки в дереве) + Column из SectionHeading и 12 карточек в фиксированном порядке; каждая карточка читает блок сама (settings_page.dart:24-102)
- **Решение:** адаптировать
- **Почему:** Колонку навигации с якорями взять как новый виджет над теми же 12 карточками (GlobalKey на карточку, animateTo, spy, ниже 880 — над телом); порядок карточек и _ListTraversal оставить. Поиск — второй этап: карточкам нужен список слов, а это либо каталог данными (перестройка всех 12 карточек), либо фильтр по заголовкам. Не брать: «Звук», «Раздача», «Клавиши», расписание скорости, папки-диски, порт/шифрование, «Разработка» — ни модели, ни движка под ними нет. B14/B15 (select по части, SettingRow, patchSettings) закрывать в этом же заходе.
- **Файлы дизайна:** evaporate_design/lib/screens/settings_page.dart, evaporate_design/lib/settings/settings_search.dart, evaporate_design/lib/settings/ev_settings_widgets.dart, evaporate_design/lib/settings/settings_catalog.dart
- **Файлы evaporate:** lib/ui/settings/settings_page.dart, lib/ui/settings/cards/appearance_card.dart, lib/ui/widgets/section_card.dart
- **Стражи:** settings_navigation_test (все карточки в дереве, стрелка вниз уводит из поля, спуск до «Проверить обновления»), settings_layout_test (язык/тема в карточке вида; крупность в библиотеке; перезапуск движка только на загрузках; украшения набором), reachability_test, effect_settings_test (ключи effects-*), theme_structure (_layoutHere width: 220 settingLabelWidth; navWidth 212 — новая константа EvaporateLayout), complexity/widget_structure для нового виджета колонки, B14/B15 из TODO

### Карточка «Эффекты» дизайна — EvEffects ChangeNotifier: livingBackground, sparks, parallax, grain, glass, refraction, quality Эко/Полное/Макс, ritual, holdToPlay, throttleInBackground; «Сбросить» (design/effects.dart:43-83; settings_catalog.dart:410-491)

- **Аналог в evaporate:** LibraryEffectsCard 'living-library-settings' → EffectPresetPicker (off/calm/standard/full, 'effects-preset') + EffectDetails (ExpansionTile 'effects-details', 'effects-master-toggle', переключатель на каждое LibraryEffect.values с ключом effects-<name>-toggle, independent мимо мастера) (effect_details.dart:20-60; library_effect.dart:89-99)
- **Решение:** оставить evaporate
- **Почему:** Модель украшений остаётся Set<LibraryEffect> с jsonKey на диске и лестницей пресетов; новые украшения дизайна (параллакс героя, марево, плюм, зерно) — новые значения enum со строкой в shipped или без неё, подписью в ARB и записью в effect_settings_test. Качество Эко/Полное/Макс — множитель, не булево, в лестницу пресетов не ложится: отложить до отдельного решения (поле Appearance с плоским ключом).
- **Файлы дизайна:** evaporate_design/lib/design/effects.dart
- **Файлы evaporate:** lib/ui/settings/effect_details.dart, lib/ui/settings/effect_preset_picker.dart, lib/models/library_effect.dart, lib/models/effect_preset.dart
- **Стражи:** effect_settings_test (умолчания поимённо, toJson/fromJson обратимы), effect_preset_test (calm ⊂ standard ⊂ full), model_roundtrip_test (плоская запись), settings_layout_test (набором, а не галочками)

### Режимы просмотра — EvLibraryView showcase/wall/term в ValueNotifier, EvViewSwitch в топбаре (tools от 1080), WallPage (локальные _filter/_selected, evWallCells minTile 146/gap 11, большая плитка 3×2 первой, EvWallTile подъём −4, EvWallFeature свечение), TermPage (сортировка по столбцам, локальный _selected, ↑↓ с ensureVisible, Enter, жанр/версия/часы из EvGameFacts) (modes_data.dart:8-60; wall_page.dart:10-60; term_page.dart:26-90)

- **Аналог в evaporate:** Аналога нет. Ближайшее — libraryScale через ScaleControl 'library-scale' в ConceptLibraryHeading (library_heading.dart:30-51) и Shelf-вкладки; выбор — только NavigationBloc.selectedGameId; плитки — LibraryGridController.tileKey/targetKey
- **Решение:** новое
- **Почему:** Новый экран — issue до правки. Если брать: вид — событие LibraryViewBloc (уже экранный блок) или поле Appearance (плоский ключ), не ValueNotifier; Стена = та же LibraryGrid с иным делегатом и первой большой плиткой, выбор и ключи плиток через тот же контроллер (иначе капля/искры/атмосфера потеряют цель); Терминал — таблица без жанра/версии (статус, обложка 22, название, размер, наиграно, последний запуск). Кайма искр 48 при gap 11 налезет на соседей — см. конфликт.
- **Файлы дизайна:** evaporate_design/lib/modes/modes_data.dart, evaporate_design/lib/modes/ev_view_switch.dart, evaporate_design/lib/modes/ev_wall.dart, evaporate_design/lib/screens/wall_page.dart, evaporate_design/lib/screens/term_page.dart
- **Файлы evaporate:** lib/ui/library/library_grid.dart, lib/ui/library/library_grid_controller.dart, lib/bloc/library_view/library_view_bloc.dart, lib/models/appearance.dart
- **Стражи:** bloc_lint prefer_bloc (ValueNotifier → событие блока), library_grid_test (layoutFor/scrollTo под новый делегат), liquid_selection_test / library_effects_test (targetKey), portal_sparks_test golden (кайма 48), settings_layout_test:56 (крупность в библиотеке), complexity/coverage/localization для новых файлов, decodeWidth (обложка 22 px — новая ступень)

### Пульт showEvPult — PopupRoute без барьера, Fade 380 мс, размытый фон обложки (blur 34, saturate, scale 1.18), карусель пяти обложек, заголовок до 58 px, две большие кнопки, подсказки A/X/◄►/Y/B, ←→/Enter/Esc, клавиша P (ev_pult.dart:29-98)

- **Аналог в evaporate:** Аналога нет. Части: FeaturedGame (крупный кадр), CoverBackdrop (размытая обложка страницы игры), ButtonHints геймпада, GamepadBinding (A confirm, B back, X primaryAction, Y search, RB/LB разделы — свободной кнопки нет)
- **Решение:** не брать
- **Почему:** Новый экран под геймпад — отдельный issue после каркаса. Если однажды брать: отдельный маршрут (decorationMayRun гасит украшения библиотеки под ним по ModalRoute.isCurrentOf — желаемо), свои PortalSparks/DecorativeMotion вокруг центральной обложки, вход — новое NavAction без свободной кнопки на геймпаде (Y занят поиском); P в русской раскладке — «З», ловить физическую клавишу через focusInTextField.
- **Файлы дизайна:** evaporate_design/lib/modes/ev_pult.dart
- **Файлы evaporate:** lib/input/gamepad_binding.dart, lib/ui/widgets/window_visibility.dart
- **Стражи:** input_scope/gamepad_binding (NavAction без свободной кнопки), decorationMayRun (ModalRoute.isCurrentOf), coverage (_reportedNowhere)

### Лист игры showEvGameSheet — PopupRoute barrierDismissible (клик мимо закрывает), 420 мс с подъёмом 18 px, лист maxWidth 1080, CustomScrollView: _SheetArt (параллакс, eyebrow, название, чипы, крестик) → SliverPersistentHeader pinned _SheetBar 71 (полоса действий по состоянию окна сильнее раздачи) → EvSheetBody (история/достижения/состав/раздача | сохранения/друзья/действия; <900 одной колонкой) (ev_game_sheet.dart:59-130)

- **Аналог в evaporate:** GamePage вместо сетки по openedGameId (library_page.dart:129) — Stack[CoverBackdrop, Column[BackToLibraryButton, GameDetail]]; GameDetail — ListView maxWidth 940: DetailHeader | DownloadingHeader (график под заголовком), ActionPanel (PrimaryActions + SteamActions + DownloadActivity/TaskStats + InlineWarning), SavePathsSection, SnapshotsSection, FilesSection, InfoSection, RemoveGameButton (game_page.dart:19-48; game_detail.dart:28-58)
- **Решение:** адаптировать
- **Почему:** Страница остаётся страницей внутри раздела, не модалкой: на этом стоят возврат фокуса на плитку (_restoreFocusOnClose), openedGameId в NavigationBloc, Esc/«К библиотеке», GameDropTarget и семантика («Папки сохранений» у открытой игры). Взять: липкую полосу действий (SliverPersistentHeader pinned с ActionPanel — GameDetail переходит на CustomScrollView) и двухколоночную раскладку тела ≥900 (слева заголовок/описание/DownloadActivity/FilesSection/InfoSection, справа 300: SavePathsSection + SnapshotsSection и «Действия» = GameFileActions/Steam/RemoveGameButton). Не брать: достижения, друзья, история семи сессий, «Глава 5 · 62 %» — нет данных; «состав на диске» — только по списку файлов задачи, если он есть.
- **Файлы дизайна:** evaporate_design/lib/sheet/ev_game_sheet.dart, evaporate_design/lib/sheet/sheet_blocks.dart
- **Файлы evaporate:** lib/ui/library/game_page.dart, lib/ui/library/game_detail.dart, lib/ui/library/detail/action_panel.dart, lib/ui/library/detail/primary_actions.dart, lib/ui/library/library_page.dart
- **Стражи:** game_page_back_test (подложка возврата radiusSelection обнимает клавишу), game_actions_test (Steam справа в одном ряду, папка в «Подробностях», график под заголовком), game_page_effects_test (LauncherActionButton 48×≥112, один DecorativeMotion), semantics_test (открытая игра сохраняет «Папки сохранений»), input_navigation_test (закрытие возвращает фокус на game:<id>), widget_structure/complexity (_SheetBar ~190 строк с двумя switch — по виджету на состояние), B13 из TODO (побочные действия LibraryPage.build → BlocListener) — тот же файл

### EvPlayButton — удержание 620 мс (AnimationBehavior.preserve, reverse 160), дыхание ядра 3.6 с, спекулярный блик, кольцо заряда _ChargeRingPainter, «УДЕРЖАТЬ»/caption, cool-вариант для загрузки, requireHold: false — по нажатию (ev_play_button.dart:72-130)

- **Аналог в evaporate:** LauncherActionButton — ход travel 1/3, блик keySheen, торец depth, кант selection в фокусе; подпись/значок/доступность из primaryActionFor/canDoPrimaryAction (launcher_action_button.dart; primary_action.dart:21-47); стоит в FeaturedActions, ActionPanel и ещё одном месте
- **Решение:** адаптировать
- **Почему:** Облик (кольцо, ядро, cool-вариант для download) — как тема компонента с двумя экземплярами arclight/cartridge; решение о подписи и доступности — по-прежнему primary_action.dart. Удержание — вторым этапом и с независимым флагом (как selectionFrame): на геймпаде кнопка X зовёт dispatchPrimaryAction мгновенно (shell.dart:28-37), и без удержания там защита дырявая; при disableAnimations context.motion даёт still, а 620 мс защиты сжимать нельзя — нужен preserve мимо токенов, что требует записи в _durations.
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_play_button.dart
- **Файлы evaporate:** lib/ui/widgets/launcher_action_button.dart, lib/ui/library/primary_action.dart, lib/ui/shell.dart
- **Стражи:** game_page_effects_test (48 в высоту, ≥112, срабатывает с клавиатуры один раз), primary_action_test (подпись гаснет, а не исчезает), theme_structure (_durations/_curves/_alphas — 620/3600/1050, Curves.easeOut, alpha .85/.42 только через тему или новые записи), motion_test (still при disableAnimations), localization/arb_usage («УДЕРЖАТЬ», «Играть»), lonelyShared (launcher_action_button — 3 потребителя, ок)

### EvFocusable — FocusableActionDetector + ActivateIntent, рамка 2 px hot2 с отступом 5 только при onShowFocusHighlight (клавиатурная навигация), звук tap; null-действие снимает фокус (ev_focusable.dart:51-92)

- **Аналог в evaporate:** NavTile — InkWell, AnimatedScale 1.06 и рамка 2.5 colors.selection по фокусу, showFocusBorder = isOn(selectionFrame) (independent, мимо мастера), Scrollable.ensureVisible, onFocusChange → GameSelected (nav_tile.dart:34-92; game_cover.dart:61-69)
- **Решение:** адаптировать
- **Почему:** Правило «рамка только при клавиатурной навигации» (FocusManager.highlightMode) взять в NavTile — совместимо с независимым флагом selectionFrame и уберёт рамку после клика мышью. Второй примитив фокуса не заводить: у NavTile уже ensureVisible и связь с выбором. Звук не брать.
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_focusable.dart
- **Файлы evaporate:** lib/ui/library/nav_tile.dart
- **Стражи:** effect_settings_test:284-339 (рамка мимо мастера), reachability_test (кант фокуса главной клавиши), semantics_test

### Стекло: EvGlass (frost blur 22 / lens blur 6 + bevel / chip 0; tint ступенью палитры, зерно, блик кромки вершинами от курсора EvPointer, hover-свечение, нажатие 1.035), EvPanel с glowCorner, EvScrollEdge (8 полос BackdropFilter.grouped), BackdropGroup, EvGlassLens только под Impeller (ev_glass.dart; glass_style.dart; ev_scroll_edge.dart)

- **Аналог в evaporate:** GlassSurface (BackdropFilter blur 16, GlassSurfaceTheme: fillOpacity/sheenTop/sheenBottom/rim/counterLight с экземплярами arclight/cartridge, decorationOf для сливеров), SectionCard (18 потребителей), SliverGlassClip, ShellPanel (surface × shellOpacity без blur), LibraryToolbar на GlassSurface (glass_surface.dart; toolbar.dart:50-63)
- **Решение:** адаптировать
- **Почему:** Числа материалов frost/chip и плотность полос каркаса — поля GlassSurfaceTheme (обязаны различаться у arclight и cartridge — hardware_surface_theme_test); BackdropGroup для трёх полос — взять. Не брать: линзу (Impeller-only, гаснет под любым Opacity <255 — FadeIndexedStack, RiseIn), свет кромки от курсора (второй тикер, у геймпада курсора нет), зерно на всё окно и EvScrollEdge из восьми BackdropFilter (цена кадра под FoilCard/PortalSparks/CoverDrops).
- **Файлы дизайна:** evaporate_design/lib/glass/ev_glass.dart, evaporate_design/lib/glass/glass_style.dart, evaporate_design/lib/glass/ev_scroll_edge.dart, evaporate_design/lib/widgets/ev_surfaces.dart
- **Файлы evaporate:** lib/ui/widgets/glass_surface.dart, lib/ui/theme/glass_surface_theme.dart, lib/ui/widgets/section_card.dart, lib/ui/shell/shell_panel.dart
- **Стражи:** hardware_surface_theme_test (схемы различаются в каждом поле), theme_fields_test (lerp/values), theme_test (WCAG на светлом корпусе под стеклом), color_palette_test (Color только в lib/ui/theme), sliver_glass_clip_test, widget_structure (ev_surfaces: 9 публичных виджетов в файле)

### EvAtmosphere — плюм на plume.frag (toImageSync каждый кадр), угли drawAtlas, зерно 128×128, свой Ticker + AppLifecycleListener + Timer 30 к/с на inactive, EvPointer в долях окна (ev_atmosphere.dart)

- **Аналог в evaporate:** AmbientLight в AppShell (три пятна gameAmbientColors(title) выбранной игры + виньетка, без blur; сила из HardwareSurfaceTheme) + LibraryAtmosphere в LibraryBody (частицы 4800 + перламутр днём, DecorationClock, цель — targetKey плитки) + GameWave в ShellPanel только для библиотеки (shell.dart:84-88; library_body.dart:67-71; shell_panel.dart:40-44)
- **Решение:** оставить evaporate
- **Почему:** Часы одни — DecorationClock с decorationMayRun (inactive считается видимым — window_visibility), AppLifecycleListener отвергнут в decoration_clock.dart:88-89; второй тикер с 30 к/с не заводить. Плюм — если брать, то новым LibraryEffect на DecorationClock и в цветах gameAmbientColors (по игре, а не по облику), вторым этапом; угли дублируют частицы, зерно — цена на всё окно. Пересадка GameWave вместе с условием section == library при смене панели.
- **Файлы дизайна:** evaporate_design/lib/atmosphere/ev_atmosphere.dart, evaporate_design/lib/atmosphere/ev_pointer.dart
- **Файлы evaporate:** lib/ui/shell/ambient_light.dart, lib/ui/library/effects/library_atmosphere.dart, lib/ui/library/effects/game_wave.dart, lib/ui/widgets/decoration_clock.dart, lib/ui/widgets/window_visibility.dart
- **Стражи:** library_effects_test (фон при скрытом окне часов не пускает; 'library-wave'), widget_structure (_longClosures library_atmosphere: 40, game_wave: 43), effect_settings_test (новое украшение), pubspec shaders (новый .frag), coverage (thinFiles cover_drops 44 — образец цены шейдера без теста)

### EvDroplet — Positioned по Rect в чужом Stack, стеклянный чип droplet без чтения фона, вытягивание вдоль и сужение поперёк в полёте, хозяин сам считает Rect (EvRail.dropletRect статикой, EvSegmented по GlobalKey после кадра, палитра со сдвигом скролла) (ev_droplet.dart; ev_rail.dart:72-84)

- **Аналог в evaporate:** LiquidSelection — targetKey GlobalKey? Function(), замер после кадра и по ScrollNotification/SizeChanged, путь двух долей с перемычкой и прыжком на дальнем, 460 мс, decorationMayRun, LiquidInkScope перекрашивает подписи; три места: 'rail-liquid', 'grid-liquid', 'shelf-liquid' (liquid_selection.dart:13-95; navigation_rack.dart:60-67; library_grid.dart:46-52; shelf_tabs.dart:42-49)
- **Решение:** оставить evaporate
- **Почему:** Жидкая подложка — сохраняемый эффект: в рейле дизайна LiquidSelection ставится над колонкой NavigationKey с теми же GlobalKey targets[section]; EvSegmented → штатный SegmentedButton evaporate (segmentedButtonTheme). Стеклянный материал капли (tint, кромка) можно дать LiquidPainter полем темы, геометрию и замер не менять. Держать оба — две подсветки выбранного.
- **Файлы дизайна:** evaporate_design/lib/glass/ev_droplet.dart, evaporate_design/lib/widgets/ev_controls.dart
- **Файлы evaporate:** lib/ui/widgets/liquid/liquid_selection.dart, lib/ui/widgets/liquid/liquid_selection_path.dart, lib/ui/widgets/liquid/liquid_selection_ink.dart
- **Стражи:** liquid_selection_test (три подложки, перекраска ink в onSelection, NaN-матрица), theme_structure (_durations liquid_selection: 1; _curves liquid_selection_path: 3 — не трогать)

### Первый запуск — EvLibraryEmpty (дышащий знак, «Просканировать диск» EvPlayButton, «Вставить magnet», нажимаемая зона броска, подсказки Ctrl+O/Ctrl+V/«/»), EvLibrarySkeleton с таймером 300 мс, EvFlowBar сценария над навигатором, диалог «Добавить раздачу» с частями (ev_first_run_widgets.dart; ev_add_torrent.dart)

- **Аналог в evaporate:** LibraryEmptyState — различает «пусто» и «поиск не нашёл», FilledButton «Добавить игру» → showAddGameDialog (library_empty_state.dart:9-60); AddGameMenuButton («Указать источник», «Найти установленные»), ScanDialog/ScanSession, GameDropTarget обнимает пустую полку (library_body.dart:82-87) — бросок уже настоящий
- **Решение:** адаптировать
- **Почему:** Три входа в раскладке EvLibraryEmpty на существующие действия: скан → onScan/ScanDialog, magnet → showAddGameDialog, бросок — GameDropTarget уже вокруг; ветку «поиск ничего не нашёл» сохранить (у дизайна её нет). Скелет, полосу сценария и таймер 300 мс не брать — library.json читается мгновенно; диалог с частями — только если движок умеет выбирать файлы раздачи.
- **Файлы дизайна:** evaporate_design/lib/first_run/ev_first_run_widgets.dart, evaporate_design/lib/first_run/ev_add_torrent.dart
- **Файлы evaporate:** lib/ui/library/library_empty_state.dart, lib/ui/library/add_game_dialog.dart, lib/ui/library/scan_folder_dialog.dart, lib/ui/widgets/game_drop_target.dart
- **Стражи:** localization/arb_usage (libraryEmpty/libraryEmptyNote/addGame читаются; новые ключи ru+en), add_game_dialog_test, widget_structure (_GlowingMark StatefulWidget с контроллером — свой файл; часы через DecorativeMotion), thinFiles (drop_overlay 2)

### Плашки EvPill в trailing топбара — скорость приёма (idle/busy), состояние движка/сохранений («Движок готов», «Нет раздающих», «1 конфликт», «Пока вас не было · N») (main.dart:556-643; ev_surfaces.dart:240-334)

- **Аналог в evaporate:** EngineReadout в подвале (PulseDot + engineStateLabel + ↓↑) и EngineStatusChip в DownloadsHeading — один switch цвета/мигания в engine_state_color.dart (engine_readout.dart:22-69; downloads_heading.dart)
- **Решение:** адаптировать
- **Почему:** Одна реализация EngineReadout в облике EvPill; место — либо trailing топбара, либо строка подсказок, не оба. Плашки состояний сохранений и дайджеста не брать (нет облака/конфликта/журнала событий). Скорость — из EngineStats, как сейчас.
- **Файлы дизайна:** evaporate_design/lib/main.dart, evaporate_design/lib/widgets/ev_surfaces.dart
- **Файлы evaporate:** lib/ui/shell/engine_readout.dart, lib/ui/downloads/engine_status.dart, lib/ui/downloads/engine_state_color.dart
- **Стражи:** section_layout_test ('ОСТАНОВЛЕН' ровно один раз где бы ни стоял), engine_state_color_test, lonelyShared (pulse_dot: 2 потребителя)

### Правая колонка от 1800 px — EvFriendsCard и EvDownloadsNowCard (screens/library_page.dart:197-235, 300-330); ступени поля gutterFor 16…44 и ширины карточек 134–224

- **Аналог в evaporate:** Нет: contentMaxWidth 1340 зажимает и центрует широкие экраны (EvaporateLayout, layout.dart), поле 28 постоянное
- **Решение:** не брать
- **Почему:** Друзей нет; «Качается сейчас» дублирует раздел загрузок и EngineReadout. Предел 1340 держится нарочно (строка описания, карточка задачи, график) — колонку от 1800 некуда ставить. Ступенчатое поле — решение темы, не структуры; при желании — новое поле EvaporateLayout.pagePaddingFor уже принимает ширину.
- **Файлы дизайна:** evaporate_design/lib/library/ev_side_cards.dart, evaporate_design/lib/screens/library_page.dart
- **Файлы evaporate:** lib/ui/theme/layout.dart
- **Стражи:** theme_structure (_layoutHere: 1340/28 только константами)

### EvBottomNav 60 ниже 760 px и минимум окна 1280×720 с системным заголовком DWM (ev_shell.dart:264-268; README.md:636-652)

- **Аналог в evaporate:** RackFit — обойма сама сжимается (подписи от 124, метка от 58), минимум окна 900×620 без системной рамки (rack_fit.dart; window_state.dart)
- **Решение:** не брать
- **Почему:** Минимум 900 по ширине — ниже 760 окно не бывает, нижняя панель недостижима; README сам говорит «на Windows до этого не доходит». Системный заголовок возвращать не надо: клавиши окна и перетаскивание переезжают в новый топбар (см. EvTopBar).
- **Файлы дизайна:** evaporate_design/lib/shell/ev_rail.dart
- **Файлы evaporate:** lib/ui/shell/rack_fit.dart, lib/services/system/window_state.dart
- **Стражи:** app_shell_test (820×620 и 620), window_frame_test (наименьшее окно 900×620)

### Иконки — EvIcon/EvMark: 39 SVG из design/assets через flutter_svg с ColorFilter, EvIcons строковые константы (ev_icon.dart:12-119)

- **Аналог в evaporate:** Material Icons (Icons.grid_view_outlined/download_rounded/save_rounded/settings_rounded в ConceptNavigation; Icons.* по всему lib/ui), размеры — EvaporateIconSize
- **Решение:** не брать
- **Почему:** Новая зависимость (flutter_svg) — по CLAUDE.md сначала issue и запись в docs/decisions; окраска через ColorFilter не наследует IconTheme, имя иконки строкой молчит при опечатке. Material Icons остаются; при желании набор дизайна позже конвертируется в шрифт значков (font_licenses_test).
- **Файлы дизайна:** evaporate_design/lib/widgets/ev_icon.dart
- **Файлы evaporate:** lib/ui/shell/navigation.dart, lib/ui/theme/icon_size.dart
- **Стражи:** layering (плагин в моделях запрещён транзитивно), git diff регистраторов плагинов после pub get, theme_structure (_iconSizeHere)

## Конфликты

### Крошка «EVAPORATE / <раздел>» в топбаре против единственного имени раздела

- **Дизайн:** EvTopBar пишет имя раздела второй частью крошки с AnimatedSwitcher (ev_top_bar.dart:53-91); в рейле у кнопок нет подписей — только значок и боковая подсказка
- **Evaporate:** section_layout_test:54-77 требует, чтобы имя раздела встречалось ровно один раз (в обойме), а страница несёт метку «[ 0N / … ]» через SectionHeading с Semantics(header)
- **Рекомендация:** Если рейл идёт с подписями под значками — крошку не вводить. Если рейл только со значками 48×44 — крошка становится единственным именем раздела, метка SectionHeading остаётся на странице, тест не правится (одно вхождение сохраняется). Смешивать нельзя: два имени на экране — то, от чего тест написан.

### Смена раздела: уничтожение экрана против живых разделов

- **Дизайн:** AnimatedSwitcher с ключом (section, detail) выбрасывает уходящий экран; «к началу» через primary-скролл; переход 340/440 мс с подъёмом 10 px (ev_shell.dart:249-260; README.md:656-661)
- **Evaporate:** FadeIndexedStack держит всех детей и раздаёт TickerMode текущему — на нём GameDropTarget, WatchWhileShown, decorationMayRun, DownloadHistoryBloc один на приложение (fade_indexed_stack.dart:5-10, 84)
- **Рекомендация:** Оставить FadeIndexedStack; переход дизайна воспроизвести внутри него (сдвиг 10 px рядом с проявлением, ступени context.motion). «К началу» при повторном выборе — отдельное событие блока, не часть каркаса.

### Число разделов: шесть против четырёх

- **Дизайн:** EvSection — library, downloads, saves, settings, friends, profile; клавиши 1–6; аватар в рейле открывает профиль (ev_section.dart:7-24)
- **Evaporate:** AppSection — четыре; индекс = индекс стека и номер метки; «Друзья» и «Профиль» без бэкенда (аккаунты, presence) не имеют ни одного настоящего числа; README дизайна сам сохраняет четыре (README.md:2127)
- **Рекомендация:** Четыре раздела. Профиль/статистика, если понадобится, — карточка в «Настройках» или «Сохранениях», не пятый раздел.

### Строка подсказок: «● ГОТОВ/ЗАНЯТ» и копирайт против четырёх состояний движка и скоростей

- **Дизайн:** EvHintsBar показывает подсказки из таблицы клавиш, справа «● ГОТОВ/ЗАНЯТ» и «© 2026 EVAPORATE» (ev_hints_bar.dart:64-69); README называет строку «подписью приложения, которую нельзя терять» (README.md:2126)
- **Evaporate:** AppFooter: ButtonHints по GamepadBinding.buttonsFor (геймпад/клавиатура) и EngineReadout с четырьмя состояниями и ↓↑; section_layout_test:79-90 требует «ОСТАНОВЛЕН» и запрещает копирайт
- **Рекомендация:** Облик дизайна (стекло 32, EvKey-чип), содержимое evaporate. Копирайт не возвращать. Подсказки из таблицы клавиш — только когда карточка «Клавиши» появится в настройках и та же таблица кормит и InputScope.

### Лист игры модалкой против страницы внутри раздела

- **Дизайн:** showEvGameSheet — PopupRoute с barrierDismissible, клик мимо закрывает, лист 1080 поверх окна (ev_game_sheet.dart:59-96)
- **Evaporate:** LibraryPage возвращает GamePage вместо сетки по openedGameId (library_page.dart:129); возврат фокуса на плитку, Esc/«К библиотеке», GameDropTarget под TickerMode, семантика разделов открытой игры — всё завязано на страницу
- **Рекомендация:** Страница остаётся страницей; от дизайна берутся липкая полоса действий (SliverPersistentHeader pinned) и двухколоночное тело. Модалка вернула бы потерю фокуса и второй путь навигации мимо NavigationBloc.

### Карточка полки: 3/4, подъём −8, sheen, EvFocusable против цепочки FoilCard→NavTile→CoverFrame→CoverFace

- **Дизайн:** EvGameCard — AspectRatio 3/4, lifted при hover||focus, диагональный sheen, EvCoverBadge, EvBar, подпись под обложкой, EvFocusable рамка (ev_game_card.dart:54-179); наклона/искр/капель нет
- **Evaporate:** Плитка 2/3, подъём −7 в AnimatedContainer (тест читает transform), FoilCard с наклоном/фольгой, PortalSparks снаружи ClipRRect с каймой 48, CoverDrops по coverPath, KeyedSubtree(tileKey) для капли/атмосферы (library_grid_tile.dart:106-145; cover_frame.dart:35-62)
- **Рекомендация:** Цепочку evaporate не трогать — она и есть сохраняемое выделение. От дизайна — только облик бейджа и полосы через тему компонента. Пропорция 2/3 фиксируется (golden искр, PortalOutline).

### Горизонтальные полки против вертикальной сетки

- **Дизайн:** Полки «Библиотека»/«Скоро на диске» — горизонтальные SingleChildScrollView с промежутком 16, вертикальной сетки нет (screens/library_page.dart:263-296)
- **Evaporate:** GridView.builder 215·scale с layoutFor/scrollTo, LiquidSelection над сеткой, атмосфера по targetKey, обход стрелками и возврат фокуса на непостроенную плитку (library_grid.dart:43-95; library_grid_controller.dart)
- **Рекомендация:** Сетка остаётся; «Продолжить» — новое значение Shelf во вкладках, а не отдельный ряд над сеткой (высота над сеткой зажата section_layout_test).

### Наведение выбирает игру против «наведение только поднимает карточку»

- **Дизайн:** EvGameCard при наведении лишь поднимается и звучит; герой не следует за курсором (ev_game_card.dart:59-72)
- **Evaporate:** LibraryGridTile._hover шлёт GameSelected (library_grid_tile.dart:71-77); крупный кадр и AmbientLight идут за selectedGameId; library_grid_test:288-313 держит это
- **Рекомендация:** Оставить правило evaporate: кнопка X геймпада и «Играть» в кадре работают по игре под курсором, не заходя внутрь. Менять — только вместе с тестами и решением, что делает X без наведения.

### Настройки: каталог данными с поиском против 12 карточек-виджетов с обходом стрелками

- **Дизайн:** Десять EvSettingSection с панелями и строками (words, dim), поиск по основе слова раскрывает разделы, липкая колонка 212 (settings_search.dart; screens/settings_page.dart:117-343)
- **Evaporate:** SettingsPage — Column из 12 карточек, каждая читает блок сама; _ListTraversal и стрелки без ignoreTextFields; settings_navigation_test требует все карточки в дереве и спуск до «Проверить обновления»; settings_layout_test фиксирует, что где лежит
- **Рекомендация:** Первый этап — колонка навигации с якорями над теми же карточками; поиск — вторым этапом, когда решено, откуда у карточек слова. Каталог данными перестраивает все 12 карточек и тесты разом — не в одном коммите с каркасом.

### Клавиши каркаса: свой FocusScope.onKeyEvent с цифрами и P против таблицы InputScope и NavAction

- **Дизайн:** EvShell ловит 1–6, Ctrl+K, «/» по физической клавише, Esc, P в своём FocusScope; строка подсказок и таблица клавиш в настройках — одна таблица evKeyBindings (ev_shell.dart:189-232; settings_data.dart:23-64)
- **Evaporate:** InputScope — таблица _shortcuts + NavAction для клавиатуры и геймпада разом, focusInTextField(), ButtonHints по binding.buttonsFor (input_scope.dart:279-317; button_hints.dart:22-36); лишний обработчик — второй источник правды
- **Рекомендация:** Расширять таблицу _shortcuts (цифры 1–4 с проверкой поля ввода; Ctrl+K и P — только с палитрой/Пультом); подсказки показывать только для клавиш, которые в таблице есть.

### Состояние оболочки: ChangeNotifier/ValueNotifier против Bloc

- **Дизайн:** EvShellController, EvEffects, EvAppearance — ChangeNotifier; вид библиотеки и состояния окна — ValueNotifier в EvaporateApp (main.dart:85-94)
- **Evaporate:** Решение 0001 и bloc_lint prefer_bloc: новое состояние — блок с событиями; NavigationBloc, SettingsBloc (SettingsPatched), LibraryViewBloc уже есть; TODO §5 запрещает возврат Cubit
- **Рекомендация:** Ничего из контроллеров дизайна не переносить; каждое новое состояние — событие существующего блока или новый блок.

### Окно: минимум 1280×720 и системный заголовок против 900×620 без рамки

- **Дизайн:** Windows-раннер с заголовком «Evaporate», DWM-цвета, минимум 1280×720 (README.md:636-644)
- **Evaporate:** Окно без системной рамки, WindowChrome рисует углы и полосы, клавиши окна и перетаскивание живут в верхней рейке (window_frame.dart:8-14; top_bar_actions.dart:37-61); минимум 900×620
- **Рекомендация:** Рамку evaporate оставить; новый топбар обязан нести WindowDragArea подложкой и TopBarActions (свернуть/развернуть/выход/тема); поле рейла/топбара от края окна > WindowChrome.edge (4).

### Часы украшений: свой тикер с 30 к/с на inactive против DecorationClock

- **Дизайн:** EvAtmosphere — Ticker + AppLifecycleListener + Timer 33 мс в неактивном окне; приборы загрузок — свой AnimationController с preserve (ev_atmosphere.dart; screens/downloads_page.dart:37-67)
- **Evaporate:** DecorationClock/DecorativeMotion с единым decorationMayRun; inactive считается видимым; AppLifecycleListener отвергнут (decoration_clock.dart:7-18; window_visibility.dart:25-29) — незакоммиченный B6
- **Рекомендация:** Все новые украшения и приборы — на DecorationClock/DecorativeMotion; политику inactive не менять без отдельного решения.

### Удержание «Играть» 620 мс против мгновенного главного действия и still при disableAnimations

- **Дизайн:** EvPlayButton держит заряд 620 мс с AnimationBehavior.preserve, чтобы «уменьшить движение» не ужимал защиту (ev_play_button.dart:72-80)
- **Evaporate:** primaryActionFor/dispatchPrimaryAction мгновенно из четырёх мест, включая кнопку X геймпада (shell.dart:28-37); context.motion при disableAnimations отдаёт нули (motion_test)
- **Рекомендация:** Удержание — вторым этапом, независимым флагом, и одновременно на геймпаде (иначе защита односторонняя); длительность защиты — не ступень motion, а константа с записью в _durations и объяснением.

### Стена: плотная сетка gap 11 против каймы искр 48

- **Дизайн:** evWallCells — minTile 146, зазор 11; README: в Стене эффекты только у активной плитки (ev_wall.dart:24-56; README.md:2119)
- **Evaporate:** PortalSparks кладёт слой на 48 px за плитку с Clip.none; просветы 28/32 в delegateFor подобраны под кайму (cover_frame.dart:35; library_grid.dart:87-93)
- **Рекомендация:** Если Стена появится — искры только у выбранной (уже так), но кайма налезет на соседей; либо halo параметром вида, либо в Стене портал выключен, как README и предлагает.

## Сохраняемые эффекты

### Искры по краю обложки (portal)

- **Где живёт:** CoverFrame → PortalSparks(enabled: selected && portalEnabled, child) снаружи DecoratedBox/ClipRRect/AspectRatio 2/3 (cover_frame.dart:35-62); поле PortalSparkField в PortalSparksState, reset при смене enabled и при disableAnimations (portal_sparks.dart:20-45); флаг из GameCoverTile: effects.shows(LibraryEffect.portal) (game_cover.dart:77); DecorativeMotion → Stack(Clip.none) → Positioned(-48) → CustomPaint 'portal-sparks' под child
- **Как выживает:** Плитка новой библиотеки строится той же цепочкой LibraryGridTile → FoilCard → GameCoverTile → CoverFrame → CoverFace; любая обёртка дизайна (тень, рамка, бейдж) ставится снаружи CoverFrame или внутри CoverFace, но не с Clip между PortalSparks и плиткой; пропорция 2/3 и просветы ≥ каймы 48 сохраняются; selected — только из NavigationBloc.selectedGameId
- **Зависит от:** NavigationBloc.selectedGameId, LibraryEffect.portal в shipped, DecorativeMotion/decorationMayRun, EffectsPalette.sparkBlend (plus/srcOver), AppColors.portalSpark/portalRim, test/goldens/portal_sparks_reference.png (over == 0), delegateFor spacing 28/32

### Блики и фольга — переливы (foil)

- **Где живёт:** FoilCard(foilEnabled: isOn(foil)) на DecorationClock → FoilScope(FoilMotion) → FoilSurface foregroundPainter в CoverFace вокруг CoverDrops, под CoverProgressStrip/CoverStatusBadge (foil_card.dart:14-44; cover_face.dart:59-67); wantsFrames только у active или возвращающейся
- **Как выживает:** active = hovered ?? selected остаётся решением LibraryGridTile._lookNow (library_grid_tile.dart:58-64) — новый облик карточки не заводит своего hover-состояния поверх; sheen дизайна не переносится (второй блик на той же обложке); CoverFace сохраняет порядок FoilSurface → CoverDrops → CoverArt
- **Зависит от:** LibraryGridController.hoveredId и MouseRegion плитки, DecorationClock (B6, незакоммичен), libraryInkColors, AppColors.foilHighlight, theme_structure _curves foil_motion: 1, _alphas foil_surface: 2, library_effects_test (builds == 1, одна анимирующая FoilCardState)

### Наклон карточки (cardTilt)

- **Где живёт:** FoilCard(tiltEnabled: isOn(cardTilt)) → Transform(key 'foil-perspective', FoilMotion.perspective: entry(3,2)=0.0015, rotateX/Y по фазе) вокруг GameCoverTile (foil_card.dart:14-37); снаружи — KeyedSubtree(tileKey) и AnimatedContainer подъёма −7
- **Как выживает:** Порядок «подъём снаружи, наклон внутри, ключ плитки между ними» не меняется; параллакс героя дизайна — отдельное украшение крупного кадра, а не второй Transform на плитке; MouseRegion остаётся снаружи сдвига (как и в дизайне — ev_game_card.dart:60-61)
- **Зависит от:** KeyedSubtree(controller.tileKey) выше FoilCard, LibraryEffect.cardTilt в shipped, DecorationClock, library_grid_test (подъём читается из AnimatedContainer.transform)

### Жидкое искажение обложки (liquidDistortion)

- **Где живёт:** Та же FoilCard(distortionEnabled: isOn(liquidDistortion)) — матрица сжатия/сдвига в FoilMotion (foil_card.dart:21, 39-41); выключено по умолчанию (не в shipped)
- **Как выживает:** Едет вместе с FoilCard без правок; переключатель effects-liquidDistortion-toggle остаётся
- **Зависит от:** FoilCard, effect_settings_test (искажение отдельно от наклона/фольги)

### Шейдер капель воды (drops, assets/shaders/drops.frag)

- **Где живёт:** CoverFace → FoilSurface → CoverDrops(enabled: selected && dropsEnabled, coverPath: game.details.coverPath) → CoverArt (cover_face.dart:59-67); FragmentProgram один на приложение, useProgram подменяется в тестах (cover_drops.dart:37-47); dropsEnabled = shows(LibraryEffect.drops); без coverPath капель нет
- **Как выживает:** Обложка остаётся файлом с диска (не процедурный EvCover) — шейдеру нужна текстура; CoverDrops сам рисует обложку, поэтому кромка/sheen дизайна кладутся выше CoverDrops в Stack CoverFace, иначе капли их сотрут; пропорция плитки 2/3 = BoxFit.cover в шейдере
- **Зависит от:** game.details.coverPath (CoverCache), DecorativeMotion (iTime), pubspec shaders: assets/shaders/drops.frag, cover_drops_test (отказы шейдера/обложки), thinFiles cover_drops: 44 (не тоньше), NavigationBloc.selectedGameId

### Жидкая подложка выбора (liquidSelection)

- **Где живёт:** Три места: LibraryGrid 'grid-liquid' — targetKey controller.targetKey(selectedId) = _tileKeys[hovered ?? selected], radiusPanel, padding gap (library_grid.dart:46-52); NavigationRack 'rail-liquid' — targets[section], radiusChip (navigation_rack.dart:60-67); ShelfTabs 'shelf-liquid' — _targets[shelf], radiusControl (shelf_tabs.dart:42-49); LiquidSelectionInk в NavigationKey и ShelfButton перекрашивает подписи под каплей; _sync = enabled && decorationMayRun (liquid_selection.dart:76-80)
- **Как выживает:** В вертикальном рейле LiquidSelection ставится над колонкой NavigationKey с теми же GlobalKey на раздел — EvDroplet и EvRail.dropletRect не переносятся; сетка сохраняет KeyedSubtree(tileKey); во вкладках полок — как есть; SegmentedButton настроек каплю не получает. Материал капли (стекло) — полем темы в LiquidPainter, геометрия не меняется
- **Зависит от:** GlobalKey на раздел/плитку/полку, KeyedSubtree(tileKey) в LibraryGridTile, colors.selection и palette.onSelection, decorationMayRun, liquid_selection_test (три подложки, ink, NaN), LibraryEffect.liquidSelection (вне shipped — включить по умолчанию только с правкой effect_settings_test)

### Рамка выбора (selectionFrame, независимый флаг)

- **Где живёт:** NavTile.showFocusBorder = isOn(selectionFrame) — рамка 2.5 colors.selection и AnimatedScale 1.06 по фокусу, мимо общего выключателя (nav_tile.dart:34-92; game_cover.dart:69)
- **Как выживает:** NavTile остаётся оправой плитки; правило EvFocusable «только при клавиатурной навигации» добавляется в него, а не вторым виджетом
- **Зависит от:** LibraryEffect.selectionFrame independent, effect_settings_test:284-339

### Свет выбранной игры в корпусе (ambient)

- **Где живёт:** AppShell → AmbientLight(enabled: shows(ambient), title выбранной игры) вокруг ShellLayout (shell.dart:43-53, 84-88); цвета gameAmbientColors(title), сила HardwareSurfaceTheme.ambientStrength
- **Как выживает:** Остаётся под новым каркасом: панель и полосы стекла — неплотные (shellOpacity/GlassSurfaceTheme), иначе единственный цвет в окне гаснет; плюм дизайна — если брать — в тех же цветах игры
- **Зависит от:** NavigationBloc.selectedGameId + LibraryBloc.gameById, HardwareSurfaceTheme.ambientStrength/vignetteOpacity (arclight/cartridge)

### Частицы и перламутр библиотеки (particles/ambient wash)

- **Где живёт:** LibraryBody → LibraryAtmosphere(enabled: libraryEffects, particles: isOn, ambient: isOn, targetKey: grid.targetKey(selectedId)) вокруг заголовка/кадра/тулбара/сетки (library_body.dart:67-91); DecorationClock, field.card = rect плитки цели
- **Как выживает:** Новая раскладка библиотеки оборачивается LibraryAtmosphere на том же уровне (над сеткой и героем), targetKey — тот же контроллер
- **Зависит от:** LibraryGridController.targetKey, DecorationClock, EffectsPalette.particle/ambientWash, _longClosures library_atmosphere: 40

### Волна под разделами (waves)

- **Где живёт:** ShellPanel → GameWave(key 'library-wave', enabled: section == library && shows(waves)) вокруг FocusTraversalGroup(ShellSections) (shell_panel.dart:40-44)
- **Как выживает:** При замене ShellPanel стеклом дизайна GameWave переезжает вместе с условием section == library и ключом
- **Зависит от:** NavigationBloc.section, library_effects_test:467 ('library-wave'), _longClosures game_wave: 43

### Пробег света и кадры под крупным кадром (heroSweep, shotsBackdrop)

- **Где живёт:** FeaturedArt → HeroSweep → ShotsBackdrop(shots: shotPaths, fallback обложка/задник) + затемнения (featured_art.dart:37-73); флаги shows(heroSweep)/shows(shotsBackdrop) в LibraryFeaturedSlot
- **Как выживает:** Герой дизайна берёт FeaturedArt как кадр — процедурный EvHeroArtPainter не переносится; параллакс, если брать, — новый LibraryEffect поверх ShotsBackdrop на тех же часах
- **Зависит от:** game.details.shotPaths (GameMetadataFetcher.maxShots), DecorativeMotion, shots_backdrop_test, _curves hero_sweep/shots_slideshow

### Размытая обложка фоном страницы игры (coverBackdrop)

- **Где живёт:** GamePage → Positioned.fill CoverBackdrop(enabled: isOn(coverBackdrop)) под BackToLibraryButton и GameDetail (game_page.dart:20-29)
- **Как выживает:** Страница остаётся страницей (не модалка) — CoverBackdrop лежит под всей страницей и под липкой полосой действий; _SheetArt дизайна с параллаксом — не вместо, а поверх как шапка
- **Зависит от:** openedGameId в NavigationBloc, cover_backdrop_test (яркость строк 0.05/0.45/0.85), HardwareSurfaceTheme.scrimOpacity

## Заметки

- Рабочее дерево не чистое: B6 (DecorationClock: новый lib/ui/widgets/decoration_clock.dart, правки foil_card, library_atmosphere, decorative_motion, liquid_selection, window_visibility, CLAUDE.md, TODO.md) не закоммичен. План обновления интерфейса ложится поверх — первым шагом довести B6 до зелёных ворот и коммита, иначе конфликт в тех же файлах эффектов.
- Согласование с TODO.md Этап B (открыты B7–B15): B12 (Concept → убрать, файл = класс, словарь плитка/полка/сетка/обойма/рейка/плашка) делать в одном заходе с каркасом — переименования NavigationRack/ConceptTopBar/ConceptNavigation всё равно неизбежны и требуют правки CLAUDE.md (docs_names_test); B13 (LibraryPage: побочные действия build → BlocListener) — вместе с правкой страницы игры; B14/B15 (select по части, SettingRow, patchSettings) — вместе с колонкой настроек; B7–B9 трогают ровно файлы сохраняемых эффектов — их не открывать дважды; B10/B11 (роли текста, доступ к теме) — до переноса типографики героя.
- Что не предлагать (TODO §5 и docs/decisions): Cubit/ChangeNotifier для нового состояния (0001), freezed (0005), уход с part, понижение порогов 15/60/3 и 25/40/7, integration_test и снимки экрана как стражи, переписывание темы (0002 — ярусы и ThemeExtension остаются), блок окна (0004), подпись обновлений (0008).
- Данные, которых у evaporate нет, и что с ними в интерфейсе: сессии по дням/«последняя сессия N мин» (только PlayStats.playtime/lastPlayed — блок «история» не показывать, пока нет журнала сеансов), достижения и друзья (нет источника — блоки и раздел не заводить, не заглушка), версия/жанр игры (нет в Game — столбцы Терминала и чипы героя заменить на статус/размер/наиграно), «где остановился» (только SaveSnapshot.note — показывать note или ничего), облако с квотой/устройства онлайн/конфликт (папка синхронизации без предела; устройства — из deviceName снимков и пакетов с датой последнего снимка; конфликт — существующий ImportNewerDialog/RestorePreviewBloc), части раздачи и тепловая карта пиров (движок отдаёт completed/total, connections/seeders — двухдольное кольцо, карту не рисовать), «есть обновление»/«офлайн» у героя (нет состояния — не показывать; ProxyRouting.blocked — единственный «офлайн»).
- Что требует issue до правки (CLAUDE.md «Что обсуждать до правки»): палитра команд (новый экран), режимы Стена/Терминал (новый вид библиотеки), Пульт (новый экран под геймпад), звук (flutter_soloud — нативная зависимость), flutter_svg (зависимость), удержание «Играть» (меняет поведение главного действия на геймпаде), третья схема/облики Magma/Nebula/Cryo (тема — не эта линза).
- Предлагаемая этапность по этой линзе: (1) каркас — рейл 76/топбар 58/строка 32 на EvaporateLayout, WindowDragArea и клавиши окна в топбаре, LiquidSelection в вертикальном рейле, FadeIndexedStack с переходом дизайна, B12; (2) библиотека — раскладка тела героя в FeaturedPoster при высоте 238, облик бейджа/полосы плитки через тему, Shelf.recent, пустая полка с тремя входами; (3) страница игры — липкая полоса действий и две колонки, B13; (4) загрузки и сохранения — приборы сверху на ReadoutPanel/DownloadChart, TaskCard в раскладке EvTorrentRow, лента снимков на нити при SliverList; (5) настройки — колонка навигации с якорями, B14/B15; (6) новое по issue — палитра, режимы, удержание, плюм.
- Стражи, которые новая структура заденет чаще всего: section_layout_test (первый ряд обложек в 1280×900, имя раздела один раз, «ОСТАНОВЛЕН», нет копирайта), widget_structure (один публичный виджет на файл — ev_surfaces 9, ev_controls 6, ev_rail 4, ev_palette 3; приватные >40 строк _SideTooltip/_PageTransition/_SheetBar; _longClosures навигации/страниц), theme_structure (все числа дизайна — fontSize, Duration, Curves, BorderRadius.circular, alpha, SizedBox числом — только токенами), localization/arb_usage (каждая подпись дизайна — пара ключей ru+en, удалённые виджеты уносят ключи), coverage (_reportedNowhere/thinFiles — каждый новый файл с тестом), bloc_lint/bloc_members_test.
- Ключи виджетов и тексты, которые тесты ищут и которые план обязан сохранить или переписать вместе с тестами: 'concept-navigation', 'rail-liquid', 'grid-liquid', 'shelf-liquid', 'rail-quit', 'rail-minimize', 'rail-maximize', 'window-drag-region', 'window-clip', 'window-resize-*', 'library-wave', 'library-scale', 'portal-sparks', 'cover-drops', 'foil-perspective', 'library-atmosphere-paint', 'featured-game-background(-fallback)', 'effects-<name>-toggle', 'effects-preset', 'effects-details', 'living-library-settings', 'interface-scale'; тексты: метки «[ 01 / КОЛЛЕКЦИЯ ]»…«[ 04 / ПАРАМЕТРЫ ]», заглавные имена разделов один раз, «ОСТАНОВЛЕН», tooltip'ы окна и темы.
- Минимальный размер окна 900×620 и рамка без системного заголовка остаются: EvBottomNav (<760) недостижим, а рейл/топбар обязаны отступать от края окна больше WindowChrome.edge (4) — window_frame_test держит edge < compactInset ≤ wideInset.

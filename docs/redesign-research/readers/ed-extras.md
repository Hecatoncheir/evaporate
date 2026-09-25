# Конспект читателя: ed-extras

## Сводка

В evaporate_design шесть кусков, которых в evaporate нет: первый запуск (пустая библиотека, скелет, диалог «Добавить раздачу», полоса сценария из восьми шагов), второй запуск (седьмое состояние героя `returned`, дайджест «Пока вас не было», точка сохранения под кнопкой), «Друзья» с профилем друга, свой «Профиль», оверлей в игре и звук на девяти синтезированных голосах через `flutter_soloud`. Собрано это как витрина без движка: состояния окна лежат `ValueNotifier`-ами в `EvaporateApp` и переключаются из «Настройки → Разработка», данные — `sample_*.dart` с процедурными обложками, сценарии — `ChangeNotifier`-контроллеры, чья полоса рисуется над навигатором, оверлей и диалог — `PopupRoute` внутри того же окна. Вердикты по кускам (обоснования в фактах): ПЕРВЫЙ ЗАПУСК — взять урезанно: пустую библиотеку как точку входа с тремя дорогами (скан, magnet, бросить файл) на существующие `AddGameDialog`/`ScanSession`/`GameDropTarget`; шаги 3–8 — это состояния настоящих задач загрузки, которые evaporate уже показывает, скелет и полосу сценария не брать (загрузка `library.json` мгновенна, фейковых состояний нет); диалог «Добавить раздачу» с частями — только если движок умеет выбирать файлы раздачи. ВТОРОЙ ЗАПУСК — взять урезанно: «вы остановились N назад» и карточку последнего снимка из `PlayStats.lastPlayed` и `SaveSnapshot` данные уже есть; дайджест отложить до появления персистентного журнала событий с отметкой «просмотрено» — сейчас уведомления одноразовые и на диск не ложатся, считать «пока вас не было» не от чего. ДРУЗЬЯ и ПРОФИЛЬ ДРУГА — не брать: без аккаунтов, presence и узнавания друзей среди пиров у экрана нет ни одного настоящего числа; переиспользуемого — только аватар с инициалами. ПРОФИЛЬ — взять урезанно как «Статистика» (часы по играм, установленные, устройства из `deviceName` снимков; карта года — после журнала сеансов; рейтинг раздачи — если движок отдаёт накопленную отдачу); достижения, код друга и тумблеры приватности не брать. ОВЕРЛЕЙ — не брать как оверлей (это страница в окне лаунчера, а fps/GPU/CPU/глава требуют хука в процесс игры, которого во Flutter нет); взять урезанно как состояние «игра идёт» на странице игры: таймер `elapsed`, «Завершить» через `GameLauncher.terminate`, «Фоном» с новым пределом скорости в игре по `RunningGamesChanged`. ЗВУК — отложить: нативная зависимость с C++-сборкой на трёх CI, слой `EvSound` — `ChangeNotifier` против правила «новое состояние — блок», настройки звука — четвёртая часть `AppSettings`, а два из девяти голосов (удержание, ритуал) привязаны к ритуалу запуска; если брать — вторым этапом, после ритуала, с фейком `EvSilentOut` в тестах и «звук не громче картинки» через флаги `LibraryEffect`.

## Файлы

- `evaporate_design/lib/main.dart` — витрина: состояния окна ValueNotifier-ами, оба сценария, звук, плашки верхней полосы, маршрутизация разделов
- `evaporate_design/lib/first_run/first_run_data.dart` — EvCatalog, восемь шагов EvFirstRunStep, EvFirstRun с синтезированной раздачей по фазам
- `evaporate_design/lib/first_run/first_run_controller.dart` — контроллер первого запуска: шаг, каталог, таймер чтения 300 мс
- `evaporate_design/lib/first_run/scenario.dart` — EvScenario (общее у сценариев) и EvReturnController на четыре шага
- `evaporate_design/lib/first_run/ev_first_run_widgets.dart` — EvLibraryEmpty (знак, два входа, зона броска), EvLibrarySkeleton, EvFlowBar
- `evaporate_design/lib/first_run/ev_add_torrent.dart` — диалог «Добавить раздачу» маршрутом: части, сумма, остаток на диске, btih
- `evaporate_design/lib/returning/return_data.dart` — EvSaveSpot, EvDigestState, EvDigestEvent, пять событий ночи
- `evaporate_design/lib/returning/ev_return_widgets.dart` — EvSavePointCard, EvDigest, EvDigestSlot с испарением через burstFrom
- `evaporate_design/lib/library/hero_state.dart` — EvHeroState с седьмым состоянием returned
- `evaporate_design/lib/atmosphere/ev_atmosphere.dart` — общий слой атмосферы; burstFrom — срыв 90 искр с прямоугольника
- `evaporate_design/lib/friends/friends_data.dart` — EvPerson, EvTraffic, EvSeeder, EvFeedEntry, EvInvite, EvFriends
- `evaporate_design/lib/friends/ev_avatar.dart` — EvFriendAvatar — инициалы на градиенте с точкой статуса
- `evaporate_design/lib/friends/ev_friend_rows.dart` — карточка «сейчас в игре», строка раздающего, строка друга, заявка, EvStackBar
- `evaporate_design/lib/screens/friends_page.dart` — раздел «Друзья»: от друзей сейчас, заявка, общая библиотека, в игре, раздают, все, лента
- `evaporate_design/lib/profile/profile_data.dart` — EvPlayYear 52×7, EvShare, EvEarned, EvProfile с выводимыми полями
- `evaporate_design/lib/profile/friend_profile_data.dart` — EvFriendProfile: shows, скрытое показано скрытым
- `evaporate_design/lib/profile/ev_profile_head.dart` — шапка профиля, EvProfileAvatar, EvStat/EvStatTiles
- `evaporate_design/lib/profile/ev_play_year.dart` — тепловая карта года и легенда
- `evaporate_design/lib/screens/profile_page.dart` — своя страница: плашки, год, часы по играм, отдача, достижения, приватность, код
- `evaporate_design/lib/screens/friend_profile_page.dart` — чужая страница: раздал вам, общие игры полосами, что скрыто
- `evaporate_design/lib/overlay/overlay_data.dart` — EvSession (pid, fps, VRAM, GPU °C, CPU, глава), EvFrameSeries
- `evaporate_design/lib/overlay/ev_overlay.dart` — showEvOverlay PopupRoute в окне: приборы, быстрые действия, друзья, «Фоном»
- `evaporate_design/lib/sound/ev_sound.dart` — EvSound слой (ChangeNotifier), EvAudioOut, EvSilentOut, EvSoundScope
- `evaporate_design/lib/sound/voices.dart` — EvSoundClass, девять голосов слоями, щелчок, отдушина
- `evaporate_design/lib/sound/synth.dart` — чистый Dart-синтез: слои, биквады, огибающие, evRender, evWav
- `evaporate_design/lib/sound/soloud_out.dart` — EvSoLoudOut: flutter_soloud, компрессор шины, рендер в compute
- `evaporate_design/lib/sound/cues.dart` — голоса событий движка: heroCue, downloadsCue, savesCue
- `evaporate_design/lib/settings/settings_data.dart` — EvSettings, в т.ч. inGameDownloadMb/inGameUploadMb
- `evaporate_design/lib/design/effects.dart` — EvEffects и пресеты Эко/Полное/Макс
- `evaporate_design/design/README.md` — спецификация: разделы 218–300, 364–563, 1707–1905, 1983–2092
- `evaporate_design/design/evaporate-brand.html` — айдентика: раздел 06 «Лаборатория эффектов» (12 приёмов), 07 «Девять голосов»
- `evaporate_design/todo.md` — перечень перенесённого и открытые вопросы витрины
- `evaporate_design/test/final_check_test.dart` — прогон разделов, видов, «Пульта», оверлея на трёх размерах окна; звук фейком
- `lib/ui/library/library_empty_state.dart` — нынешняя пустая полка evaporate: различает «пусто» и «поиск не нашёл»
- `lib/bloc/add_game/add_game_event.dart` — события добавления игры: magnet, торрент, папка, «начать сразу»
- `lib/services/launch/game_launcher.dart` — RunningGame (pid, startedAt, elapsed), runningIds, terminate
- `lib/bloc/library/library_bloc.dart` — _onGameExited прибавляет playtime; RunningGamesChanged
- `lib/models/play_stats.dart` — playtime и lastPlayed игры — единственная история игры
- `lib/models/save_snapshot.dart` — createdAt, deviceName, platform, sizeBytes, playtime снимка
- `lib/services/notifications/notification_service.dart` — NotificationKind и одноразовый show() — без журнала
- `lib/models/app_section.dart` — четыре раздела обоймы
- `lib/models/library_effect.dart` — четырнадцать украшений evaporate, включая foil/cardTilt/drops/portal/liquidSelection
- `lib/ui/library/effects/portal/portal_sparks.dart` — искры по краю плитки; поле искр живёт в состоянии плитки
- `lib/ui/library/detail/running_game_actions.dart` — нынешний вид «игра идёт»: клавиша остановки и подпись

## facts

- Витрина держит состояния окна ValueNotifier-ами (герой, очередь, облако, друзья, тумблеры, вид) — evaporate_design/lib/main.dart:85-94; переключает их «Настройки → Разработка» (lib/screens/settings_page.dart:30-32, main.dart:791-819). Движка нет.
- Идущий сценарий (EvScenario, lib/first_run/scenario.dart:102-117) рисуется полосой EvFlowBar над всеми маршрутами через MaterialApp.builder (main.dart:326-333, 831-873); ←/→ листают, Ctrl+V/Ctrl+O из пустой библиотеки ведут в добавление (main.dart:219-241).
- Звук заводится в EvaporateApp как EvSound(out: EvSoLoudOut()), фокус окна — AppLifecycleListener, смена раздела звучит swish (main.dart:97-113).
- Обложки везде процедурные EvCover(palette, seed) (lib/profile/ev_profile_rows.dart:50, lib/returning/ev_return_widgets.dart:45), кэшируются растрами (lib/art/ev_art.dart:72-94); тема одна, тёмная (main.dart:319-321).
- Первый запуск — восемь шагов EvFirstRunStep; empty — шаги до verifying, downloads — queued/downloading/verifying (lib/first_run/first_run_data.dart:204-242).
- Раздача шагов 3–5 синтезируется из констант _rates/_done (218/1420/1100 КБ/с, 0,4/41/88 %), время до конца считается из остатка и скорости (first_run_data.dart:273-332) — данных движка нет.
- «Чтение каталога» — таймер 300 мс EvCatalog.readTime (first_run_data.dart:200, first_run_controller.dart:16-18, 54-56) со скелетом EvLibrarySkeleton и своим AnimationController (ev_first_run_widgets.dart:271-378).
- EvLibraryEmpty: дышащий знак _GlowingMark (StatefulWidget с контроллером 4200 мс, ev_first_run_widgets.dart:122-202), «Просканировать диск» (EvPlayButton без удержания), «Вставить magnet-ссылку», _DropZone только нажимаемая — бросить нельзя (design/README.md:1729), подсказки Ctrl+O/Ctrl+V/"/" (ev_first_run_widgets.dart:17-119).
- Все три входа пустой библиотеки ведут в один onAdd, а «пусто» и «поиск ничего не нашёл» витрина не различает (lib/screens/library_page.dart:100-110).
- Диалог «Добавить раздачу» отдаётся Route<double> (сколько ГБ выбрано), части — EvGameFacts.parts, сумма и остаток на диске пересчитываются с галочкой, обязательная часть не снимается (lib/first_run/ev_add_torrent.dart:21-30, 84-116; README.md:237-240).
- evaporate уже имеет пустую полку — иконка, заголовок и одна клавиша «Добавить игру» → showAddGameDialog, различает пустую библиотеку и пустой поиск (lib/ui/library/library_empty_state.dart:9-11, 18-20, 38-55).
- Добавление игры в evaporate знает magnet, торрент, папку и «начать сразу» (lib/bloc/add_game/add_game_event.dart:11-71), ищет исполняемые ExecutableFinder.scan (add_game_bloc.dart:146); сканирование — scan_folder_dialog.dart и lib/bloc/scan; перетаскивание уже работает через GameDropTarget.
- Второй запуск — седьмое состояние героя returned (lib/library/hero_state.dart:29-31); EvDigestState open/folded существует только в нём (lib/returning/return_data.dart:36-38; main.dart:131-137, 256-261).
- EvDigestEvent — tone/icon/title/detail/не больше одного action/target/game; пять событий: загрузка ночью, обновление установлено, друг прошёл главу, 2 сохранения выгружены, раздача впустую (return_data.dart:49-72, 93-143).
- Действие, уводящее на другой экран, сворачивает дайджест; открывающее карточку — нет (main.dart:524-538); свёрнутый живёт плашкой «Пока вас не было · N» в верхней полосе (main.dart:558-570).
- EvDigestSlot при закрытии зовёт EvAtmosphere.burstFrom(context, rect) — 90 искр с прямоугольника панели, отказ без искр и при reduced motion (lib/atmosphere/ev_atmosphere.dart:78-86) — и только тогда играет EvVoice.evaporate (ev_return_widgets.dart:302-319).
- EvSavePointCard: миниатюра, «Сохранение 02:14 · Глава 5…», «41 минуту назад · выгружено · 148 МБ», «Другое» → раздел «Сохранения» (ev_return_widgets.dart:18-81; main.dart:749); стоит под кнопкой героя (lib/library/ev_hero.dart:329-336).
- В узком окне дайджест плавает Positioned поверх полок, в широком — первым в правой колонке (library_page.dart:221-235, 323).
- evaporate для «где остановился» имеет PlayStats.playtime/lastPlayed (lib/models/play_stats.dart:9-12) и у снимка createdAt, deviceName, platform, sizeBytes, playtime (lib/models/save_snapshot.dart:31-53); «глава/место» узнать неоткуда.
- Источники событий в evaporate одноразовые: NotificationKind downloadFinished/downloadFailed/saveFailed/updateAvailable (lib/services/notifications/notification_service.dart:3-15) шлются show() из downloads_bloc.dart:490,595,624, saves_bloc.dart:560, update_announcer.dart:31 и на диск не ложатся; grep lastRun|lastSeen|previousVersion по lib пуст — «пока вас не было» считать не от чего.
- EvPerson: статус playing/online/offline, общие игры, EvTraffic в обе стороны, род для «раздала/её/ей» строками (lib/friends/friends_data.dart:32-105, 63-75); EvSeeder — друг, раздающий тебе одну из твоих загрузок, rateKb/ofKb (friends_data.dart:124-146); лента, заявка, общая библиотека, EvFriends (friends_data.dart:150-266).
- Экран «Друзья» построен на «социальный граф = рой»: первое число — скорость от друзей (lib/screens/friends_page.dart:12-16; README.md:370-374). Нужны аккаунты/код друга, presence, узнавание друзей среди пиров, обмен библиотеками — у evaporate нет ни одного: движок без аккаунтов, в pubspec.yaml:19-67 сетевого бэкенда нет.
- EvFriendProfile.shows (Set<EvShare>) и hidden — скрытое показано скрытым (lib/profile/friend_profile_data.dart:31-95; README.md:548-557); всё выдумано samplePeople (lib/data/sample_friends.dart:32).
- EvFriendAvatar — инициалы на градиенте с точкой статуса (lib/friends/ev_avatar.dart:11-86) — единственный виджет раздела, не требующий данных о друзьях.
- EvPlayYear — 52×7 уровней по дням, дни/часы/серия считаются из сетки (lib/profile/profile_data.dart:16-86); EvProfile — код, hoursBefore, отдано/получено ГБ, устройства here+away, достижения; выводимое: top(count) по played, installed, ratio, uploadShare, gaveMost (profile_data.dart:129-214).
- Четыре тумблера EvShare — только про друзей (profile_data.dart:90-103); копирование кода друга в буфер (lib/screens/profile_page.dart:177-215).
- У evaporate есть накопленный playtime на игру, но нет дневной истории: _onGameExited прибавляет к сумме и ставит lastPlayed (lib/bloc/library/library_bloc.dart:495-514) — карта года требует нового журнала сеансов; устройства можно вывести из SaveSnapshot.deviceName/platform; достижений нет.
- Разделов у evaporate четыре (lib/models/app_section.dart:8-12), у витрины шесть, профиль — по аватару в рейле, клавиши 1–6 (lib/shell/ev_section.dart:7-24).
- showEvOverlay — PopupRoute внутри окна лаунчера с FadeTransition 280 мс, а не слой поверх игры (lib/overlay/ev_overlay.dart:32-93); закрывают Esc, Shift+Tab, «Вернуться в игру» (ev_overlay.dart:172-180, 802-847), «Завершить игру» → onQuit.
- EvSession: pid, fps/lowFps, vramGb, gpuC, cpu, глава/место, достижение сессии (lib/overlay/overlay_data.dart:14-52); EvFrameSeries — случайное блуждание fps шагом 900 мс (overlay_data.dart:80-107, ev_overlay.dart:125-157).
- Быстрые действия F12/F10/F9/F5 и «Настройки игры» ничего не делают (ev_overlay.dart:541-547, 826-831); «Фоном» — раздача с пределом EvSettings.inGameDownloadMb/UploadMb = 1 МБ/с через queue.capped (lib/settings/settings_data.dart:125-129; main.dart:495-502; ev_overlay.dart:722-800).
- evaporate о запущенной игре знает gameId/startedAt/process и elapsed (lib/services/launch/game_launcher.dart:20-31, 59-62), runningIds в LibraryState (library_bloc.dart:545-550), умеет terminate (game_launcher.dart:174-190); показывает клавишу остановки и подпись (lib/ui/library/detail/running_game_actions.dart:7-40); предела скорости «в игре» нет (grep inGame|whilePlaying по моделям пуст).
- EvSound — ChangeNotifier: выключен по умолчанию, три ступени громкости, классы отдельно, касание не чаще 60 мс, отдушина только в фокусе; EvAudioOut с EvSilentOut для тестов (lib/sound/ev_sound.dart:42-51, 64-110, 123-214).
- Три класса с пределами 120/400/2600 мс и девять голосов слоями (lib/sound/voices.dart:375-387, 394-489); синтез чистый Dart — биквады, evRender, evWav (lib/sound/synth.dart:130, 182, 233); но voices.dart:365-370 импортирует design/tokens.dart, launch/ritual_timeline.dart и art/key_art.dart — удержание и ритуал считаются от EvMotion.hold и EvRitualTiming.
- EvSoLoudOut: flutter_soloud ^5.1.2 (pubspec.yaml:39), init bufferSize 1024, компрессор −18 дБ 4:1 4/180 мс, рендер голосов в compute, loadMem WAV, не завёлся — тишина (lib/sound/soloud_out.dart:258-300); движок собирается из C++ на сборке (README.md:2036-2039).
- Голоса событий движка: noSpace → err; noSeeds/hash/offline и conflict/noCloud → warn; звучит смена, не повтор (lib/sound/cues.dart:18-36; main.dart:250-254). В UI: tap у всего нажимаемого (lib/widgets/ev_focusable.dart:54), hold у кнопки «Играть» (ev_play_button.dart:158-165), ritual/ok при запуске (lib/launch/ev_launch_ritual.dart:40).
- В evaporate аудио нет вовсе: grep sound|audio|soloud по lib и pubspec.yaml пуст.
- final_check_test.dart гоняет разделы 1–6, три вида, «Пульт» и оверлей на 1280×720, 1440×900, 1900×1100 без ошибок раскладки, звук — фейком _Out (test/final_check_test.dart:15, 23-43, 75-111); тестов у переносимых кусков: first_run 371, return 341, overlay 323, sound 439, friends 315, friend_profile 402, profile 355 строк; todo.md:37-41 — перенесено всё, «Разработка» остаётся; todo.md:67-75 — открыты направление ириса и разделитель дробей.
- Бренд: 12 приёмов — плюм-шейдер, угли, дым, параллакс, марево только на заряде, ореол тремя тенями, SSS, наклон до 11°/перспектива 700 со спекулярной полосой, круг заряда, волна+ирис, аберрация только на вспышке, зерно 128 px/5 % (design/evaporate-brand.html:563-607); пресеты Эко/Полное/Макс — плотность 0,5/1/1,6, размытие стекла, линза не на Эко (lib/design/effects.dart:7-38). Девять голосов с правилами «выключен по умолчанию», «не громче картинки», 200 Гц–4 кГц, 120/400/2600 мс, пассивные молчат, компрессор (brand.html:612-635, VOICES js:1019-1038; swish 190 и evaporate 420 мс в порте ужаты до 120/400 — README.md:2020-2023).
- С LibraryEffect evaporate (lib/models/library_effect.dart:12-72) пересекаются лишь наклон (cardTilt), искры (portal — по краю плитки, поле в состоянии плитки, portal_sparks.dart:21-26, аналога burstFrom нет) и полоса блика (foil/heroSweep); капли, жидкая подложка, shotsBackdrop, coverBackdrop, selectionFrame — только у evaporate, пресеты наборов уже есть (lib/models/effect_preset.dart:4-29).

## constraints

- Новый раздел (Профиль/Статистика), новый экран «игра идёт» и новая зависимость flutter_soloud — сначала issue и запись в docs/decisions/ (CLAUDE.md «Что обсуждать до правки»); прецедент отказа от нативного кода ради одного пакета — super_drag_and_drop.
- Новые разделы правят AppSection (lib/models/app_section.dart:8-12) и нумерацию меток SectionHeading — section_layout_test сторожит порядок; NavAction/геймпад листают обойму по кругу через AppSection.shifted.
- Состояние — блок с событиями, prefer_bloc в bloc lint: EvSound, EvFirstRunController, EvReturnController и ValueNotifier-ы витрины (main.dart:85-94) в evaporate не переезжают как есть; звук без состояния — Provider-сервис по образцу NotificationService, с состоянием — блок.
- layering_test: сервисы не импортируют ui; синтез голосов при переносе ложится в lib/services/sound без design/tokens.dart, launch/ritual_timeline.dart и art/key_art.dart (voices.dart:365-370).
- localization_test: все строки витрины — русские литералы в виджетах (ev_first_run_widgets.dart:51-65, ev_return_widgets.dart:135, ev_overlay.dart:544-547) — уходят в app_ru.arb/app_en.arb; каждый ключ обязан читаться переводами (arb_usage_test).
- theme_structure_test: у витрины fontSize:, Duration(milliseconds:), BorderRadius.circular(число), Curves.* и copyWith(height/letterSpacing) по месту (ev_first_run_widgets.dart:33-34, 133, 236, 282; ev_return_widgets.dart:44, 241, 325; ev_overlay.dart:74, 125) — переносится через context.text.*, context.motion, EvaporateTheme.radius*, EvaporateSpacing, EvaporateAlpha.
- Две схемы, данными, а не isDark: витрина только тёмная (main.dart:319-321) — каждый новый цвет проходит theme_test по контрасту на подложках Картриджа.
- widget_structure_test: один публичный виджет на файл, приватный ≤40 строк и без State с ресурсами — _GlowingMark, _DropZone, _DigestRow, _QuickButton получают свои файлы; lonelyShared — в lib/ui/widgets только нужное двум местам.
- Анимации — через DecorativeMotion/DecorationClock и decorationMayRun, а не свои AnimationController.repeat() с disableAnimationsOf (ev_first_run_widgets.dart:137-144, 287-295; ev_overlay.dart:137-146).
- complexity_test: ≤15 сложности, ≤60 строк, вложенность ≤3 — _statePills (main.dart:598-643) и EvFirstRun.torrent (first_run_data.dart:289-332) в таком виде не пройдут.
- Настройки звука — четвёртая часть AppSettings (как appearance/startup/saves) с плоскими ключами; model_roundtrip_test держит запись и чтение.
- Покрытие: новые файлы без тестов валят прогон (_reportedNowhere, thinFiles); порог 82 % на lib/core+models+services; фейк звука по образцу EvSilentOut/_Out (final_check_test.dart:23-43).
- Правило витрины «звук не громче картинки» (README.md:422-424): голос звучит только при включённом украшении — привязка к флагам LibraryEffect, а не отдельный список.
- Уведомления: SnackBar — за нажатое, системное — за фоновое; дайджест не должен дублировать NotificationKind.downloadFinished/saveFailed сразу после показа.
- Записи на диск (журнал событий, журнал сеансов) — только через JsonStore.
- Правка, меняющая поведение, идёт с тестом; ворота dart tool/gate.dart перед отправкой.

## risks

- Дайджест без персистентного журнала покажет при старте пустоту: события evaporate (downloadFinished, saveFailed, updateAvailable) — одноразовый show() без записи (notification_service.dart:44-50); нужен events.json под JsonStore с отметкой «просмотрено» и обрезкой по возрасту, иначе список растёт вечно.
- «Испарение» панели на искрах evaporate невозможно как у витрины: PortalSparkField живёт в состоянии плитки (portal_sparks.dart:21-26), а burstFrom витрины — на общем слое атмосферы (ev_atmosphere.dart:78-86); без общего слоя дайджест просто гаснет, а общий слой — новый виджет над IndexedStack с проверкой decorationMayRun.
- Предел скорости «в игре»: RunningGamesChanged живёт в LibraryBloc (library_bloc.dart:545-550), лимиты — в DownloadsBloc (applyLimits); связывать нужно потоком в одну сторону, как gameExits, иначе появится обратная зависимость.
- flutter_soloud собирается из C++ на трёх платформах CI: сломанная сборка видна только по расписанию, --smoke и упаковка (codesign --deep, UpdateUnpack, .deb/tarball с меткой .evaporate-install) получат новый нативный бинарник.
- Ctrl+V/Ctrl+O из пустой библиотеки (main.dart:232-239) могут столкнуться с Shortcuts/Actions в InputScope и NavAction — проверять на пустом фокусе.
- Витрина не различает «пусто» и «поиск не нашёл» (library_page.dart:106), evaporate различает (library_empty_state.dart:9-11) — при замене пустой полки второй случай легко потерять.
- Русский род в строках друзей («раздала», «её», past(verb) — friends_data.dart:63-75) не выражается ARB-подстановками — ещё довод не брать раздел.
- Карта года из существующего playtime не построить: сумму по дням задним числом не восстановить, карта заполнится только с момента введения журнала сеансов — на свежей установке пустая.
- Профиль как шестой раздел ломает цифры в метках «[ 01 / КОЛЛЕКЦИЯ ]» и клавиши 1–4; вход по аватару в рейле (витрина) у evaporate некуда класть — обойма без аватара.
- Оверлей как страница в окне: при полноэкранной игре окно лаунчера не видно, и «Shift+Tab поверх игры» не сработает без нативного хука; выдавать это за оверлей — обещание шире кода, как было с SOCKS5.
- Спекулярная полоса и наклон до 11° витрины пересекаются с foil/cardTilt evaporate — при слиянии героя две реализации одного блика; оставить foil/heroSweep, витринную полосу не переносить.
- Скелет 300 мс на старте — искусственная задержка: library.json читается мгновенно, а SmokeRun ждёт первого кадра; лишний таймер удлиняет --smoke без пользы.

## openQuestions

- Умеет ли DownloadEngine/dtorrent_task_v2 выбирать файлы внутри раздачи (части: игра, озвучка, текстуры)? Без этого диалогу «Добавить раздачу» с галочками нечего менять — останется только показ содержимого и размера.
- Отдаёт ли движок накопленную отдачу/приём за всё время и сохраняется ли это между сеансами (сессия _EngineStore)? От этого зависит, есть ли у «Статистики» рейтинг раздачи и «отдано/получено».
- Нужен ли раздел «Профиль» без друзей — или «Статистика» (часы по играм, устройства, отдача) ложится карточкой в «Настройки» либо в «Сохранения», не трогая обойму?
- Где и сколько хранить журнал событий для дайджеста (events.json, две недели?) и что считать «просмотрено» — закрытие панели или показ окна?
- Готов ли владелец к нативной аудиозависимости (flutter_soloud с C++-сборкой) после отказа от Rust ради перетаскивания ссылок — или звук откладывается до отдельного решения в docs/decisions/?
- Нужна ли полоса сценария и «Разработка» витрины в evaporate как демонстрационный режим для скриншотов и тестов, или они остаются только у витрины?
- Точка сохранения без «главы/места»: хватит ли времени, размера и устройства последнего снимка, или показывать note снимка (SaveSnapshot.note)?
- Оверлей: делать ли вообще «страницу идущей игры» в окне, если игра обычно полноэкранная и окно свёрнуто в трей — или ограничиться таймером на странице игры и пределом скорости в игре?

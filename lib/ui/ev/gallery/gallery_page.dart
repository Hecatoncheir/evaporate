import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/key_art.dart';
import '../data/sample_data.dart';
import '../design/appearance.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../launch/ev_launch_ritual.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_game_card.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_play_button.dart';
import '../widgets/ev_surfaces.dart';
import 'gallery_since.dart';

/// Галерея компонентов. Не экран продукта, а витрина системы: всё, что уже
/// перенесено из макетов, на одной странице и в работающем виде.
///
/// Открывается из настроек; облик и радиус переключаются здесь же и
/// действуют на всё приложение. Esc возвращает назад.
class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.of(context).maybePop(),
    },
    child: const Focus(autofocus: true, child: _GalleryBody()),
  );
}

class _GalleryBody extends StatefulWidget {
  const _GalleryBody();

  @override
  State<_GalleryBody> createState() => _GalleryBodyState();
}

class _GalleryBodyState extends State<_GalleryBody> {
  bool _shader = true;
  bool _sparks = true;
  bool _hold = true;
  String _quality = 'Полное';
  String? _launched;

  static const _games = [
    (
      'Пепельный Предел',
      'Action-RPG · 284 ч',
      EvCoverPalette.ash,
      1207,
      EvGameState.ready,
      null,
      null,
    ),
    (
      'Глубина 9',
      'Хоррор · 64 ч',
      EvCoverPalette.deepSea,
      9314,
      EvGameState.ready,
      null,
      null,
    ),
    (
      'Неон Хальцион',
      'Киберпанк · в очереди',
      EvCoverPalette.neon,
      4422,
      EvGameState.queued,
      null,
      'в очереди',
    ),
    (
      'Лунная Колея',
      'Симулятор · 92 ч',
      EvCoverPalette.lunar,
      7781,
      EvGameState.ready,
      null,
      null,
    ),
    (
      'Красный Меридиан',
      'Тактика · 196 ч',
      EvCoverPalette.crimson,
      2960,
      EvGameState.ready,
      null,
      null,
    ),
    (
      'Орбита 7',
      'Космосим · качается',
      EvCoverPalette.orbit,
      8802,
      EvGameState.downloading,
      0.41,
      '41 %',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(EvSpace.gutter),
          children: [
            _header(context, ev),
            const SizedBox(height: EvSpace.xxl),

            const EvSectionHeader('Запуск', count: 'удержание 620 мс · ритуал'),
            const SizedBox(height: EvSpace.l),
            EvPanel(
              glowCorner: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Единственный насыщенный объект на экране',
                    style: ev.text.label,
                  ),
                  const SizedBox(height: EvSpace.l),
                  Wrap(
                    spacing: EvSpace.m,
                    runSpacing: EvSpace.m,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      EvPlayButton(
                        requireHold: _hold,
                        onLaunch: () async {
                          await showEvLaunchRitual(
                            context,
                            title: 'Пепельный Предел',
                            stages: sampleLaunchStages,
                          );
                          if (mounted) {
                            setState(() => _launched = 'Пепельный Предел');
                          }
                        },
                      ),
                      EvGhostButton(
                        label: 'Подробнее',
                        icon: EvIcons.info,
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: EvSpace.m),
                  Text(
                    _launched == null
                        ? 'Нажатие ничего не делает — кнопку нужно удержать.'
                        : 'Запущено: $_launched',
                    style: ev.text.bodySmall.copyWith(
                      color: _launched == null ? c.ink4 : EvColors.ok,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: EvSpace.xxl),
            const EvSectionHeader('Полка', count: '6 игр'),
            const SizedBox(height: EvSpace.l),
            SizedBox(
              height: 296,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _games.length,
                separatorBuilder: (_, _) => const SizedBox(width: EvSpace.l),
                itemBuilder: (context, i) {
                  final g = _games[i];
                  return EvGameCard(
                    title: g.$1,
                    subtitle: g.$2,
                    palette: g.$3,
                    seed: g.$4,
                    state: g.$5,
                    progress: g.$6,
                    badge: g.$7,
                    onTap: () {},
                  );
                },
              ),
            ),

            const SizedBox(height: EvSpace.xxl),
            const EvSectionHeader('Состояния', count: 'цвет кодирует причину'),
            const SizedBox(height: EvSpace.l),
            EvPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wrap(
                    spacing: EvSpace.s,
                    runSpacing: EvSpace.s,
                    children: [
                      EvPill('Движок готов'),
                      EvPill('1.6 МБ/с', status: EvStatus.busy),
                      EvPill('Нет раздающих', status: EvStatus.warn),
                      EvPill('Диск переполнен', status: EvStatus.bad),
                      EvPill('Пауза', status: EvStatus.idle),
                    ],
                  ),
                  const SizedBox(height: EvSpace.l),
                  const Wrap(
                    spacing: EvSpace.s,
                    runSpacing: EvSpace.s,
                    children: [
                      EvChip('Установлена', hot: true),
                      EvChip('v2.4.1'),
                      EvChip('68.4 ГБ'),
                      EvChip('Action-RPG'),
                      EvChip('Одиночная'),
                    ],
                  ),
                  const SizedBox(height: EvSpace.xl),
                  Text('Приём · 41 %', style: ev.text.label),
                  const SizedBox(height: EvSpace.s),
                  const EvBar(0.41),
                  const SizedBox(height: EvSpace.m),
                  Text('Проверка · 66 %', style: ev.text.label),
                  const SizedBox(height: EvSpace.s),
                  const EvBar(0.66, cool: true),
                  const SizedBox(height: EvSpace.m),
                  Text('Завершено', style: ev.text.label),
                  const SizedBox(height: EvSpace.s),
                  const EvBar(1, muted: true),
                  const SizedBox(height: EvSpace.m),
                  Text('Ждём раздающих', style: ev.text.label),
                  const SizedBox(height: EvSpace.s),
                  const EvBar(0.41, tone: EvBarTone.stall),
                  const SizedBox(height: EvSpace.m),
                  Text('Остановлено ошибкой', style: ev.text.label),
                  const SizedBox(height: EvSpace.s),
                  const EvBar(0.41, tone: EvBarTone.dead),
                  const SizedBox(height: EvSpace.m),
                  Text('Перепроверка частей', style: ev.text.label),
                  const SizedBox(height: EvSpace.s),
                  const EvBar(0.38, tone: EvBarTone.arc),
                  const SizedBox(height: EvSpace.xl),
                  Text('Действие одним знаком', style: ev.text.label),
                  const SizedBox(height: EvSpace.s),
                  Row(
                    children: [
                      EvIconButton(
                        icon: EvIcons.pause,
                        label: 'Пауза',
                        onPressed: () {},
                      ),
                      const SizedBox(width: 7),
                      EvIconButton(
                        icon: EvIcons.folder,
                        label: 'Открыть папку',
                        accent: EvIconButtonAccent.hot,
                        onPressed: () {},
                      ),
                      const SizedBox(width: 7),
                      EvIconButton(
                        icon: EvIcons.close,
                        label: 'Отменить',
                        accent: EvIconButtonAccent.danger,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: EvSpace.xxl),
            const EvSectionHeader('Пусто', count: 'раздел без содержимого'),
            const SizedBox(height: EvSpace.l),
            EvNothing(
              icon: EvIcons.download,
              title: 'Ничего не качается',
              detail:
                  'Перетащите .torrent в окно или вставьте magnet-ссылку — '
                  'движок подхватит её сам',
              action: EvMiniButton(
                label: 'Вставить ссылку',
                icon: EvIcons.magnet,
                onPressed: () {},
              ),
            ),

            const GallerySince(),

            const SizedBox(height: EvSpace.xxl),
            const EvSectionHeader('Настройки', count: 'строки и контролы'),
            const SizedBox(height: EvSpace.l),
            EvPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Атмосфера', style: ev.text.label),
                  EvOption(
                    title: 'Живой фон (шейдер)',
                    description: 'Объёмный плюм пара за интерфейсом',
                    control: EvSwitch(
                      value: _shader,
                      semanticLabel: 'Живой фон',
                      onChanged: (v) => setState(() => _shader = v),
                    ),
                  ),
                  EvOption(
                    title: 'Искры и частицы',
                    description: 'Восходящие угли, аддитивное смешивание',
                    control: EvSwitch(
                      value: _sparks,
                      semanticLabel: 'Искры',
                      onChanged: (v) => setState(() => _sparks = v),
                    ),
                  ),
                  EvOption(
                    title: 'Удержание кнопки «Играть»',
                    description: 'Защита от случайного запуска · 620 мс',
                    control: EvSwitch(
                      value: _hold,
                      semanticLabel: 'Удержание',
                      onChanged: (v) => setState(() => _hold = v),
                    ),
                  ),
                  EvOption(
                    last: true,
                    title: 'Уровень эффектов',
                    description: 'Плотность частиц и разрешение шейдера',
                    control: EvSegmented<String>(
                      items: const {
                        'Эко': 'Эко',
                        'Полное': 'Полное',
                        'Макс': 'Макс',
                      },
                      value: _quality,
                      onChanged: (v) => setState(() => _quality = v),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: EvSpace.xxl),
            const EvSectionHeader('Иконки', count: 'сетка 24 · обводка 1.5'),
            const SizedBox(height: EvSpace.l),
            EvPanel(
              child: Wrap(
                spacing: EvSpace.xl,
                runSpacing: EvSpace.l,
                children: [
                  for (final n in const [
                    EvIcons.library,
                    EvIcons.download,
                    EvIcons.saves,
                    EvIcons.settings,
                    EvIcons.friends,
                    EvIcons.search,
                    EvIcons.play,
                    EvIcons.pause,
                    EvIcons.peers,
                    EvIcons.seed,
                    EvIcons.speed,
                    EvIcons.disk,
                    EvIcons.cloud,
                    EvIcons.folder,
                    EvIcons.trophy,
                    EvIcons.verified,
                    EvIcons.boost,
                    EvIcons.audio,
                  ])
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EvIcon(n, size: 22, color: c.ink2),
                        const SizedBox(height: EvSpace.s),
                        Text(
                          n,
                          style: ev.text.data.copyWith(
                            color: c.ink4,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: EvSpace.xxl),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, EvTheme ev) {
    final c = ev.colors;
    final appearance = EvAppearanceScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (Navigator.of(context).canPop()) ...[
          Row(
            children: [
              EvMiniButton(
                label: 'Назад',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: EvSpace.m),
              Text('Esc', style: ev.text.data.copyWith(color: c.ink4)),
            ],
          ),
          const SizedBox(height: EvSpace.xl),
        ],
        Row(
          children: [
            const EvMark(size: 44),
            const SizedBox(width: EvSpace.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EVAPORATE · КОМПОНЕНТЫ', style: ev.text.label),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Дизайн-система '),
                        TextSpan(
                          text: 'вживую',
                          style: ev.text.displayBold(34),
                        ),
                      ],
                    ),
                    style: ev.text.display(34),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: EvSpace.l),
        Wrap(
          spacing: EvSpace.m,
          runSpacing: EvSpace.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Облик', style: ev.text.label),
            EvSegmented<EvSkin>(
              items: {for (final s in EvSkin.values) s: s.label},
              value: appearance.skin,
              onChanged: (s) => appearance.skin = s,
            ),
            const SizedBox(width: EvSpace.s),
            Text('Радиус', style: ev.text.label),
            EvSegmented<EvGeometry>(
              items: {for (final g in EvGeometry.values) g: g.label},
              value: appearance.geometry,
              onChanged: (g) => appearance.geometry = g,
            ),
          ],
        ),
        const SizedBox(height: EvSpace.m),
        Text(
          'Токены приходят через ThemeExtension, поэтому смена облика и потолка '
          'радиуса не требует правок в самих виджетах.',
          style: ev.text.bodySmall.copyWith(color: c.ink4),
        ),
      ],
    );
  }
}

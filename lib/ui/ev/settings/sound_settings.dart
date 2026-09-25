import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../sound/ev_sound.dart';
import '../sound/voices.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import 'settings_search.dart';

/// Раздел «Звук»: слой, громкость, три класса, отдушина — и каталог
/// девяти голосов, каждый можно послушать. Пока слой выключен, остальное
/// приглушено: оно ждёт его.
EvSettingSection evSoundSection(EvSound sound) {
  final off = !sound.enabled;
  EvSettingRow toggle(
    String title,
    String detail,
    bool value,
    ValueChanged<bool> onChanged, {
    bool dim = true,
  }) => EvSettingRow(
    title: title,
    detail: detail,
    dim: dim && off,
    control: (_) =>
        EvSwitch(value: value, semanticLabel: title, onChanged: onChanged),
  );

  return EvSettingSection(
    id: 'snd',
    title: 'Звук',
    icon: EvIcons.audio,
    panels: [
      EvSettingPanel(
        label: 'Слой и классы',
        rows: [
          toggle(
            'Звуковой слой',
            'Выключен по умолчанию: лаунчер не должен шуметь на первом запуске',
            sound.enabled,
            (v) => sound.enabled = v,
            dim: false,
          ),
          EvSettingRow(
            title: 'Громкость',
            detail: 'Ритуал запуска на 6 дБ громче интерфейса',
            words: [for (final v in EvVolume.values) v.label],
            dim: off,
            control: (_) => EvSegmented<EvVolume>(
              items: {for (final v in EvVolume.values) v: v.label},
              value: sound.volume,
              onChanged: (v) => sound.volume = v,
            ),
          ),
          for (final c in EvSoundClass.values)
            toggle(
              c.label,
              c.detail,
              sound.heard(c),
              (v) => sound.setHeard(c, v),
            ),
          toggle(
            'Фоновая отдушина',
            'Тихий дышащий шум ниже 210 Гц, пока окно активно',
            sound.ambient,
            (v) => sound.ambient = v,
          ),
          EvSettingRow(
            title: 'Проверить',
            detail:
                'Все девять голосов синтезируются на месте, ни одного файла',
            dim: off,
            control: (_) => EvMiniButton(
              label: 'Сыграть',
              icon: EvIcons.audio,
              onPressed: () => sound.play(EvVoice.evaporate),
            ),
          ),
        ],
      ),
      EvSettingPanel(
        label: 'Голоса',
        note:
            'Числа — это и есть звук: аргументы синтеза, а не описание '
            'файла. Голос длиннее своего класса — ошибка',
        body: (_) => _VoiceList(sound: sound),
      ),
    ],
  );
}

/// Девять голосов: имя, класс, длительность, развёртка и «послушать».
class _VoiceList extends StatelessWidget {
  const _VoiceList({required this.sound});

  final EvSound sound;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final data = ev.text.data.copyWith(fontSize: 10.5, color: c.ink3);
    return Opacity(
      opacity: sound.enabled ? 1 : .4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final v in EvVoice.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  EvIconButton(
                    icon: EvIcons.play,
                    label: 'Послушать: ${v.label}',
                    size: 28,
                    onPressed: () => sound.play(v),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      v.label,
                      style: ev.text.body.copyWith(fontSize: 13, color: c.ink),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(v.soundClass.label, style: data),
                  ),
                  Expanded(flex: 2, child: Text(v.length, style: data)),
                  Expanded(flex: 3, child: Text(v.sweep, style: data)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

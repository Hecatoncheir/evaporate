import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/settings/settings_bloc.dart';
import '../../../models/app_settings.dart';
import '../../../models/effect_quality.dart';
import '../../../models/library_effect.dart';
import '../design/effects.dart';
import '../sound/ev_sound.dart';

/// Эффекты и звук прототипа для всего окна — над навигатором, чтобы их
/// видели и каркас, и палитра, и всё, что открывается поверх.
///
/// Эффекты не хранятся отдельно: они выводятся из облика в настройках
/// приложения ([applyAppearance]), и переключатель в настройках правит
/// ровно то, что видно в каркасе.
class EvAppScope extends StatefulWidget {
  const EvAppScope({super.key, this.sound, required this.child});

  /// Звук окна; один на приложение и заводится в `main`. Не задан — окно
  /// молчит: тестам и превью настоящий звук ни к чему.
  final EvSound? sound;

  final Widget child;

  @override
  State<EvAppScope> createState() => _EvAppScopeState();
}

class _EvAppScopeState extends State<EvAppScope> {
  final _effects = EvEffects();
  late final _silent = widget.sound == null
      ? EvSound(out: const EvSilentOut())
      : null;

  EvSound get _sound => widget.sound ?? _silent!;

  @override
  void initState() {
    super.initState();
    applyAppearance(_effects, context.read<SettingsBloc>().state.appearance);
  }

  @override
  void dispose() {
    _effects.dispose();
    _silent?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsBloc, AppSettings>(
      listenWhen: (before, after) => before.appearance != after.appearance,
      listener: (context, settings) =>
          applyAppearance(_effects, settings.appearance),
      child: EvEffectsScope(
        effects: _effects,
        child: EvSoundScope(sound: _sound, child: widget.child),
      ),
    );
  }
}

/// Облик приложения — на эффекты прототипа.
///
/// * качество — то же качество, ступень в ступень;
/// * стекло — переключатель «Стекло»;
/// * живой фон (плюм пара) — «Свет игр»: он занял место прежнего света
///   корпуса и так же красит окно;
/// * угли, зерно и параллакс своих переключателей не имеют и подчиняются
///   общему выключателю украшений — «выключено» гасит и их;
/// * остальное (преломление, ритуал запуска, удержание «Играть», 30 к/с в
///   фоне) — как в прототипе: у приложения таких настроек нет.
void applyAppearance(EvEffects effects, Appearance appearance) {
  final decor = appearance.libraryEffects;
  effects
    ..quality = _quality(appearance.effectQuality)
    ..glass = appearance.shows(LibraryEffect.glass)
    ..livingBackground = appearance.shows(LibraryEffect.ambient)
    ..sparks = decor
    ..grain = decor
    ..parallax = decor;
}

EvEffectsQuality _quality(EffectQuality quality) => switch (quality) {
  EffectQuality.eco => EvEffectsQuality.eco,
  EffectQuality.full => EvEffectsQuality.full,
  EffectQuality.max => EvEffectsQuality.max,
};

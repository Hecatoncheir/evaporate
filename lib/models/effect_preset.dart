import 'app_settings.dart';

/// Набор украшений одним выбором: выключено, спокойно, обычно, полностью.
///
/// Флаг на каждое украшение остаётся — у них разная цена и разный вкус, и
/// один общий переключатель означал бы «или всё, или ничего». Но
/// тринадцать переключателей подряд человек не выбирает, а пролистывает,
/// поэтому наверху стоит выбор из наборов, а сами флаги уехали под
/// «Подробно».
///
/// Набор — не новое состояние: он раскладывается в те же флаги, и ни
/// настройки, ни виджеты о нём не знают. Отсюда и то, что «выключено»
/// трогает **только общий выключатель**: включив украшения обратно, человек
/// получает свой набор, а не наш.
///
/// Наборы выстроены лестницей — `calm` ⊂ `standard` ⊂ `full`, — и «обычно»
/// в ней не выдумано, а взято из значений по умолчанию: иначе на свежей
/// установке не горел бы ни один сегмент, и выбор выглядел бы сломанным.
enum EffectPreset { off, calm, standard, full }

/// Значения по умолчанию — единственный источник правды для «обычно».
/// Путь здесь ни при чём: читаются только флаги украшений.
const _shipped = AppSettings(installDir: '');

extension EffectPresetFlags on EffectPreset {
  /// Раскладывает набор во флаги настроек.
  ///
  /// `selectionFrameEnabled` набор не трогает: рамка показывает место в
  /// сетке, а не украшает её, и живёт мимо общего выключателя.
  AppSettings applyTo(AppSettings settings) => switch (this) {
    EffectPreset.off => settings.copyWith(libraryEffects: false),
    // Спокойно — это не «поменьше блеска», а ровно то, чем оболочка
    // объясняет, что куда переехало: проявления разделов и обложка фоном
    // на странице игры. Остальное гаснет.
    EffectPreset.calm => settings.copyWith(
      libraryEffects: true,
      interfaceAnimationsEnabled: true,
      coverBackdropEnabled: true,
      particlesEnabled: false,
      wavesEnabled: false,
      foilEnabled: false,
      cardTiltEnabled: false,
      liquidDistortionEnabled: false,
      liquidSelectionEnabled: false,
      ambientEnabled: false,
      heroSweepEnabled: false,
      dropsEnabled: false,
      portalEnabled: false,
    ),
    // Обычно — как поставляется. Флаги берутся из значений по умолчанию, а
    // не выписаны числом: поменяется значение по умолчанию — поменяется и
    // набор, и они не разойдутся молча.
    EffectPreset.standard => settings.copyWith(
      libraryEffects: true,
      interfaceAnimationsEnabled: _shipped.interfaceAnimationsEnabled,
      coverBackdropEnabled: _shipped.coverBackdropEnabled,
      particlesEnabled: _shipped.particlesEnabled,
      wavesEnabled: _shipped.wavesEnabled,
      foilEnabled: _shipped.foilEnabled,
      cardTiltEnabled: _shipped.cardTiltEnabled,
      liquidDistortionEnabled: _shipped.liquidDistortionEnabled,
      liquidSelectionEnabled: _shipped.liquidSelectionEnabled,
      ambientEnabled: _shipped.ambientEnabled,
      heroSweepEnabled: _shipped.heroSweepEnabled,
      dropsEnabled: _shipped.dropsEnabled,
      portalEnabled: _shipped.portalEnabled,
    ),
    EffectPreset.full => settings.copyWith(
      libraryEffects: true,
      interfaceAnimationsEnabled: true,
      coverBackdropEnabled: true,
      particlesEnabled: true,
      wavesEnabled: true,
      foilEnabled: true,
      cardTiltEnabled: true,
      liquidDistortionEnabled: true,
      liquidSelectionEnabled: true,
      ambientEnabled: true,
      heroSweepEnabled: true,
      dropsEnabled: true,
      portalEnabled: true,
    ),
  };
}

extension EffectPresetOf on AppSettings {
  /// Какому набору отвечают нынешние флаги, или `null` — человек собрал
  /// свой в «Подробно».
  ///
  /// Сравнением, а не своей таблицей: раскладку набора знает [applyTo], и
  /// вторая её копия здесь однажды разошлась бы с первой. Выключенные
  /// украшения проверяются первыми — при погашенном общем выключателе
  /// значения отдельных флагов уже ничего не решают.
  EffectPreset? get effectPreset {
    if (!libraryEffects) return EffectPreset.off;
    for (final preset in [
      EffectPreset.calm,
      EffectPreset.standard,
      EffectPreset.full,
    ]) {
      if (preset.applyTo(this) == this) return preset;
    }
    return null;
  }
}

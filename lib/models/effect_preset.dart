import 'appearance.dart';
import 'library_effect.dart';

/// Набор украшений одним выбором: выключено, спокойно, обычно, полностью.
///
/// Флаг на каждое украшение остаётся — у них разная цена и разный вкус, и
/// один общий переключатель означал бы «или всё, или ничего». Но
/// полтора десятка переключателей подряд человек не выбирает, а пролистывает,
/// поэтому наверху стоит выбор из наборов, а сами флаги уехали под
/// «Подробно».
///
/// Набор — не новое состояние: он раскладывается в те же украшения, и ни
/// настройки, ни виджеты о нём не знают. Отсюда и то, что «выключено»
/// трогает **только общий выключатель**: включив украшения обратно, человек
/// получает свой набор, а не наш.
///
/// Наборы выстроены лестницей — `calm` ⊂ `standard` ⊂ `full`, — и «обычно»
/// в ней не выдумано, а взято из того, с чем приложение поставляется:
/// иначе на свежей установке не горел бы ни один сегмент, и выбор выглядел
/// бы сломанным.
enum EffectPreset { off, calm, standard, full }

/// Спокойно — это не «поменьше блеска», а ровно то, чем оболочка
/// объясняет, что куда переехало: проявления разделов и обложка фоном на
/// странице игры. Остальное гаснет.
const _calm = {LibraryEffect.interfaceAnimations, LibraryEffect.coverBackdrop};

extension EffectPresetFlags on EffectPreset {
  /// Раскладывает набор в украшения настроек.
  ///
  /// Рамку выбора набор не трогает: она показывает место в сетке, а не
  /// украшает её, и живёт мимо общего выключателя. Поэтому всё
  /// независимое переносится из нынешних настроек как есть.
  Appearance applyTo(Appearance settings) => switch (this) {
    EffectPreset.off => settings.copyWith(libraryEffects: false),
    EffectPreset.calm => settings.copyWith(
      libraryEffects: true,
      effects: _keepIndependent(settings, _calm),
    ),
    EffectPreset.standard => settings.copyWith(
      libraryEffects: true,
      effects: _keepIndependent(settings, LibraryEffect.shipped),
    ),
    EffectPreset.full => settings.copyWith(
      libraryEffects: true,
      effects: _keepIndependent(settings, LibraryEffect.decorative),
    ),
  };

  Set<LibraryEffect> _keepIndependent(
    Appearance settings,
    Set<LibraryEffect> chosen,
  ) => {
    for (final effect in chosen)
      if (!effect.independent) effect,
    for (final effect in settings.effects)
      if (effect.independent) effect,
  };
}

extension EffectPresetOf on Appearance {
  /// Какому набору отвечают нынешние украшения, или `null` — человек собрал
  /// свой в «Подробно».
  ///
  /// Сравнением, а не своей таблицей: раскладку набора знает [applyTo], и
  /// вторая её копия здесь однажды разошлась бы с первой. Выключенные
  /// украшения проверяются первыми — при погашенном общем выключателе
  /// отдельные уже ничего не решают.
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

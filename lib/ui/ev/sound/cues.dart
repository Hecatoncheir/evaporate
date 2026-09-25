import '../downloads/download_data.dart';
import '../library/hero_state.dart';
import '../saves/saves_data.dart';
import 'voices.dart';

// События движка и их голоса — те же, что `cue` в прототипе. Цвет
// состояния и голос говорят одно: янтарное «ждём внешнего» — «Внимание»,
// красное «нужно решение» — «Ошибка».
//
// Пассивные события сюда не входят и молчат: докачка и заявка в друзья
// не зовут человека, пока он в другом разделе, — они ждут в дайджесте.

/// Голос, которым окно встречает новое состояние игры.
///
/// «Игра запущена» своего голоса не имеет: запуск уже прозвучал ритуалом
/// или коротким «Готово». В прототипе «Готово» звучало ещё раз, когда
/// ритуал уходил, — без ритуала это два «Готово» подряд за 0,9 с.
EvVoice? evHeroCue(EvHeroState state) => switch (state) {
  EvHeroState.offline => EvVoice.warn,
  _ => null,
};

/// Голос нового состояния очереди.
EvVoice? evDownloadsCue(EvDownloadsState state) => switch (state) {
  EvDownloadsState.noSpace => EvVoice.err,
  EvDownloadsState.noSeeds ||
  EvDownloadsState.hash ||
  EvDownloadsState.offline => EvVoice.warn,
  _ => null,
};

/// Голос нового состояния облака сохранений.
EvVoice? evSavesCue(EvSavesState state) => switch (state) {
  EvSavesState.conflict || EvSavesState.noCloud => EvVoice.warn,
  _ => null,
};

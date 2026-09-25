import '../overlay/overlay_data.dart';
import '../profile/profile_data.dart';
import 'sample_data.dart';

/// Игра, которая идёт в состоянии «Игра запущена» и под оверлеем.
///
/// Достижение этой сессии — третье в игре, «Без единой царапины»:
/// в прототипе оверлей хвалил «Тихий шаг», полученный 22 минуты назад,
/// а профиль — тот же «Тихий шаг» три часа назад, до начала сессии.
final sampleSession = EvSession(
  game: sampleHero,
  elapsed: const Duration(hours: 1, minutes: 4, seconds: 12),
  chapter: 'Глава 5',
  place: 'Кузня Сумерек',
  pid: 8842,
  fps: 144,
  lowFps: 108,
  vramGb: 9.4,
  gpuC: 71,
  cpu: 38,
  earned: EvEarned(sampleHero, 2, '22 минуты назад'),
);

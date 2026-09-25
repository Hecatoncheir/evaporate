import '../profile/profile_data.dart';
import 'sample_data.dart';
import 'sample_friends.dart';
import 'sample_saves.dart';
import 'sample_session.dart';

// Своя страница. Руками здесь только то, что лаунчер про прошлое не
// хранит по отдельности: часы до последнего года и весь трафик. Остальное
// — из библиотеки, друзей, устройств и года игры.

SampleGame _game(String title) =>
    sampleLibrary.firstWhere((g) => g.title == title);

/// Код для друзей. Его же вводят в «Друзья → Добавить по коду».
const sampleFriendCode = 'EVP-8К4М-ТРПЛ';

final sampleProfile = EvProfile(
  name: sampleUserName,
  initials: sampleUserInitials,
  since: '2 года 4 месяца',
  code: sampleFriendCode,
  // Зерно прототипа: 193 дня, 392 часа, серия в 13 дней.
  year: EvPlayYear.sample(20260914),
  hoursBefore: 892,
  uploadedGb: 1400,
  receivedGb: 581,
  library: sampleLibrary,
  people: samplePeople,
  here: evThisPc,
  away: const [(evLaptop, 178)],
  // Только то, что карточка игры показывает полученным: первые три
  // достижения в каждой игре, где есть часы. Первое — из идущей сессии.
  recent: [
    sampleSession.earned,
    EvEarned(_game('Красный Меридиан'), 2, 'вчера'),
    EvEarned(_game('Волчья Тропа'), 0, '4 дня назад'),
    EvEarned(_game('Стеклянный Сад'), 1, 'неделю назад'),
  ],
);

import 'package:evaporate/models/save_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

/// Момент снятия снимка уезжает на другие устройства, а у них другой
/// часовой пояс. Прежде в манифест шло местное время без смещения, и
/// читающая машина принимала его за своё местное — проверка «здесь новее»
/// ошибалась на разницу поясов.
void main() {
  SaveSnapshot snapshotAt(DateTime moment) => SaveSnapshot(
    id: 's1',
    gameId: 'g1',
    gameTitle: 'Игра',
    createdAt: moment,
    deviceName: 'здешний',
    platform: 'windows',
    sizeBytes: 1,
    archivePath: '',
    rules: const [],
  );

  test('в манифест момент уходит в UTC, со смещением', () {
    final moment = DateTime(2026, 9, 22, 10);
    final written = snapshotAt(moment).toManifest()['createdAt'] as String;

    expect(written, endsWith('Z'));
    expect(DateTime.parse(written).isUtc, isTrue);
    expect(DateTime.parse(written).isAtSameMomentAs(moment), isTrue);
  });

  test('момент с чужим поясом читается тем же мгновением', () {
    // Снято в 10:00 по Москве — это 07:00 по Гринвичу, где бы ни читали.
    final read = SaveSnapshot.readMoment('2026-09-22T10:00:00.000+03:00');

    expect(read.isAtSameMomentAs(DateTime.utc(2026, 9, 22, 7)), isTrue);
    expect(read.isUtc, isFalse, reason: 'показ и сравнение — в местном');
  });

  test('записанное читается обратно тем же моментом', () {
    final moment = DateTime(2026, 9, 22, 10, 30, 15, 250);

    final back = SaveSnapshot.fromJson(snapshotAt(moment).toJson());

    expect(back.createdAt, moment);
  });

  // «Сейчас» делало нечитаемый пакет самым свежим из всех, и при переносе
  // он затирал то, что новее на самом деле.
  test('нечитаемая дата — эпоха, а не сейчас', () {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);

    expect(SaveSnapshot.readMoment('вчера'), epoch);
    expect(SaveSnapshot.readMoment(null), epoch);
    expect(SaveSnapshot.readMoment(42), epoch);
  });

  test('прежняя запись без смещения читается местным временем', () {
    expect(
      SaveSnapshot.readMoment('2026-09-22T10:00:00.000'),
      DateTime(2026, 9, 22, 10),
    );
  });
}

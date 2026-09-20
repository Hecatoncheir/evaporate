import 'package:evaporate/input/gamepad_binding.dart';
import 'package:evaporate/input/gamepad_service.dart';
import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Модели сравниваются по значениям, а не по ссылке.
///
/// Это не чистота ради чистоты: состояния блоков — `Equatable`, и пока
/// игра сравнивалась по ссылке, `copyWith` с теми же значениями давал
/// «новое» состояние и перестройку всей страницы библиотеки.
void main() {
  Game game({String title = 'Игра'}) =>
      Game(id: 'g1', title: title, addedAt: DateTime(2026));

  test('игра с теми же полями равна себе', () {
    expect(game(), game());
    expect(game().hashCode, game().hashCode);
    expect(game(), isNot(game(title: 'Другая')));
  });

  // Правка, ничего не меняющая, не должна выглядеть правкой: на ней
  // перестраивалась вся сетка обложек.
  test('copyWith без изменений даёт равную игру', () {
    final before = game();

    expect(before.copyWith(), before);
    expect(before.copyWith(title: 'Игра'), before);
    expect(before.copyWith(title: 'Другая'), isNot(before));
  });

  test('профиль сохранений сравнивается по правилам', () {
    const rule = SavePathRule(
      id: 'r1',
      label: 'Сохранения',
      template: '{HOME}/s',
    );

    expect(const SaveProfile(rules: [rule]), const SaveProfile(rules: [rule]));
    expect(
      const SaveProfile(rules: [rule]),
      isNot(const SaveProfile(rules: [rule], keepSnapshots: 3)),
    );
  });

  test('снимок сравнивается по содержимому', () {
    SaveSnapshot snapshot({int sizeBytes = 10}) => SaveSnapshot(
      id: 's1',
      gameId: 'g1',
      gameTitle: 'Игра',
      createdAt: DateTime(2026),
      deviceName: 'здесь',
      platform: 'windows',
      sizeBytes: sizeBytes,
      archivePath: '',
      rules: const [],
    );

    expect(snapshot(), snapshot());
    expect(snapshot(), isNot(snapshot(sizeBytes: 11)));
  });

  // Список устройств переспрашивается раз в секунду, и раньше каждый
  // одинаковый ответ считался новым состоянием: подвал окна и настройки
  // геймпада перестраивались ежесекундно, пока приложение открыто.
  test('равное состояние геймпада слушателей не будит', () {
    final status = ValueNotifier(const GamepadStatus(available: true));
    addTearDown(status.dispose);
    var notifications = 0;
    status.addListener(() => notifications++);

    status.value = const GamepadStatus(available: true);
    expect(notifications, 0);

    status.value = const GamepadStatus(available: true, devices: ['геймпад']);
    expect(notifications, 1);
  });

  test('настройки с равной раскладкой геймпада равны', () {
    const first = AppSettings(
      installDir: 'игры',
      gamepad: GamepadBinding(deadzone: 0.4),
    );
    const second = AppSettings(
      installDir: 'игры',
      gamepad: GamepadBinding(deadzone: 0.4),
    );

    expect(first, second);
    expect(
      first,
      isNot(
        const AppSettings(
          installDir: 'игры',
          gamepad: GamepadBinding(deadzone: 0.6),
        ),
      ),
    );
  });
}

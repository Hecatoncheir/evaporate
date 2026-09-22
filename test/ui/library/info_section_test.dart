import 'package:evaporate/l10n/app_localizations_en.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/detail/info_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Сведения об игре называют источник словами языка интерфейса.
///
/// Прежде сюда шла журнальная подпись модели — русская всегда, и в
/// английской локали строка читалась «Source: Локальная папка: …». Страж
/// кириллицы её не видел: литерал лежит в `lib/models`.
void main() {
  testWidgets('в английском интерфейсе источник назван по-английски', (
    tester,
  ) async {
    final game = Game(
      id: 'g',
      title: 'Игра',
      addedAt: DateTime(2026),
      download: const DownloadLink(
        source: GameSource(kind: GameSourceKind.localFolder, value: '/games/x'),
      ),
    );

    await tester.pumpWidget(
      hostWidget(
        SingleChildScrollView(child: InfoSection(game: game)),
        locale: const Locale('en'),
      ),
    );

    expect(find.text('${LEn().sourceFolder}: /games/x'), findsOneWidget);
    expect(find.textContaining('Локальная папка'), findsNothing);
  });
}

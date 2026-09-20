import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../core/progress_throttle.dart';

/// Один GET: открыть клиента, проверить код, прочитать тело, закрыть.
///
/// Четыре места писали это своими словами — каталог Steam дважды, проверка
/// обновлений и база путей сохранений, — и одинаково ошибались бы в одном:
/// клиента надо закрывать в `finally`, а тело дочитывать **до** закрытия.
///
/// Общее здесь — устройство запроса, а не слова о нём: во что превратить
/// чужой отказ, решает зовущий ([describeStatus]). Отказ каталога — про
/// каталог, отказ обновления — про обновление, и сводить их к одному
/// исключению значило бы сказать человеку меньше, чем знаем.
class HttpFetch {
  const HttpFetch({
    required this.openClient,
    required this.describeStatus,
    this.headers = const {},
    this.limitBytes,
  });

  /// Откуда брать клиента: прямого, перехваченного или своего.
  final HttpClient Function() openClient;

  /// Что бросить, если сервер ответил не двумя сотнями.
  final Exception Function(int status) describeStatus;

  /// Заголовки запроса. GitHub без них отвечает иначе, чем ожидается.
  final Map<String, String> headers;

  /// Предел размера тела. Ответ приходит извне, и принимать его без
  /// предела — значит позволить чужой стороне занять всю память.
  final int? limitBytes;

  /// Тело ответа байтами.
  ///
  /// Копим в `BytesBuilder`, а не в `List<int>`: в списке чисел каждый байт
  /// занимает машинное слово, и манифест путей на семнадцать мегабайт стоил
  /// бы под полгигабайта — да ещё с удвоением при росте.
  Future<Uint8List> bytes(
    Uri uri, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = openClient();
    try {
      final request = await client.getUrl(uri);
      headers.forEach(request.headers.set);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw describeStatus(response.statusCode);
      }

      final total = response.contentLength > 0 ? response.contentLength : 0;
      final builder = BytesBuilder(copy: false);
      final progress = ProgressThrottle(
        () => onProgress?.call(builder.length, total),
      );
      await for (final chunk in response) {
        builder.add(chunk);
        final limit = limitBytes;
        if (limit != null && builder.length > limit) {
          throw const FormatException('Тело ответа длиннее дозволенного');
        }
        if (onProgress != null) progress.tick();
      }
      if (onProgress != null) progress.finish();
      return builder.takeBytes();
    } finally {
      // Без `await` выше клиент закрылся бы раньше, чем дочитано тело.
      client.close(force: true);
    }
  }

  /// Тело ответа текстом.
  Future<String> text(Uri uri) async => utf8.decode(await bytes(uri));
}

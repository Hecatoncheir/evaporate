import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../core/progress_throttle.dart';
import 'http_fetch.dart';
import 'proxy_http_overrides.dart';
import 'update_exception.dart';

/// Как обновление достаётся из сети.
///
/// Отдельно от подготовки, потому что здесь своя забота — докачка: полсотни
/// мегабайт по плохому каналу обрываются регулярно, и без продолжения
/// каждая попытка начинается с нуля, то есть не заканчивается никогда.
class UpdateTransport {
  const UpdateTransport._();

  /// Качает файл в [target], продолжая с байта [from].
  ///
  /// Докачка нужна не ради экономии трафика: полсотни мегабайт по плохому
  /// каналу обрываются регулярно, а без продолжения каждая попытка
  /// начинается с нуля — то есть на таком канале не заканчивается никогда.
  static Future<void> download(
    Uri uri,
    File target,
    int from,
    void Function(int, int) onProgress,
  ) async {
    final client = directHttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final response = await _open(client, uri, from);
      // Просим больше, чем файл занимает: значит он уже весь у нас, и
      // сказать об этом должна проверка суммы, а не отказ загрузки.
      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        await response.drain<void>();
        return;
      }
      // Докачку сервер поддерживать не обязан: не умеет — отвечает целым
      // файлом и кодом 200, и тогда прежний кусок надо выбросить, а не
      // дописать к нему второй.
      final resumed = response.statusCode == HttpStatus.partialContent;
      if (!resumed && response.statusCode != HttpStatus.ok) {
        throw UpdateException('Сервер ответил ${response.statusCode}');
      }
      await _writeBody(
        response,
        target,
        alreadyHave: resumed ? from : 0,
        append: resumed,
        onProgress: onProgress,
      );
    } on SocketException catch (error) {
      throw UpdateException('Нет связи: ${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  /// Как часто докладываем о ходе загрузки. Кусков приходят тысячи, и
  /// перерисовывать окно на каждый значит тратить на показ больше, чем на
  /// саму загрузку.
  static const _progressInterval = Duration(milliseconds: 100);

  /// Пишет тело ответа в файл, изредка сообщая о ходе.
  static Future<void> _writeBody(
    HttpClientResponse response,
    File target, {
    required int alreadyHave,
    required bool append,
    required void Function(int, int) onProgress,
  }) async {
    var received = alreadyHave;
    final total = response.contentLength > 0
        ? response.contentLength + received
        : 0;
    final sink = target.openWrite(
      mode: append ? FileMode.append : FileMode.writeOnly,
    );
    final progress = ProgressThrottle(
      () => onProgress(received, total),
      interval: _progressInterval,
    );
    try {
      // Простойный предел, как у `HttpFetch`: сеть, пропавшая посреди
      // загрузки, иначе оставляла «устанавливается» навсегда.
      await for (final chunk in response.timeout(
        HttpFetch.defaultIdleTimeout,
      )) {
        sink.add(chunk);
        received += chunk.length;
        progress.tick();
      }
    } finally {
      await sink.close();
    }
    progress.finish();
  }

  /// Запрос с продолжением и переадресациями.
  ///
  /// Диапазон переезжает вместе с запросом: GitHub уводит на своё
  /// хранилище, и докачивать предстоит уже там.
  static Future<HttpClientResponse> _open(
    HttpClient client,
    Uri uri,
    int from,
  ) async {
    var target = uri;
    for (var hop = 0; hop <= 5; hop++) {
      final request = await client.getUrl(target);
      if (from > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-');
      }
      final response = await request.close().timeout(
        HttpFetch.defaultIdleTimeout,
      );
      if (!response.isRedirect) return response;
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null) return response;
      await response.drain<void>();
      target = target.resolve(location);
    }
    throw const UpdateException('Слишком много переадресаций');
  }

  /// Читает небольшой файл релиза целиком — например, `SHA256SUMS`.
  ///
  /// Переадресации идут тем же путём, что и у самой загрузки: GitHub
  /// уводит на своё хранилище, и адрес разрешается относительно того, куда
  /// увели, а не исходного.
  static Future<List<int>> fetch(
    Uri uri,
    void Function(int, int) onProgress,
  ) async {
    final client = directHttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final response = await _open(client, uri, 0);
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('Сервер ответил ${response.statusCode}');
      }

      final total = response.contentLength;
      final builder = BytesBuilder(copy: false);
      final progress = ProgressThrottle(
        () => onProgress(builder.length, total),
        interval: _progressInterval,
      );
      await for (final chunk in response) {
        builder.add(chunk);
        progress.tick();
      }
      progress.finish();
      return builder.takeBytes();
    } on SocketException catch (error) {
      throw UpdateException('Нет связи: ${error.message}');
    } finally {
      client.close(force: true);
    }
  }
}

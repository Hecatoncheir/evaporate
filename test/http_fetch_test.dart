import 'dart:convert';
import 'dart:io';

import 'package:evaporate/services/system/http_fetch.dart';
import 'package:evaporate/services/system/proxy_http_overrides.dart';
import 'package:flutter_test/flutter_test.dart';

/// Один GET на четверых: каталог Steam, обложки, проверка обновлений и
/// база путей сохранений. Сервер здесь свой, на петле, — сети тесту не
/// нужно.
void main() {
  late HttpServer server;
  late List<HttpHeaders> received;

  /// Чем отвечать на следующий запрос.
  late int status;
  late List<int> body;

  setUp(() async {
    status = HttpStatus.ok;
    body = utf8.encode('ответ');
    received = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      received.add(request.headers);
      request.response.statusCode = status;
      request.response.add(body);
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  Uri address() => Uri.parse('http://127.0.0.1:${server.port}/');

  HttpFetch fetcher({
    int? limitBytes,
    Map<String, String> headers = const {},
  }) => HttpFetch(
    openClient: directHttpClient,
    describeStatus: (code) => HttpException('ответил $code'),
    headers: headers,
    limitBytes: limitBytes,
  );

  test('двести — тело целиком', () async {
    body = List.filled(3000, 65);

    expect(await fetcher().bytes(address()), hasLength(3000));
  });

  test('текст читается как UTF-8', () async {
    body = utf8.encode('сохранения');

    expect(await fetcher().text(address()), 'сохранения');
  });

  // Слова об отказе у каждого зовущего свои: отказ каталога — про
  // каталог, отказ обновления — про обновление.
  test('не двести — отказ теми словами, что дал зовущий', () async {
    status = HttpStatus.forbidden;

    await expectLater(
      fetcher().text(address()),
      throwsA(
        isA<HttpException>().having(
          (e) => e.message,
          'сообщение',
          'ответил 403',
        ),
      ),
    );
  });

  test('заголовки доходят до сервера', () async {
    await fetcher(headers: {HttpHeaders.userAgentHeader: 'Evaporate/1'})
        .text(address());

    expect(received.single.value(HttpHeaders.userAgentHeader), 'Evaporate/1');
  });

  // Ответ приходит извне, и принимать его без предела — значит позволить
  // чужой стороне занять всю память.
  test('тело длиннее дозволенного обрывается отказом', () async {
    body = List.filled(4096, 65);

    await expectLater(
      fetcher(limitBytes: 1024).bytes(address()),
      throwsFormatException,
    );
  });

  test('о ходе сообщают, и последнее слово — за концом загрузки', () async {
    body = List.filled(8192, 65);
    final reports = <int>[];

    await fetcher().bytes(address(), onProgress: (got, _) => reports.add(got));

    expect(reports, isNotEmpty);
    expect(reports.last, 8192);
  });
}

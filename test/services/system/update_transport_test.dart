import 'dart:convert';
import 'dart:io';

import 'package:evaporate/services/system/update_exception.dart';
import 'package:evaporate/services/system/update_transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// Как файлы обновления достаются из сети. Сервер здесь свой, на петле.
void main() {
  late HttpServer server;

  tearDown(() => server.close(force: true));

  /// Сервер, отвечающий по таблице «путь → что ответить».
  Future<Uri> serving(Map<String, void Function(HttpResponse)> routes) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final route = routes[request.uri.path];
      if (route == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        route(request.response);
      }
      await request.response.close();
    });
    return Uri.parse('http://127.0.0.1:${server.port}/');
  }

  // GitHub отдаёт файлы релиза через переадресацию на своё хранилище, и
  // адрес в ней бывает относительным — а за ним ещё одна. Кто идёт по
  // цепочке, клиент или наш цикл, тесту неважно: важно, что доходит она
  // до того файла, который просили, а не до пути от корня.
  test('цепочка переадресаций доводит до файла', () async {
    final base = await serving({
      '/release/file': (response) {
        response
          ..statusCode = HttpStatus.movedTemporarily
          ..headers.set(HttpHeaders.locationHeader, '/storage/');
      },
      '/storage/': (response) {
        response
          ..statusCode = HttpStatus.movedTemporarily
          ..headers.set(HttpHeaders.locationHeader, 'sums');
      },
      '/storage/sums': (response) {
        response.add(utf8.encode('сумма'));
      },
    });

    final bytes = await UpdateTransport.fetch(
      base.resolve('release/file'),
      (_, _) {},
    );

    expect(utf8.decode(bytes), 'сумма');
  });

  // Слов у транспорта нет — он статика и языка не знает: отказ приходит
  // причиной с кодом ответа, а слова к ним подберёт блок обновления.
  test('отказ сервера приходит причиной и кодом ответа', () async {
    final base = await serving({});

    await expectLater(
      UpdateTransport.fetch(base.resolve('missing'), (_, _) {}),
      throwsA(
        isA<UpdateException>()
            .having((e) => e.reason, 'причина', UpdateFailure.serverStatus)
            .having((e) => e.detail, 'код', '404'),
      ),
    );
  });
}

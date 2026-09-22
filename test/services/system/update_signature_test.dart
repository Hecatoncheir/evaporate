import 'dart:convert';
import 'dart:io';

import 'package:evaporate/services/system/update_signature.dart';
import 'package:flutter_test/flutter_test.dart';

/// Подпись под файлом сумм — то, что отличает наш релиз от выложенного
/// кем-то от нашего имени.
void main() {
  List<int> hex(String text) => [
    for (var i = 0; i < text.length; i += 2)
      int.parse(text.substring(i, i + 2), radix: 16),
  ];

  // RFC 8032, раздел 7.1, «TEST 1»: пустое сообщение.
  final rfcKey = base64Encode(
    hex('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'),
  );
  final rfcSignature = hex(
    'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
  );

  group('проверка подписи', () {
    final signature = UpdateSignature(trustedKeys: [rfcKey]);

    test('подпись из RFC 8032 сходится', () async {
      expect(await signature.verify(const [], rfcSignature), isTrue);
    });

    test('другое сообщение под той же подписью не сходится', () async {
      expect(await signature.verify(utf8.encode('x'), rfcSignature), isFalse);
    });

    test('испорченная подпись не сходится', () async {
      final broken = [...rfcSignature]..[10] ^= 1;
      expect(await signature.verify(const [], broken), isFalse);
    });

    // Библиотека на подписи не той длины бросает — а ответ здесь один:
    // «не подтверждено».
    test('подпись не той длины — не подпись', () async {
      expect(await signature.verify(const [], const []), isFalse);
      expect(
        await signature.verify(const [], rfcSignature.sublist(1)),
        isFalse,
      );
    });

    test('ключ, которому не верим, подпись не подтверждает', () async {
      const stranger = UpdateSignature(
        trustedKeys: ['orraeL7HTiSc5y47XUJl09ALdDDVMRWj6u3GFX9a0ag='],
      );
      expect(await stranger.verify(const [], rfcSignature), isFalse);
    });

    test('подходит любой ключ из списка', () async {
      final either = UpdateSignature(
        trustedKeys: ['orraeL7HTiSc5y47XUJl09ALdDDVMRWj6u3GFX9a0ag=', rfcKey],
      );
      expect(await either.verify(const [], rfcSignature), isTrue);
    });
  });

  // По файлу CI проверяет подпись сразу после того, как её поставил: секрет,
  // не парный ключу в приложении, дал бы релиз, который не примет ни одна
  // установленная копия. Файл и приложение обязаны держать один ключ.
  test('ключ в приложении — тот же, что в tool/update_signing_key.pub.pem', () {
    final pem = File('tool/update_signing_key.pub.pem').readAsStringSync();
    final body = const LineSplitter()
        .convert(pem)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('-----'))
        .join();
    final der = base64Decode(body);
    // SubjectPublicKeyInfo Ed25519: двенадцать байт заголовка и ключ.
    const header = '302a300506032b6570032100';

    expect(der.sublist(0, 12), hex(header));
    expect(
      UpdateSignature.defaultTrustedKeys.first,
      base64Encode(der.sublist(12)),
    );
  });
}

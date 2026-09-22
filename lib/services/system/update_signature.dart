import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// Подлинность обновления: подпись Ed25519 под файлом сумм релиза.
///
/// Суммы ловят оборванную и побитую загрузку, но не подмену: их считает то
/// же задание CI, что собирает архивы, и кладёт в тот же релиз. Кто сумел
/// выложить релиз от имени проекта — угнав учётную запись или токен, —
/// выложил бы и суммы, а Windows-клиент молча запускает скачанный
/// установщик. Подпись ставит закрытый ключ, которого в репозитории нет:
/// он в секрете CI (`UPDATE_SIGNING_KEY`) и у хозяина проекта. Открытый —
/// здесь.
///
/// Проверка — чистым Dart (`DartEd25519`): итог не зависит от того,
/// какую криптографию подставит платформа, и одинаков в прогоне и у
/// человека.
class UpdateSignature {
  const UpdateSignature({this.trustedKeys = defaultTrustedKeys});

  /// Файл подписи в релизе — рядом с `SHA256SUMS`: 64 байта подписи над
  /// ним, как их выдаёт `openssl pkeyutl -sign -rawin`.
  static const fileName = 'SHA256SUMS.sig';

  /// Открытые ключи, которым верим: 32 байта Ed25519 в base64.
  ///
  /// Список, а не один ключ: сменить ключ можно только выпуском, который
  /// знает оба, — иначе установленные копии не приняли бы ни одного
  /// релиза, подписанного новым. Первый — тот же, что в
  /// `tool/update_signing_key.pub.pem`: по файлу CI проверяет подпись сразу
  /// после того, как её поставил, а тест сверяет, что они не разошлись.
  static const defaultTrustedKeys = [
    'orraeL7HTiSc5y47XUJl09ALdDDVMRWj6u3GFX9a0ag=',
  ];

  final List<String> trustedKeys;

  /// Подписано ли [message] одним из [trustedKeys].
  ///
  /// Подпись не той длины — не подпись: библиотека бросила бы на ней
  /// исключение, а ответ здесь один — «не подтверждено».
  Future<bool> verify(List<int> message, List<int> signature) async {
    if (signature.length != 64) return false;
    final ed25519 = DartEd25519();
    for (final key in trustedKeys) {
      final trusted = await ed25519.verify(
        message,
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(
            base64Decode(key),
            type: KeyPairType.ed25519,
          ),
        ),
      );
      if (trusted) return true;
    }
    return false;
  }
}

/// Размеры картинки по её заголовку, без полного разбора.
///
/// Своим файлом, потому что это разбор двоичных форматов, а не работа со
/// Steam: пятьдесят строк про байты маркеров рядом с записью ярлыков
/// читались бы как чужая вставка.
/// Размеры картинки, прочитанные из заголовка.
class ImageSize {
  const ImageSize(this.width, this.height);

  final int width;
  final int height;
}

/// Ширина и высота JPEG или PNG без полного разбора картинки.
///
/// Обе с CDN Steam, других нам и не приносят. `null` — «не разобрали»;
/// вызывающий считает такую обложку вертикальной, потому что каталог
/// сначала просит именно вертикальную.
ImageSize? imageSizeOf(List<int> bytes) => _pngSize(bytes) ?? _jpegSize(bytes);

/// PNG: размеры лежат в IHDR, сразу за подписью, старшим байтом вперёд.
ImageSize? _pngSize(List<int> bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47];
  if (bytes.length <= 24) return null;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return null;
  }
  return ImageSize(_be32(bytes, 16), _be32(bytes, 20));
}

/// JPEG: идём по маркерам до любого из SOF — только там лежат размеры.
ImageSize? _jpegSize(List<int> bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;

  var i = 2;
  while (i + 9 < bytes.length) {
    if (bytes[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = bytes[i + 1];
    // Заполнитель между маркерами и маркеры без полезной нагрузки.
    if (marker == 0xFF || (marker >= 0xD0 && marker <= 0xD9)) {
      i += 2;
      continue;
    }
    if (_isStartOfFrame(marker)) {
      return ImageSize(_be16(bytes, i + 7), _be16(bytes, i + 5));
    }
    final length = _be16(bytes, i + 2);
    if (length < 2) return null;
    i += 2 + length;
  }
  return null;
}

/// Начало кадра — единственный маркер, в котором записаны размеры.
bool _isStartOfFrame(int marker) =>
    marker >= 0xC0 &&
    marker <= 0xCF &&
    marker != 0xC4 && // таблица Хаффмана
    marker != 0xC8 && // расширение JPEG
    marker != 0xCC; // таблица арифметического кодирования

/// Число из двух байт, старший впереди.
int _be16(List<int> bytes, int at) => bytes[at] << 8 | bytes[at + 1];

/// Число из четырёх байт, старший впереди.
int _be32(List<int> bytes, int at) =>
    bytes[at] << 24 | bytes[at + 1] << 16 | bytes[at + 2] << 8 | bytes[at + 3];

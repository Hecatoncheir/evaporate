# contrast

Проба из исследования; в прогон тестов не входит, лежит как образец. Запускать из scratchpad: `flutter test <абсолютный путь>`.

```dart
import 'dart:math' as math;
double lum(int c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(((c >> 16) & 255) / 255) + 0.7152 * ch(((c >> 8) & 255) / 255) + 0.0722 * ch((c & 255) / 255);
}
double cr(int a, int b) { final la = lum(a), lb = lum(b); return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05); }
void main() {
  const bg = 0x06060A, sf = 0x0E0F16, sh = 0x15161F;
  final bgs = [bg, sf, sh];
  String r(double v) => v.toStringAsFixed(2);
  print('outline/bg ${r(cr(0x22242F, bg))}');
  for (final e in {'textPrimary': 0xF2F3F7, 'textSecondary': 0xA8ACBD, 'hot1': 0xFF7A18, 'cool': 0x5EE7FF, 'warn/hot2': 0xFFC24D, 'bad': 0xFF4D5E, 'ink3': 0x6E7387, 'ink4': 0x464A5C}.entries) {
    print('${e.key}: ${bgs.map((b) => r(cr(e.value, b))).join(' / ')}');
  }
  print('onPrimary 170800 on hot1 ${r(cr(0x170800, 0xFF7A18))}');
  print('onDanger 0A0D11 on bad ${r(cr(0x0A0D11, 0xFF4D5E))}');
  print('onSelection 0A0D11 on hot2 ${r(cr(0x0A0D11, 0xFFC24D))}');
  print('onSelection 0A0D11 on hot1 ${r(cr(0x0A0D11, 0xFF7A18))}');
  print('hot1 vs portalRim FF8A1F ${r(cr(0xFF7A18, 0xFF8A1F))}');
  print('hot2 vs portalRim ${r(cr(0xFFC24D, 0xFF8A1F))}');
  print('light bg lum > dark: ${lum(0xE4E1D8) > lum(bg)}');
}

```

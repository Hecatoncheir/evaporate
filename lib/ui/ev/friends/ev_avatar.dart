import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// Аватар друга: инициалы на градиенте своего цвета. Один и тот же
/// кружок стоит в правой колонке библиотеки, в карточке игры и во всех
/// списках раздела «Друзья».
class EvFriendAvatar extends StatelessWidget {
  const EvFriendAvatar({
    super.key,
    required this.initials,
    required this.tint,
    this.size = 28,
    this.status,
  });

  final String initials;
  final EvAvatarTint tint;
  final double size;

  /// Точка состояния в правом нижнем углу. `null` — без точки.
  final Color? status;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final dot = size * .29;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                math.min(ev.radii.pill, size / 2),
              ),
              gradient: LinearGradient(
                // 140° в CSS
                begin: const Alignment(-.64, -.77),
                end: const Alignment(.64, .77),
                colors: evAvatarColors(c, tint),
              ),
            ),
            child: Text(
              initials,
              style: ev.text.ui(
                ev.text.title,
                weight: FontWeight.w600,
                size: size * .39,
                color: const Color(0xFF0B0B10),
              ),
            ),
          ),
          if (status != null)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: status,
                  // Обводка цветом панели — чтобы точка не сливалась
                  // с кромкой аватара.
                  border: Border.all(color: c.surface, width: 2),
                  boxShadow: status == c.ink4
                      ? null
                      : [BoxShadow(color: status!, blurRadius: 8)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Градиент аватара: два цвета под 140°.
List<Color> evAvatarColors(EvColors c, EvAvatarTint tint) => switch (tint) {
  EvAvatarTint.hot => [c.hot2, c.hot1],
  EvAvatarTint.cool => [c.cool, const Color(0xFF1B6F8A)],
  EvAvatarTint.arc => [c.arc, const Color(0xFF5A2FA8)],
  EvAvatarTint.ok => const [EvColors.ok, Color(0xFF146C48)],
  EvAvatarTint.rose => const [Color(0xFFFF8AE0), Color(0xFFA8226F)],
  EvAvatarTint.sky => const [Color(0xFF8FB6FF), Color(0xFF2B4A8F)],
};

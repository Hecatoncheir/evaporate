import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../models/app_settings.dart';

/// Раскладка считается по увеличенному логическому размеру, а затем
/// масштабируется весь `Navigator` целиком — так вместе с текстом растут
/// и заданные числом размеры значков, области нажатия и диалоги.
///
/// Кнопки окна остаются снаружи: они принадлежат системе, а не интерфейсу.
class InterfaceScale extends StatelessWidget {
  const InterfaceScale({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = context
        .select<SettingsBloc, double>((b) => b.state.interfaceScale)
        .clamp(AppSettings.minInterfaceScale, AppSettings.maxInterfaceScale);
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final size = constraints.biggest / scale;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: size.width,
            maxWidth: size.width,
            minHeight: size.height,
            maxHeight: size.height,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: MediaQuery(
                data: media.copyWith(
                  size: size,
                  devicePixelRatio: media.devicePixelRatio * scale,
                  padding: media.padding / scale,
                  viewPadding: media.viewPadding / scale,
                  viewInsets: media.viewInsets / scale,
                  systemGestureInsets: media.systemGestureInsets / scale,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

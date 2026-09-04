import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../models/app_settings.dart';

/// Layout at the zoomed logical size, then scale the entire Navigator.
/// Explicit icon sizes, text, hit targets and dialogs all scale together.
/// The native/custom window controls stay outside this widget.
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

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/window_start_mode.dart';
import 'segmented_setting.dart';

/// Каким открывать окно при запуске.
class WindowStartPicker extends StatelessWidget {
  const WindowStartPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final WindowStartMode value;
  final ValueChanged<WindowStartMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SegmentedSetting<WindowStartMode>(
      label: l.windowOnStart,
      segments: [
        ButtonSegment(
          value: WindowStartMode.remembered,
          icon: const Icon(Icons.crop_din, size: 17),
          label: Text(l.windowRemembered),
        ),
        ButtonSegment(
          value: WindowStartMode.maximized,
          icon: const Icon(Icons.fullscreen, size: 17),
          label: Text(l.windowMaximized),
        ),
        ButtonSegment(
          value: WindowStartMode.minimized,
          icon: const Icon(Icons.expand_more, size: 17),
          label: Text(l.windowMinimized),
        ),
      ],
      selected: value,
      onChanged: onChanged,
    );
  }
}

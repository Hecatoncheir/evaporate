import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import 'library_heading.dart';

/// Подпись раздела библиотеки вместе с ползунком крупности плиток.
///
/// Ползунок стоит здесь, а не в настройках: он про то, на что смотришь
/// прямо сейчас, и крутят его, глядя на сами обложки.
class LibraryHeadingBar extends StatelessWidget {
  const LibraryHeadingBar({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsBloc>();
    return ConceptLibraryHeading(
      scale: store.state.appearance.libraryScale,
      onScale: (value) => store.add(
        SettingsPatched(
          (current) =>
              current.withAppearance((a) => a.copyWith(libraryScale: value)),
        ),
      ),
    );
  }
}

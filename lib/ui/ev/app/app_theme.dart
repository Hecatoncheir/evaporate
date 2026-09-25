import 'package:flutter/material.dart';

import '../../theme.dart';
import '../design/theme.dart';

/// Тема окна: тёмная тема приложения и токены прототипа поверх неё.
///
/// Одна на всё окно, потому что в нём живут оба интерфейса сразу: каркас
/// прототипа читает `context.ev`, а прежние страницы, ещё не перенесённые
/// в него, — `context.colors` и роли текста приложения. Схема одна —
/// тёмная: у прототипа дневной нет (`docs/decisions/0013`).
ThemeData evaporateAppTheme() => withEvTokens(EvaporateTheme.dark());

/// [base] с токенами прототипа (`context.ev`), если их в ней ещё нет.
ThemeData withEvTokens(ThemeData base) {
  if (base.extension<EvTheme>() != null) return base;
  final ev = buildEvTheme().extension<EvTheme>()!;
  return base.copyWith(extensions: [...base.extensions.values, ev]);
}
